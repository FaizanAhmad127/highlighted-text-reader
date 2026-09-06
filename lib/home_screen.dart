import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'data/services/meaning_language_store.dart';
import 'data/services/quota_request_mailer.dart';
import 'data/services/quota_request_prompt_store.dart';
import 'data/services/scan_rate_limiter.dart';
import 'domain/entities/highlight.dart';
import 'domain/entities/meaning_language.dart';
import 'presentation/widgets/highlight/expandable_highlight_card.dart';
import 'presentation/widgets/home/extra_quota_dialog.dart';
import 'presentation/widgets/home/image_capture_section.dart';
import 'presentation/widgets/home/meaning_language_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

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

  File? _image;
  HighlightResponse? highlightResponse;
  bool isFetchingMeaning = false;
  String? _status;
  bool _offline = false;
  bool _skipNextConnectivityEvent = true;
  StreamSubscription<dynamic>? _connectivitySub;
  StreamSubscription<void>? _quotaSub;
  StreamSubscription<int>? _limitsSub;
  int? _expandedHighlightIndex;
  MeaningLanguage _meaningLanguage = MeaningLanguage.defaultLanguage;
  int? _scansUsed;
  int? _scansMax;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _loadMeaningLanguage();
    _loadQuotaUsage();
  }

  Future<void> _loadMeaningLanguage() async {
    final language = await _languageStore.read();
    if (!mounted) return;
    setState(() => _meaningLanguage = language);
  }

  Future<void> _loadQuotaUsage() async {
    try {
      await FirebaseBootstrap.ensureAnonymousUser();
      try {
        await _limitsStore.read();
      } catch (_) {}
      try {
        await _quotaStore.ensureAdminPlaceholders();
      } catch (_) {}
      await _refreshQuotaUsage();
      _listenQuotaDoc();
      _listenLimitsDoc();
    } catch (_) {}
  }

  void _listenQuotaDoc() {
    _quotaSub?.cancel();
    try {
      _quotaSub = _quotaStore.snapshots().listen((_) {
        unawaited(_refreshQuotaUsage());
      });
    } catch (_) {}
  }

  void _listenLimitsDoc() {
    _limitsSub?.cancel();
    try {
      _limitsSub = _limitsStore.snapshots().listen((_) {
        unawaited(_refreshQuotaUsage());
      });
    } catch (_) {}
  }

  Future<void> _refreshQuotaUsage() async {
    try {
      final usage = await _rateLimiter.usageToday();
      if (!mounted) return;
      setState(() {
        _scansUsed = usage.used;
        _scansMax = usage.max;
      });
    } catch (_) {}
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _quotaSub?.cancel();
    _limitsSub?.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    await _refreshConnectivity(silent: true);
    if (!mounted) return;
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
        'You are offline. Connect to the internet to scan a page.',
      );
    }
  }

  void _setupConnectivityListener() {
    _connectivitySub = ConnectivityHelper.onConnectivityChanged.listen((results) async {
      if (!mounted) return;

      // Replay of the current state after subscribe — not a real change.
      if (_skipNextConnectivityEvent) {
        _skipNextConnectivityEvent = false;
        return;
      }

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
      }
    });
  }

  Future<void> _pickImage(ImageSource source) async {
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
    });

    final pickedFile = await _picker.pickImage(
      source: source,
      maxWidth: AppConstants.maxImageEdgePx.toDouble(),
      maxHeight: AppConstants.maxImageEdgePx.toDouble(),
      imageQuality: AppConstants.jpegQuality,
    );

    if (!mounted) return;

    if (pickedFile == null) {
      setState(() => _status = null);
      UIHelpers.showSnackbar(context, 'No image selected, try again');
      return;
    }

    setState(() {
      _image = File(pickedFile.path);
      isFetchingMeaning = true;
      _status = 'Preparing photo';
    });
    await _processImage();
  }

  Future<void> _processImage() async {
    final image = _image;
    if (image == null) return;

    final online = await ConnectivityHelper.hasConnection();
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

    await _languageStore.write(selected);
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
      unawaited(_offerExtraQuota(force: false));
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
            onPressed: isFetchingMeaning ? null : _pickMeaningLanguage,
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
                  onGallery: () => _pickImage(ImageSource.gallery),
                  onCamera: () => _pickImage(ImageSource.camera),
                  scansUsed: _scansUsed,
                  scansMax: _scansMax,
                  onRequestExtraQuota: () => unawaited(_offerExtraQuota(force: true)),
                ),
                const SizedBox(height: 12),
                if (found)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${highlights.length} highlight${highlights.length == 1 ? '' : 's'} — tap for literal and in-context meaning',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                      ),
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
