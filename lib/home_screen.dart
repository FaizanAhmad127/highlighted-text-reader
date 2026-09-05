import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'core/constants/app_constants.dart';
import 'core/firebase/app_analytics.dart';
import 'core/firebase/app_crashlytics.dart';
import 'core/utils/connectivity_helper.dart';
import 'core/utils/ui_helpers.dart';
import 'data/services/text_processing_pipeline.dart';
import 'domain/entities/highlight.dart';
import 'presentation/widgets/highlight/expandable_highlight_card.dart';
import 'presentation/widgets/home/image_capture_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextProcessingPipeline _pipeline = TextProcessingPipeline();
  final ImagePicker _picker = ImagePicker();

  File? _image;
  HighlightResponse? highlightResponse;
  bool isFetchingMeaning = false;
  String? _status;
  bool _offline = false;
  bool _skipNextConnectivityEvent = true;
  bool _isRefreshingMeanings = false;
  int? _expandedHighlightIndex;

  @override
  void initState() {
    super.initState();
    _refreshConnectivity(silent: true);
    _setupConnectivityListener();
  }

  Future<void> _refreshConnectivity({required bool silent}) async {
    final online = await ConnectivityHelper.hasConnection();
    if (!mounted) return;
    setState(() => _offline = !online);
    if (!silent && !online) {
      unawaited(AppAnalytics.logConnectivityChanged(offline: true));
      UIHelpers.showSnackbar(
        context,
        'You are offline. Highlighted text can still be read; definitions need internet.',
      );
    }
  }

  void _setupConnectivityListener() {
    ConnectivityHelper.onConnectivityChanged.listen((results) {
      if (!mounted) return;

      // The first stream event often fires right after navigation; ignore it.
      if (_skipNextConnectivityEvent) {
        _skipNextConnectivityEvent = false;
        setState(() => _offline = ConnectivityHelper.isOffline(results));
        return;
      }

      final nowOffline = ConnectivityHelper.isOffline(results);
      final wasOffline = _offline;
      setState(() => _offline = nowOffline);

      if (nowOffline && !wasOffline) {
        unawaited(AppAnalytics.logConnectivityChanged(offline: true));
        UIHelpers.showSnackbar(
          context,
          'You are offline. Highlighted text can still be read; definitions need internet.',
        );
      } else if (!nowOffline && wasOffline) {
        unawaited(AppAnalytics.logConnectivityChanged(offline: false));
        unawaited(_refreshPendingMeanings());
      }
    });
  }

  Future<void> _refreshPendingMeanings() async {
    if (_isRefreshingMeanings || isFetchingMeaning) return;

    final highlights = highlightResponse?.highlights;
    if (highlights == null ||
        highlights.isEmpty ||
        !TextProcessingPipeline.hasPendingMeanings(highlights)) {
      return;
    }

    final online = await ConnectivityHelper.hasConnection();
    if (!online || !mounted) return;

    UIHelpers.showSnackbar(
      context,
      'Connection restored — loading definitions. No need to upload the image again.',
      icon: Icons.wifi,
      backgroundColor: Colors.green.shade700,
    );

    setState(() => _isRefreshingMeanings = true);

    try {
      final updated = await _pipeline.refreshMeanings(highlights);
      if (!mounted) return;

      final updatedHighlights = updated.highlights ?? [];
      final stillPending =
          TextProcessingPipeline.hasPendingMeanings(updatedHighlights);

      setState(() {
        highlightResponse = highlightResponse?.copyWith(
          highlights: updatedHighlights,
        );
        _isRefreshingMeanings = false;
        _offline = false;
      });

      if (!mounted) return;

      if (!stillPending) {
        UIHelpers.showSnackbar(
          context,
          'Definitions loaded.',
          icon: Icons.check_circle_outline,
          backgroundColor: Colors.green.shade700,
        );
      } else if (_pipeline.hadNetworkLookupFailure &&
          !TextProcessingPipeline.hasAnyLoadedDefinition(updatedHighlights)) {
        UIHelpers.showSnackbar(
          context,
          'Definitions could not be loaded. Check your internet connection.',
        );
      }
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(
        e,
        st,
        reason: 'meaning_refresh',
      );
      if (!mounted) return;
      setState(() => _isRefreshingMeanings = false);
      UIHelpers.showSnackbar(
        context,
        'Could not load definitions. We will retry when you are back online.',
      );
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final sourceName = source == ImageSource.camera ? 'camera' : 'gallery';
    unawaited(AppAnalytics.logImageSelected(source: sourceName));
    await AppCrashlytics.log('Image pick started: $sourceName');

    setState(() {
      highlightResponse = null;
      _expandedHighlightIndex = null;
      _status = 'Loading image';
    });

    final pickedFile = await _picker.pickImage(source: source);

    if (pickedFile == null) {
      setState(() => _status = null);
      if (!mounted) return;
      UIHelpers.showSnackbar(context, 'No image selected, try again');
      return;
    }

    setState(() {
      _image = File(pickedFile.path);
      isFetchingMeaning = true;
    });
    unawaited(AppAnalytics.logScanStarted(offline: _offline));
    await _processImage();
  }

  Future<void> _processImage() async {
    final image = _image;
    if (image == null) return;

    final online = await ConnectivityHelper.hasConnection();
    if (!mounted) return;
    setState(() => _offline = !online);

    setState(() => isFetchingMeaning = true);
    await AppCrashlytics.setCustomKeys({
      'offline': _offline,
      'lookup_meanings': online,
    });
    await AppCrashlytics.log('Image processing started');

    try {
      final result = await _pipeline.process(
        image,
        lookupMeanings: online,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _status = status);
        },
      );

      if (!mounted) return;
      final highlightCount = result.highlights?.length ?? 0;
      final found = result.found == true && highlightCount > 0;
      unawaited(
        AppAnalytics.logScanCompleted(
          found: found,
          highlightCount: highlightCount,
          offline: _offline,
          dictionaryPartialFailure: _pipeline.hadNetworkLookupFailure,
        ),
      );
      await AppCrashlytics.setCustomKeys({
        'highlight_count': highlightCount,
        'scan_found': found,
      });
      await AppCrashlytics.log('Image processing finished');

      setState(() {
        highlightResponse = result;
        isFetchingMeaning = false;
        _status = null;
        _expandedHighlightIndex = null;
      });

      if (!mounted) return;

      if (result.found != true || (result.highlights?.isEmpty ?? true)) {
        UIHelpers.showSnackbar(
          context,
          'No highlighted text found. Use a sharp photo of a book page with highlighter marks.',
        );
      } else if (_offline) {
        UIHelpers.showSnackbar(
          context,
          'Highlighted text found. Definitions will load automatically when you are back online.',
        );
      } else if (_pipeline.hadNetworkLookupFailure &&
          !TextProcessingPipeline.hasAnyLoadedDefinition(
            result.highlights ?? [],
          )) {
        if (kDebugMode) {
          print('Dictionary lookup issue: ${_pipeline.lastMeaningError}');
        }
        UIHelpers.showSnackbar(
          context,
          'Definitions could not be loaded. Check your internet connection.',
        );
      } else {
        UIHelpers.showSnackbar(
          context,
          'Enjoy the highlighted text. If the result looks off, try a higher-resolution photo.',
        );
      }
    } on UnsupportedError catch (e, st) {
      await AppCrashlytics.recordNonFatal(
        e,
        st,
        reason: 'unsupported_device',
      );
      unawaited(AppAnalytics.logScanFailed(reason: 'unsupported_device'));
      _fail(e.message ?? 'This feature is not supported on this device.');
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st, reason: 'image_processing');
      unawaited(AppAnalytics.logScanFailed(reason: 'image_processing'));
      if (kDebugMode) {
        print('Error processing image: $e\n$st');
      }
      _fail(
        'Could not process the image. Try a clear photo of a book page with highlighted text.',
      );
    }
  }

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      isFetchingMeaning = false;
      _status = null;
    });
    UIHelpers.showSnackbar(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final found = highlightResponse?.found ?? false;
    final highlights = highlightResponse?.highlights ?? [];

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: Text(AppConstants.appName),
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              children: [
                ImageCaptureSection(
                  image: _image,
                  isProcessing: isFetchingMeaning,
                  status: _status,
                  offline: _offline,
                  compact: found,
                  onGallery: () => _pickImage(ImageSource.gallery),
                  onCamera: () => _pickImage(ImageSource.camera),
                ),
                const SizedBox(height: 12),
                if (found)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${highlights.length} highlight${highlights.length == 1 ? '' : 's'} — tap to see meaning',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
                    ),
                  ),
                if (found) const SizedBox(height: 8),
                if (_isRefreshingMeanings)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Connection restored — loading definitions…',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Expanded(
                  child: isFetchingMeaning
                      ? UIHelpers.loadingIndicator()
                      : ListView.separated(
                          padding: EdgeInsets.fromLTRB(
                            16,
                            0,
                            16,
                            MediaQuery.paddingOf(context).bottom + 24,
                          ),
                          itemCount: highlights.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final highlight = highlights[index];
                            return ExpandableHighlightCard(
                              highlight: highlight,
                              expanded: _expandedHighlightIndex == index,
                              onTap: () {
                                final expanding =
                                    _expandedHighlightIndex != index;
                                setState(() {
                                  _expandedHighlightIndex =
                                      _expandedHighlightIndex == index
                                          ? null
                                          : index;
                                });
                                if (expanding) {
                                  unawaited(
                                    AppAnalytics.logHighlightExpanded(
                                      index: index,
                                    ),
                                  );
                                }
                              },
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


