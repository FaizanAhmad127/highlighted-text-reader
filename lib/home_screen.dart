import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import 'core/constants/app_constants.dart';
import 'core/firebase/app_analytics.dart';
import 'core/firebase/app_crashlytics.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/utils/connectivity_helper.dart';
import 'core/utils/ui_helpers.dart';
import 'data/services/firestore_scan_limits_store.dart';
import 'data/services/firestore_scan_quota_store.dart';
import 'data/services/highlight_scan_service.dart';
import 'data/services/hybrid_saved_highlights_repository.dart';
import 'data/services/meaning_language_store.dart';
import 'data/services/quota_request_mailer.dart';
import 'data/services/quota_request_prompt_store.dart';
import 'data/services/saved_highlights_store.dart';
import 'data/services/scan_rate_limiter.dart';
import 'domain/entities/highlight.dart';
import 'domain/entities/meaning_language.dart';
import 'domain/entities/saved_highlight.dart';
import 'presentation/widgets/highlight/expandable_highlight_card.dart';
import 'presentation/widgets/home/extra_quota_dialog.dart';
import 'presentation/widgets/home/image_capture_section.dart';
import 'presentation/widgets/home/meaning_language_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.savedHighlightsStore,
    @visibleForTesting this.debugHighlightResponse,
    @visibleForTesting this.debugMeaningLanguage,
    @visibleForTesting this.debugScanId,
    @visibleForTesting this.debugImage,
    @visibleForTesting this.debugQuotaReady,
  });

  final SavedHighlightsStore? savedHighlightsStore;
  final HighlightResponse? debugHighlightResponse;
  final MeaningLanguage? debugMeaningLanguage;
  final String? debugScanId;
  final File? debugImage;
  final bool? debugQuotaReady;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final HighlightScanService _scan = HighlightScanService();
  final FirestoreScanQuotaStore _quotaStore = FirestoreScanQuotaStore();
  final FirestoreScanLimitsStore _limitsStore = FirestoreScanLimitsStore();
  late final ScanRateLimiter _rateLimiter = ScanRateLimiter(
    store: _quotaStore,
    maxScansPerDayReader: () => _limitsStore.maxScansPerDay,
    cooldown: AppConstants.scanCooldown,
  );
  final ImagePicker _picker = ImagePicker();
  final MeaningLanguageStore _languageStore = MeaningLanguageStore();
  final QuotaRequestMailer _quotaMailer = QuotaRequestMailer();
  final QuotaRequestPromptStore _quotaPromptStore = QuotaRequestPromptStore();
  late final SavedHighlightsStore _savedStore;

  File? _image;
  HighlightResponse? highlightResponse;
  bool isFetchingMeaning = false;
  String? _status;
  bool _offline = false;
  bool _skipNextConnectivityEvent = true;
  StreamSubscription<dynamic>? _connectivitySub;
  StreamSubscription<void>? _quotaSub;
  StreamSubscription<int>? _limitsSub;
  StreamSubscription<List<SavedHighlight>>? _savedSub;
  int? _expandedHighlightIndex;
  MeaningLanguage _meaningLanguage = MeaningLanguage.defaultLanguage;
  int? _scansUsed;
  int? _scansMax;
  bool _quotaReady = false;
  List<SavedHighlight> _saved = [];
  MeaningLanguage? _scanMeaningLanguage;
  String? _currentScanId;

  @override
  void initState() {
    super.initState();
    _savedStore =
        widget.savedHighlightsStore ?? HybridSavedHighlightsRepository.instance;
    if (widget.debugHighlightResponse != null) {
      highlightResponse = widget.debugHighlightResponse;
      _image = widget.debugImage;
      _scanMeaningLanguage =
          widget.debugMeaningLanguage ?? MeaningLanguage.defaultLanguage;
      _currentScanId = widget.debugScanId ?? SavedHighlight.newId();
      _meaningLanguage = _scanMeaningLanguage!;
    }
    _initConnectivity();
    if (widget.debugMeaningLanguage == null) {
      _loadMeaningLanguage();
    }
    if (widget.debugQuotaReady != null) {
      _quotaReady = widget.debugQuotaReady!;
    } else {
      _loadQuotaUsage();
    }
    _listenSavedHighlights();
  }

  Future<void> _loadMeaningLanguage() async {
    try {
      final language = await _languageStore.read();
      if (!mounted) return;
      setState(() => _meaningLanguage = language);
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st,
          reason: 'meaning_language_read');
    }
  }

  Future<void> _loadQuotaUsage() async {
    try {
      await FirebaseBootstrap.ensureAnonymousUser();
      try {
        await _limitsStore.read();
      } catch (e, st) {
        await AppCrashlytics.recordNonFatal(e, st, reason: 'scan_limits_read');
      }
      try {
        await _quotaStore.ensureAdminPlaceholders();
      } catch (e, st) {
        await AppCrashlytics.recordNonFatal(e, st,
            reason: 'quota_placeholders');
      }
      try {
        await _savedStore.current();
      } catch (e, st) {
        await AppCrashlytics.recordNonFatal(
          e,
          st,
          reason: 'saved_highlights_current',
        );
      }
      await _refreshQuotaUsage();
      _listenQuotaDoc();
      _listenLimitsDoc();
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st, reason: 'quota_load');
    } finally {
      _markQuotaReady();
    }
  }

  void _markQuotaReady() {
    if (!mounted || _quotaReady) return;
    setState(() => _quotaReady = true);
  }

  void _listenQuotaDoc() {
    _quotaSub?.cancel();
    try {
      _quotaSub = _quotaStore.snapshots().listen(
        (_) {
          unawaited(_refreshQuotaUsage());
        },
        onError: (Object error, StackTrace stack) {
          AppCrashlytics.record(error, stack, reason: 'quota_watch');
        },
      );
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'quota_watch');
    }
  }

  void _listenLimitsDoc() {
    _limitsSub?.cancel();
    try {
      _limitsSub = _limitsStore.snapshots().listen(
        (_) {
          unawaited(_refreshQuotaUsage());
        },
        onError: (Object error, StackTrace stack) {
          AppCrashlytics.record(error, stack, reason: 'scan_limits_watch');
        },
      );
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'scan_limits_watch');
    }
  }

  void _listenSavedHighlights() {
    _savedSub?.cancel();
    try {
      _savedSub = _savedStore.watch().listen(
        (items) {
          if (!mounted) return;
          setState(() => _saved = items);
        },
        onError: (Object error, StackTrace stack) {
          AppCrashlytics.record(error, stack, reason: 'saved_highlights_watch');
        },
      );
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'saved_highlights_watch');
    }
  }

  String get _activeMeaningLanguageId =>
      _scanMeaningLanguage?.id ?? _meaningLanguage.id;

  bool _isHighlightSaved(Highlight highlight) {
    final key = SavedHighlight.dedupKeyFor(
      highlight.text,
      _activeMeaningLanguageId,
    );
    return _saved.any((item) => item.dedupKey == key);
  }

  SavedHighlight? _savedItemFor(Highlight highlight) {
    final key = SavedHighlight.dedupKeyFor(
      highlight.text,
      _activeMeaningLanguageId,
    );
    for (final item in _saved) {
      if (item.dedupKey == key) return item;
    }
    return null;
  }

  void _showSaveResult(SavedHighlightsWriteResult result,
      {required String method}) {
    if (!mounted) return;
    if (result.savedCount == 0) {
      UIHelpers.showSnackbar(
        context,
        method == 'all'
            ? 'All highlights are already saved.'
            : 'Already saved.',
      );
      return;
    }
    unawaited(
      AppAnalytics.logHighlightSaved(
        count: result.savedCount,
        method: method,
      ),
    );
    if (result.pendingSync) {
      UIHelpers.showSnackbar(
        context,
        'Saved on this device. It will sync when you\'re back online.',
      );
    } else if (method == 'all') {
      UIHelpers.showSnackbar(
        context,
        result.savedCount == 1
            ? 'Saved 1 highlight.'
            : 'Saved ${result.savedCount} highlights.',
      );
    } else {
      UIHelpers.showSnackbar(context, 'Saved to your library.');
    }
  }

  Future<void> _toggleSave(Highlight highlight) async {
    final existing = _savedItemFor(highlight);
    if (existing != null) {
      await _savedStore.delete(existing.id);
      unawaited(AppAnalytics.logSavedDeleted());
      if (!mounted) return;
      UIHelpers.showSnackbar(context, 'Removed from your library.');
      return;
    }
    await _saveOne(highlight);
  }

  Future<void> _saveOne(Highlight highlight) async {
    final result = await _savedStore.save(
      highlight,
      meaningLanguageId: _activeMeaningLanguageId,
      scanId: _ensureScanId(),
    );
    if (!mounted) return;
    _showSaveResult(result, method: 'one');
  }

  Future<void> _saveAll(List<Highlight> highlights) async {
    final result = await _savedStore.saveAll(
      highlights,
      meaningLanguageId: _activeMeaningLanguageId,
      scanId: _ensureScanId(),
    );
    if (!mounted) return;
    _showSaveResult(result, method: 'all');
  }

  String _ensureScanId() => _currentScanId ??= SavedHighlight.newId();

  Future<void> _refreshQuotaUsage() async {
    try {
      final usage = await _rateLimiter.usageToday();
      if (!mounted) return;
      setState(() {
        _scansUsed = usage.used;
        _scansMax = usage.max;
        _quotaReady = true;
      });
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st, reason: 'quota_refresh');
      _markQuotaReady();
    }
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _quotaSub?.cancel();
    _limitsSub?.cancel();
    _savedSub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    await _refreshConnectivity(silent: true);
    if (!mounted) return;
    _setupConnectivityListener();
  }

  Future<void> _refreshConnectivity({required bool silent}) async {
    try {
      final online = await ConnectivityHelper.hasConnection();
      if (!mounted) return;
      setState(() => _offline = !online);
      if (!silent && !online) {
        unawaited(AppAnalytics.logConnectivityChanged(offline: true));
        UIHelpers.showSnackbar(
          context,
          'You are offline. Connect to the internet to scan a page.',
        );
      }
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st, reason: 'connectivity_check');
    }
  }

  void _setupConnectivityListener() {
    try {
      _connectivitySub = ConnectivityHelper.onConnectivityChanged.listen(
        (results) async {
          if (!mounted) return;

          // Replay of the current state after subscribe — not a real change.
          if (_skipNextConnectivityEvent) {
            _skipNextConnectivityEvent = false;
            return;
          }

          try {
            // iOS NWPathMonitor often emits a spurious "none". Confirm before flipping UI.
            var online = ConnectivityHelper.hasActiveInterface(results);
            if (!online) {
              online = await ConnectivityHelper.hasConnection();
            }
            if (!mounted) return;

            final nowOffline = !online;
            final wasOffline = _offline;
            if (nowOffline == wasOffline) return;

            setState(() => _offline = nowOffline);

            if (nowOffline) {
              unawaited(AppAnalytics.logConnectivityChanged(offline: true));
              UIHelpers.showSnackbar(
                context,
                'You are offline. Connect to the internet to scan a page.',
              );
            } else {
              unawaited(AppAnalytics.logConnectivityChanged(offline: false));
              UIHelpers.showSnackbar(
                context,
                'Back online. You can scan a page now.',
                icon: Icons.wifi,
              );
              unawaited(_refreshQuotaUsage());
              AppCrashlytics.capture(
                _savedStore.flushPendingSync(),
                reason: 'saved_highlights_flush',
              );
            }
          } catch (e, st) {
            await AppCrashlytics.recordNonFatal(
              e,
              st,
              reason: 'connectivity_watch',
            );
          }
        },
        onError: (Object error, StackTrace stack) {
          AppCrashlytics.record(error, stack, reason: 'connectivity_watch');
        },
      );
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'connectivity_watch');
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    if (!_quotaReady) return;

    if (_offline) {
      unawaited(AppAnalytics.logScanFailed(reason: 'offline'));
      UIHelpers.showSnackbar(
        context,
        'You are offline. Connect to the internet to scan a page.',
      );
      return;
    }

    if (!await _ensureCanScan()) return;

    final sourceName = source == ImageSource.camera ? 'camera' : 'gallery';
    unawaited(AppAnalytics.logImageSelected(source: sourceName));
    await AppCrashlytics.log('Image pick started: $sourceName');

    setState(() {
      highlightResponse = null;
      _expandedHighlightIndex = null;
      _status = null;
      _currentScanId = null;
      _scanMeaningLanguage = null;
    });

    final XFile? pickedFile;
    try {
      pickedFile = await _picker.pickImage(
        source: source,
        maxWidth: AppConstants.maxImageEdgePx.toDouble(),
        maxHeight: AppConstants.maxImageEdgePx.toDouble(),
        imageQuality: AppConstants.jpegQuality,
      );
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st, reason: 'image_pick');
      if (!mounted) return;
      setState(() => _status = null);
      UIHelpers.showSnackbar(
        context,
        'Could not open the camera or gallery. Try again.',
      );
      return;
    }

    if (!mounted) return;

    final selected = pickedFile;
    if (selected == null) {
      setState(() => _status = null);
      UIHelpers.showSnackbar(context, 'No image selected, try again');
      return;
    }

    setState(() {
      _image = File(selected.path);
      isFetchingMeaning = true;
      _status = 'Preparing photo';
    });
    await _processImage();
  }

  Future<void> _processImage() async {
    final image = _image;
    if (image == null) return;

    final bool online;
    try {
      online = await ConnectivityHelper.hasConnection();
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st, reason: 'connectivity_check');
      if (!mounted) return;
      _fail('Could not check your connection. Try again.');
      return;
    }
    if (!mounted) return;
    setState(() => _offline = !online);

    if (!online) {
      unawaited(AppAnalytics.logScanFailed(reason: 'offline'));
      _fail('Connect to the internet to scan a page.');
      return;
    }

    try {
      await FirebaseBootstrap.ensureAnonymousUser();
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st, reason: 'anonymous_auth');
      unawaited(AppAnalytics.logScanFailed(reason: 'anonymous_auth'));
      _fail('Scanning is temporarily unavailable. Please try again later.');
      return;
    }

    if (!await _ensureCanScan()) {
      if (!mounted) return;
      setState(() {
        isFetchingMeaning = false;
        _status = null;
      });
      return;
    }

    unawaited(AppAnalytics.logScanStarted(offline: _offline));

    setState(() => isFetchingMeaning = true);
    await AppCrashlytics.setCustomKeys({
      'offline': _offline,
    });
    await AppCrashlytics.log('Image processing started');

    try {
      final result = await _scan.scan(
        image,
        meaningLanguage: _meaningLanguage,
        onStatus: (status) {
          if (!mounted) return;
          setState(() => _status = status);
        },
      );

      if (!mounted) return;
      try {
        await _rateLimiter.recordAttempt();
        await _refreshQuotaUsage();
      } catch (e, st) {
        await AppCrashlytics.recordNonFatal(e, st, reason: 'scan_quota');
      }
      final highlightCount = result.highlights?.length ?? 0;
      final found = result.found == true && highlightCount > 0;
      unawaited(
        AppAnalytics.logScanCompleted(
          found: found,
          highlightCount: highlightCount,
          offline: _offline,
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
        _scanMeaningLanguage = _meaningLanguage;
        _currentScanId = found ? SavedHighlight.newId() : null;
      });

      if (!mounted) return;

      if (result.found != true || (result.highlights?.isEmpty ?? true)) {
        UIHelpers.showSnackbar(
          context,
          'No highlighted text found. Use a sharp photo of a book page with highlighter marks.',
        );
      } else {
        UIHelpers.showSnackbar(
          context,
          'Enjoy the highlighted text. Tap a phrase for literal and in-context meaning.',
        );
      }
    } on HighlightScanException catch (e, st) {
      if (kDebugMode) {
        print('HighlightScanException cause: ${e.cause ?? e}');
      }
      await AppCrashlytics.recordNonFatal(
        e.cause ?? e,
        st,
        reason: 'highlight_scan',
      );
      unawaited(AppAnalytics.logScanFailed(reason: 'highlight_scan'));
      _fail(e.userMessage);
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
      _fail(
        'Could not process the image. Try a clear photo of a book page with highlighted text.',
      );
    }
  }

  Future<void> _pickMeaningLanguage() async {
    final selected = await MeaningLanguageSheet.show(
      context,
      selected: _meaningLanguage,
    );
    if (selected == null || !mounted || selected == _meaningLanguage) return;

    try {
      await _languageStore.write(selected);
    } catch (e, st) {
      await AppCrashlytics.recordNonFatal(e, st,
          reason: 'meaning_language_write');
      if (!mounted) return;
      UIHelpers.showSnackbar(
          context, 'Could not save the language. Try again.');
      return;
    }
    if (!mounted) return;
    setState(() => _meaningLanguage = selected);

    final nextLabel = selected.matchesHighlight
        ? 'the same language as the highlighted text'
        : selected.name;
    UIHelpers.showSnackbar(
      context,
      'Meanings will use $nextLabel on the next scan.',
    );
  }

  Future<bool> _ensureCanScan() async {
    final decision = await _rateLimiter.check();
    if (decision.allowed) return true;
    if (!mounted) return false;

    final reason = decision.userMessage == ScanRateLimiter.dailyLimitMessage
        ? 'daily_limit'
        : decision.userMessage == ScanRateLimiter.cooldownMessage
            ? 'cooldown'
            : 'scan_quota';
    unawaited(AppAnalytics.logScanFailed(reason: reason));
    UIHelpers.showSnackbar(context, decision.userMessage!);
    if (reason == 'daily_limit') {
      AppCrashlytics.capture(
        _offerExtraQuota(force: false),
        reason: 'quota_request',
      );
    }
    return false;
  }

  String _todayKey() {
    final now = DateTime.now();
    final month = now.month.toString().padLeft(2, '0');
    final day = now.day.toString().padLeft(2, '0');
    return '${now.year}-$month-$day';
  }

  Future<void> _offerExtraQuota({required bool force}) async {
    final today = _todayKey();
    if (!force && !await _quotaPromptStore.shouldPrompt(today)) return;
    if (!mounted) return;

    await _quotaPromptStore.markPrompted(today);
    if (!mounted) return;
    final wantsExtra = await ExtraQuotaDialog.show(context);
    if (wantsExtra != true || !mounted) return;
    await _sendQuotaRequest();
  }

  Future<void> _sendQuotaRequest() async {
    final result = await _quotaMailer.send();
    if (!mounted) return;
    switch (result.outcome) {
      case QuotaRequestOutcome.mailed:
        UIHelpers.showSnackbar(
          context,
          'Send the email to finish your extra-scan request.',
        );
      case QuotaRequestOutcome.copiedId:
        UIHelpers.showSnackbar(
          context,
          'Could not open Mail. Support ID copied. Send it to ${AppConstants.supportEmail}.',
        );
      case QuotaRequestOutcome.couldNotSend:
        UIHelpers.showSnackbar(
          context,
          'Could not start the request. Please try again later.',
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
        actions: [
          IconButton(
            tooltip: 'Meaning language',
            icon: const Icon(Icons.translate),
            onPressed: isFetchingMeaning
                ? null
                : () => AppCrashlytics.capture(
                      _pickMeaningLanguage(),
                      reason: 'meaning_language',
                    ),
          ),
          IconButton(
            tooltip: 'Saved highlights',
            icon: const Icon(Icons.bookmarks_outlined),
            onPressed: () => context.push(AppConstants.savedRoute),
          ),
        ],
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
                  quotaReady: _quotaReady,
                  onGallery: () => AppCrashlytics.capture(
                    _pickImage(ImageSource.gallery),
                    reason: 'image_pick',
                  ),
                  onCamera: () => AppCrashlytics.capture(
                    _pickImage(ImageSource.camera),
                    reason: 'image_pick',
                  ),
                  scansUsed: _scansUsed,
                  scansMax: _scansMax,
                  onRequestExtraQuota: () => AppCrashlytics.capture(
                    _offerExtraQuota(force: true),
                    reason: 'quota_request',
                  ),
                ),
                const SizedBox(height: 12),
                if (found)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '${highlights.length} highlight${highlights.length == 1 ? '' : 's'} — tap for literal and in-context meaning',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                          ),
                        ),
                        TextButton(
                          onPressed: isFetchingMeaning ||
                                  highlights.every(_isHighlightSaved)
                              ? null
                              : () => AppCrashlytics.capture(
                                    _saveAll(
                                      highlights
                                          .where((h) => !_isHighlightSaved(h))
                                          .toList(),
                                    ),
                                    reason: 'highlight_save_all',
                                  ),
                          child: Text(
                            highlights.isNotEmpty &&
                                    highlights.every(_isHighlightSaved)
                                ? 'All saved'
                                : 'Save all',
                          ),
                        ),
                      ],
                    ),
                  ),
                if (found) const SizedBox(height: 8),
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
                          separatorBuilder: (_, __) =>
                              const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final highlight = highlights[index];
                            return ExpandableHighlightCard(
                              highlight: highlight,
                              expanded: _expandedHighlightIndex == index,
                              saved: _isHighlightSaved(highlight),
                              onSave: () => AppCrashlytics.capture(
                                _toggleSave(highlight),
                                reason: 'highlight_save',
                              ),
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
