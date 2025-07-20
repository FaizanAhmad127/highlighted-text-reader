import 'package:country_code_picker_plus/country_code_picker_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:go_router/go_router.dart';

// Clean Architecture imports
import 'core/constants/app_constants.dart';
import 'core/utils/ui_helpers.dart';
import 'domain/entities/user.dart' as domain;
import 'data/datasources/firestore_datasource.dart';
import 'data/datasources/firebase_auth_datasource.dart';
import 'data/repositories/user_repository_impl.dart';
import 'data/repositories/auth_repository_impl.dart';
import 'domain/usecases/auth/verify_phone_number.dart';
import 'domain/usecases/auth/sign_in_with_credential.dart';
import 'domain/usecases/user/create_user.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class PhoneAuthScreen extends StatefulWidget {
  @override
  _PhoneAuthScreenState createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  // Dependencies - should be injected via DI in production
  late final VerifyPhoneNumberUseCase _verifyPhoneNumberUseCase;
  late final SignInWithCredentialUseCase _signInWithCredentialUseCase;
  late final CreateUserUseCase _createUserUseCase;

  // Controllers
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();

  // State variables
  String? _verificationId;
  String? _countryCode = AppConstants.defaultCountryCode;
  bool showSigninButton = false;
  String? _selectedGender;
  List<Map<String, dynamic>>? _genderOptions;
  bool showVerifyButton = false;
  int _secondsRemaining = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initializeDependencies();
    _initializeGenderOptions();
  }

  void _initializeDependencies() {
    // Initialize data sources
    final firestore = FirebaseFirestore.instance;
    final auth = FirebaseAuth.instance;
    final firestoreDataSource = FirestoreDataSource(firestore);
    final authDataSource = FirebaseAuthDataSource(auth);

    // Initialize repositories
    final userRepository = UserRepositoryImpl(firestoreDataSource);
    final authRepository = AuthRepositoryImpl(authDataSource);

    // Initialize use cases
    _verifyPhoneNumberUseCase = VerifyPhoneNumberUseCase(authRepository);
    _signInWithCredentialUseCase = SignInWithCredentialUseCase(authRepository);
    _createUserUseCase = CreateUserUseCase(userRepository);
  }

  void _initializeGenderOptions() {
    _genderOptions = [
      {
        'value': AppConstants.maleGender,
        'icon': Icons.man,
        'label': AppConstants.maleGender
      },
      {
        'value': AppConstants.femaleGender,
        'icon': Icons.woman,
        'label': AppConstants.femaleGender
      },
    ];
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _verifyPhoneNumber() async {
    _codeController.text = '';
    setState(() {
      showSigninButton = false;
    });

    // Validation
    if (_nameController.text.isEmpty) {
      UIHelpers.showSnackbar(context, 'Please enter your name');
      return;
    }
    if (_phoneController.text.isEmpty) {
      UIHelpers.showSnackbar(context, 'Please enter phone number');
      return;
    }
    if (_selectedGender == null) {
      UIHelpers.showSnackbar(context, 'Please select your gender');
      return;
    }
    if (_countryCode == null || _countryCode!.isEmpty) {
      UIHelpers.showSnackbar(context, 'Please select a country code');
      return;
    }

    if (!mounted) return;

    UIHelpers.showSnackbar(
        context, 'Please wait while we verify your phone number');

    String phoneNumber = '$_countryCode${_phoneController.text}';
    if (kDebugMode) {
      print('Attempting to verify phone number: $phoneNumber');
    }

    await _verifyPhoneNumberUseCase(
      phoneNumber: phoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {
        await _signInWithCredentialUseCase(credential).then((value) {
          _stopTimer();
          if (mounted) {
            setState(() {
              _secondsRemaining = 0;
            });
          }
        });
      },
      verificationFailed: (FirebaseAuthException e) {
        if (kDebugMode) {
          print("Verification failed: ${e.code}");
        }
        if (!mounted) return;

        if (e.code == 'invalid-phone-number') {
          UIHelpers.showSnackbar(
              context, 'The provided phone number is not valid');
        } else if (e.code == 'too-many-requests') {
          UIHelpers.showSnackbar(context, 'Too many requests. Try again later');
        } else if (e.code == 'invalid-verification-code') {
          UIHelpers.showSnackbar(context, 'Invalid verification code');
        } else {
          UIHelpers.showSnackbar(
              context, 'Something went wrong. Please try again');
        }
      },
      codeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;

        UIHelpers.showSnackbar(context, 'Verification code sent to your phone');
        setState(() {
          _verificationId = verificationId;
          showVerifyButton = false;
          _startTimer();
        });
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        if (!mounted) return;

        setState(() {
          _verificationId = verificationId;
        });
      },
    );
  }

  void _signInWithPhoneNumber() async {
    final credential = PhoneAuthProvider.credential(
      verificationId: _verificationId!,
      smsCode: _codeController.text,
    );

    try {
      UserCredential userCredential =
          await _signInWithCredentialUseCase(credential);

      if (userCredential.user != null) {
        FocusScope.of(context).unfocus();

        // Create user entity
        final user = domain.User(
          id: userCredential.user!.uid,
          name: _nameController.text,
          phoneNumber: '$_countryCode${_phoneController.text}',
          gender: _selectedGender!,
          tokensUsed: AppConstants.defaultTokenCount,
        );

        await _createUserUseCase(user);

        if (mounted) {
          UIHelpers.showSnackbar(context, 'Phone number verified successfully');
          _stopTimer();
          context.go(AppConstants.homeRoute);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print("Sign in failed: $e");
      }
      if (mounted) {
        UIHelpers.showSnackbar(context, 'Invalid verification code');
      }
    }
  }

  void _startTimer() {
    _secondsRemaining = AppConstants.verificationTimerSeconds;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_secondsRemaining > 0) {
          _secondsRemaining--;
        } else {
          _timer?.cancel();
          showVerifyButton = true;
        }
      });
    });
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  String _getSignInText() {
    return "Sign In";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phone Authentication'),
        backgroundColor: Colors.lightBlueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: 'Full Name',
                hintText: 'John Doe',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.name,
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  CountryCodePicker(
                    onInit: (value) {
                      if (kDebugMode) {
                        print('Country code selected: $value');
                      }
                      _countryCode = value.toString();
                    },
                    onChanged: (number) {
                      if (kDebugMode) {
                        print('Country code selected: $number');
                      }
                      _countryCode = number.toString();
                    },
                    initialSelection: 'PK',
                  ),
                  Expanded(
                    child: TextField(
                      controller: _phoneController,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        hintText: '3029389334',
                        border: InputBorder.none,
                      ),
                      keyboardType: TextInputType.phone,
                      onChanged: (value) {
                        setState(() {
                          showVerifyButton = value.isNotEmpty;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedGender,
              decoration: InputDecoration(
                labelText: 'Gender',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              items: _genderOptions!.map((gender) {
                return DropdownMenuItem<String>(
                  value: gender['value'],
                  child: Row(
                    children: [
                      Icon(gender['icon']),
                      const SizedBox(width: 8),
                      Text(gender['label']),
                    ],
                  ),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGender = value;
                });
              },
            ),
            const SizedBox(height: 16),
            if (showVerifyButton)
              ElevatedButton(
                onPressed: _verifyPhoneNumber,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                    UIHelpers.getGenderBackgroundColor(_selectedGender),
                  ),
                ),
                child: Text(
                  'Verify Phone Number',
                  style: TextStyle(
                    color: UIHelpers.getGenderTextColor(_selectedGender),
                  ),
                ),
              ),
            if (!showVerifyButton && _secondsRemaining > 0)
              Text(
                'Resend code in: $_secondsRemaining seconds',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: InputDecoration(
                labelText: 'Verification Code',
                hintText: 'Enter 6 digit code',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              keyboardType: TextInputType.number,
              onChanged: (value) {
                setState(() {
                  showSigninButton = value.length == 6;
                });
              },
            ),
            const SizedBox(height: 16),
            if (showSigninButton)
              ElevatedButton(
                onPressed: _signInWithPhoneNumber,
                style: ButtonStyle(
                  backgroundColor: MaterialStateProperty.all(
                    UIHelpers.getGenderBackgroundColor(_selectedGender),
                  ),
                ),
                child: Text(
                  _getSignInText(),
                  style: TextStyle(
                    color: UIHelpers.getGenderTextColor(_selectedGender),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
