import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openai_dart/openai_dart.dart' as openai;
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'secrets/secrets.dart';

// Clean Architecture imports
import 'core/constants/app_constants.dart';
import 'core/utils/ui_helpers.dart';
import 'domain/entities/highlight.dart';
import 'data/models/highlight_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // OpenAI client
  late openai.OpenAIClient client;

  // State variables
  bool isDialogOpen = false;
  File? _image;
  String? base64Image;
  String? text;
  HighlightResponse? highlightResponse;
  int tokenUsed = 0;
  bool isUserUsingOwnApiKey = false;
  String? apiKey;
  bool isGoToBuyTokenScreenVisible = false;
  bool isFetchingMeaning = false;

  @override
  void initState() {
    super.initState();
    _setupConnectivityListener();
    _initializeOpenAIClient();
  }

  void _setupConnectivityListener() {
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.contains(ConnectivityResult.none)) {
        showNoInternetDialog();
      } else {
        dismissDialog();
      }
    });
  }

  Future<void> _initializeOpenAIClient() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();

    if (tokenUsed < 20) {
      apiKey = Secrets.openAIProjectApiKey;
      await prefs.remove('openai_api_key');
    } else {
      apiKey = prefs.getString('openai_api_key');
      if (apiKey == null) {
        return;
      } else {
        isUserUsingOwnApiKey = true;
      }
    }
    client = openai.OpenAIClient(apiKey: apiKey);
  }

  void showNoInternetDialog() {
    if (!isDialogOpen) {
      isDialogOpen = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          title: Text('No Internet'),
          content: Text('Please check your internet connection.'),
          actions: [],
        ),
      );
    }
  }

  void dismissDialog() {
    if (isDialogOpen) {
      isDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  Future<void> setApiKey(String apiKey) async {
    if (kDebugMode) {
      print("New api key is: $apiKey");
    }
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('openai_api_key', apiKey);
    _initializeOpenAIClient();
  }

  Future<void> _pickImage(ImageSource source) async {
    if (kDebugMode) {
      print("=================== $apiKey");
    }

    if (tokenUsed >= 20 && !isUserUsingOwnApiKey) {
      final result = await context.push(AppConstants.buyTokenRoute);
      if (result != null && result is List && result.isNotEmpty) {
        String apiKey = result[0];
        setApiKey(apiKey);
      }
      return;
    }

    final picker = ImagePicker();
    setState(() {
      highlightResponse = null;
    });

    UIHelpers.showSnackbar(context, 'Loading image');
    final pickedFile = await picker.pickImage(source: source);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
      });
      _fileToBase64(_image!);
    } else {
      UIHelpers.showSnackbar(context, 'No image selected, Try again');
    }
  }

  Future _fileToBase64(File file) async {
    UIHelpers.showSnackbar(context, 'Converting image to base64');
    final bytes = await file.readAsBytes();
    base64Image = 'data:image/png;base64,${base64Encode(bytes)}';
    if (base64Image != null) {
      _processImage();
    } else {
      UIHelpers.showSnackbar(context, 'Error converting image to base64');
    }
  }

  void _processImage() async {
    setState(() {
      isFetchingMeaning = true;
    });
    UIHelpers.showSnackbar(context, 'Processing image, please wait');

    try {
      final res = await client.createChatCompletion(
        request: openai.CreateChatCompletionRequest(
          model: openai.ChatCompletionModel.model(
            openai.ChatCompletionModels.gpt4o,
          ),
          messages: [
            openai.ChatCompletionMessage.system(
              content: 'You are a helpful english professor.',
            ),
            openai.ChatCompletionMessage.user(
              content: openai.ChatCompletionUserMessageContent.parts(
                [
                  openai.ChatCompletionMessageContentPart.text(
                    text: '''Retrieve the highlighted text from this image.
                  Make sure that the highlighted text is entirely in an image, if not then
                  ignore that highlighted text and continue with other highlighted text.
                  If the image is blur and distorted then also return false for 'found' key.
                  Only give me a json object in result.
                  Json should look like this in which found is used whether any
                  highlighted text is found or not in whole image. Also if the image doesn't
                  have any text at all then also return false.

                  the key 'color' should have the color of the highlighted text in form of hex and
                  hex code should look like this 0xFF6200EE and should be a string value wrapped by double quotes.

                  Given a background color which has a key 'color' in hex format, recommend an appropriate text color
                  which has a key 'textColor'
                  from the opposite side of the color spectrum. For dark backgrounds
                  like dark blue (#00008B), dark red (#8B0000), or dark black (#000000),
                  suggest light shades of white, ensuring good contrast. If the background is light,
                  suggest a darker text color for optimal readability,
                  Provide the hex code of the suggested text color and should be
                  a string value wrapped by double quotes.

                  the key 'text' should have the highlighted text.

                  the key 'literal' should give the literal meaning of that text, and same language as of 'text' and 
                  should be a string value wrapped by double quotes.
                 
                 they key 'contextual' should give the contextual meaning of that text by analyzing
                  either the whole passage or current paragraph or current sentence and if the image isn't cover the whole book page or 
                  passage then analyze the surrounding text, and same language as of 'text', and should be a string value wrapped by double quotes.
                  Json object should look like this
                  {
                    "found": true,
                    "highlights": [
                       {
                          "text": "abc",
                          "color": "0xFF6200EE",
                          "textColor": "0xFF6200EE",
                          "literal": "The love is dkafkfa",
                          "contextual": "Love is defined..."
                        }
                      ]
                  }

                  Make sure to validate your answer by checking the key value pair, text shouldn't be empty,
                  color should be in hex format, textColor should be opposite of color and in hex format,
                  literal and contextual should not be empty. And the json object should be valid json object.
                  ''',
                  ),
                  openai.ChatCompletionMessageContentPart.image(
                    imageUrl: openai.ChatCompletionMessageImageUrl(
                      url: base64Image!,
                      detail: openai.ChatCompletionMessageImageDetail.auto,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );

      if (kDebugMode) {
        print(res.choices.first.message.content!);
      }
      parseResponse(res.choices.first.message.content!);
    } catch (e) {
      setState(() {
        isFetchingMeaning = false;
      });
      UIHelpers.showSnackbar(
        context,
        'Error processing image. If you are using your own API key, please check if it is valid and also has balance in it. Go to Set API screen to set your own',
        durationSeconds: 7,
      );
      if (kDebugMode) {
        print("Error processing image: $e");
      }
    }
  }

  Future parseResponse(String response) async {
    String cleanJson =
        response.replaceAll("```json", "").replaceAll("```", "").trim();

    try {
      Map<String, dynamic> jsonMap = json.decode(cleanJson);
      final highlightResponseModel = HighlightResponseModel.fromMap(jsonMap);
      highlightResponse = highlightResponseModel.toEntity();

      if (kDebugMode) {
        print("Parsed Data: ${highlightResponseModel.toJson()}");
      }

      if (highlightResponse?.found == false) {
        setState(() {
          isFetchingMeaning = false;
        });
        UIHelpers.showSnackbar(
          context,
          'Something went wrong. Make sure to take a picture of book page with highlighted text on it. Or if the image is blur or of very small size trying another image. Please try again',
          durationSeconds: 7,
        );
      } else {
        setState(() {
          isFetchingMeaning = false;
        });
        UIHelpers.showSnackbar(
          context,
          'Enjoy the highlighted text. If you didn\'t get the desired result try high resolution image',
        );

        if (!isUserUsingOwnApiKey) {
          print("Increasing token");

          // todo: increase token
        }
      }
    } catch (e) {
      setState(() {
        isFetchingMeaning = false;
      });
      UIHelpers.showSnackbar(
        context,
        'Something went wrong. Make sure to take a picture of book page with highlighted text on it. Or if the image is blur or of very small size trying another image. Please try again',
        durationSeconds: 7,
      );
      if (kDebugMode) {
        print("Error parsing JSON: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final found = highlightResponse?.found ?? false;
    final highlights = highlightResponse?.highlights ?? [];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(AppConstants.appName),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Tokens remaining: ${20 - tokenUsed}"),
                      if (isGoToBuyTokenScreenVisible)
                        TextButton(
                          onPressed: () async {
                            final result =
                                await context.push(AppConstants.buyTokenRoute);
                            if (result != null &&
                                result is List &&
                                result.isNotEmpty) {
                              String apiKey = result[0];
                              await setApiKey(apiKey);
                            }
                          },
                          child: const Text(
                            "Set API",
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (_image != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.of(context).size.height * 0.35,
                        maxWidth: MediaQuery.of(context).size.width,
                      ),
                      child: InteractiveViewer(
                        child: Image.file(
                          _image!,
                          fit: BoxFit.fitWidth,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () => _pickImage(ImageSource.gallery),
                        child: const Text('Pick Image'),
                      ),
                      ElevatedButton(
                        onPressed: () => _pickImage(ImageSource.camera),
                        child: const Text('Take Picture'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                if (found)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        Text(
                          "Text",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Literal",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          "Contextual",
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                Expanded(
                  child: isFetchingMeaning
                      ? UIHelpers.loadingIndicator()
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          itemCount: highlights.length,
                          itemBuilder: (context, index) {
                            final highlight = highlights[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceEvenly,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.only(
                                        right: 2.0,
                                        left: 8,
                                        top: 8,
                                        bottom: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Color(
                                          int.tryParse(highlight.color) ??
                                              0xFFFFFFFF,
                                        ),
                                        borderRadius: const BorderRadius.only(
                                          topRight: Radius.circular(8),
                                          bottomRight: Radius.circular(8),
                                        ),
                                      ),
                                      child: SelectableText(
                                        highlight.text,
                                        style: TextStyle(
                                          color: Color(
                                            int.tryParse(highlight.textColor) ??
                                                0xFF000000,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(highlight.literal),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: SelectableText(highlight.contextual),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// class BuyToken extends StatefulWidget {
//   const BuyToken({super.key});

//   @override
//   State<BuyToken> createState() => _BuyTokenState();
// }

// class _BuyTokenState extends State<BuyToken> {
//   final TextEditingController apiKeyController = TextEditingController();

//   Future<void> _launchURL(String url) async {
//     if (await canLaunch(url)) {
//       await launch(url);
//     } else {
//       throw 'Could not launch $url';
//     }
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text('Set API Key'),
//       ),
//       body: Padding(
//         padding: const EdgeInsets.symmetric(horizontal: 20),
//         child: SingleChildScrollView(
//           child: Column(
//             spacing: 20,
//             children: [
//               const Text(
//                 "You have reached 20 token limit. Please use your own OpenAI API key",
//                 style: TextStyle(
//                   fontSize: 18,
//                   fontWeight: FontWeight.w600,
//                 ),
//               ),
//               TextButton(
//                 onPressed: () {
//                   _launchURL(
//                     'https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key',
//                   );
//                 },
//                 child: const Text(
//                   'Click on the link and get your own API key: https://help.openai.com/en/articles/4936850-where-do-i-find-my-openai-api-key',
//                 ),
//               ),
//               TextButton(
//                 onPressed: () {
//                   _launchURL(
//                     'https://help.openai.com/en/articles/8264644-how-can-i-set-up-prepaid-billing',
//                   );
//                 },
//                 child: const Text(
//                   'Note: Remember to add balance to your project after enabling API key. 1 USD would be enough for 50-100 images. Click on this guide: https://help.openai.com/en/articles/8264644-how-can-i-set-up-prepaid-billing',
//                 ),
//               ),
//               const Text(
//                 'Note: We don\'t store your API key. Your API key will be stored in your phone cache.',
//               ),
//               TextField(
//                 controller: apiKeyController,
//                 decoration: const InputDecoration(
//                   hintText: 'Enter your OpenAI API key',
//                   border: OutlineInputBorder(),
//                 ),
//               ),
//               ElevatedButton(
//                 onPressed: () {
//                   if (apiKeyController.text.isNotEmpty) {
//                     context.pop([apiKeyController.text]);
//                   } else {
//                     ScaffoldMessenger.of(context).showSnackBar(
//                       const SnackBar(content: Text('Please enter API key')),
//                     );
//                   }
//                 },
//                 child: const Text('Set API Key'),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
