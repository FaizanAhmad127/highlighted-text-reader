import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/firebase/app_analytics.dart';
import '../../../core/firebase/app_crashlytics.dart';
import '../../../core/utils/camera_permission.dart';
import '../../../core/utils/connectivity_helper.dart';
import '../../../core/utils/ui_helpers.dart';
import '../../../data/services/highlight_transfer_service.dart';
import '../../../data/services/hybrid_saved_highlights_repository.dart';
import '../../../data/services/saved_highlights_query.dart';
import '../../../data/services/saved_highlights_store.dart';
import '../../../data/services/swipe_delete_hint_store.dart';
import '../../../domain/entities/meaning_language.dart';
import '../../../domain/entities/saved_highlight.dart';
import '../../widgets/highlight/expandable_highlight_card.dart';
import '../../widgets/layout/collapsing_header_scroll_view.dart';
import 'highlight_qr_scanner_page.dart';
import 'highlight_transfer_qr_dialog.dart';

class SavedHighlightsPage extends StatefulWidget {
  const SavedHighlightsPage({
    super.key,
    this.store,
    this.clock,
    this.pickDate,
    this.swipeHintStore,
    this.transferService,
    this.hasConnection,
    this.isSignedIn,
    this.scanQr,
    this.requestCameraPermission,
    this.openAppSettings,
  });

  final SavedHighlightsStore? store;
  final DateTime Function()? clock;
  final Future<DateTime?> Function(BuildContext context)? pickDate;
  final SwipeDeleteHintStore? swipeHintStore;
  final HighlightTransferService? transferService;
  final Future<bool> Function()? hasConnection;
  final bool Function()? isSignedIn;
  final Future<String?> Function(BuildContext context)? scanQr;
  final Future<bool> Function()? requestCameraPermission;
  final Future<void> Function()? openAppSettings;

  @override
  State<SavedHighlightsPage> createState() => _SavedHighlightsPageState();
}

class _SavedHighlightsPageState extends State<SavedHighlightsPage> {
  late final SavedHighlightsStore _store;
  late final DateTime Function() _clock;
  late final SwipeDeleteHintStore _hintStore;
  final _searchController = TextEditingController();

  StreamSubscription<List<SavedHighlight>>? _sub;
  List<SavedHighlight> _items = [];
  String _query = '';
  SavedDateFilter _dateFilter = SavedDateFilter.all;
  DateTime? _customDay;
  String? _languageId;
  String? _expandedId;
  bool _playSwipeHint = false;
  bool _hintChecked = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? HybridSavedHighlightsRepository.instance;
    _clock = widget.clock ?? DateTime.now;
    _hintStore = widget.swipeHintStore ?? SwipeDeleteHintStore();
    unawaited(AppAnalytics.logSavedOpened());
    try {
      _sub = _store.watch().listen(
        (items) {
          if (!mounted) return;
          setState(() => _items = items);
          unawaited(_maybeStartSwipeHint());
        },
        onError: (Object error, StackTrace stack) {
          AppCrashlytics.record(error, stack, reason: 'saved_highlights_watch');
        },
      );
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'saved_highlights_watch');
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _maybeStartSwipeHint() async {
    if (_hintChecked || _items.isEmpty) return;
    _hintChecked = true;
    if (!_hintStore.shouldShow() || _items.isEmpty) return;
    _hintStore.markShown();
    setState(() => _playSwipeHint = true);
  }

  void _onSwipeHintPlayed() {
    if (!mounted) return;
    setState(() => _playSwipeHint = false);
  }

  Future<void> _delete(SavedHighlight item) async {
    await _store.delete(item.id);
    unawaited(AppAnalytics.logSavedDeleted());
  }

  HighlightTransferService get _transfers =>
      widget.transferService ?? HighlightTransferService();

  bool _defaultSignedIn() {
    try {
      return FirebaseAuth.instance.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  Future<bool> _onlineAndSignedIn() async {
    final signedIn = widget.isSignedIn?.call() ?? _defaultSignedIn();
    if (!signedIn) {
      UIHelpers.showSnackbar(context, 'Sign in failed. Try again in a moment.');
      return false;
    }
    final online =
        await (widget.hasConnection ?? ConnectivityHelper.hasConnection)();
    if (!online) {
      if (!mounted) return false;
      UIHelpers.showSnackbar(
          context, 'Connect to the internet to transfer highlights.');
      return false;
    }
    return true;
  }

  String _transferErrorMessage(HighlightTransferError error) {
    switch (error) {
      case HighlightTransferError.empty:
        return 'Save a highlight before sharing.';
      case HighlightTransferError.tooLarge:
        return 'Too many highlights to share at once.';
      case HighlightTransferError.notFound:
        return 'That QR code was not found.';
      case HighlightTransferError.expired:
        return 'That QR code has expired.';
      case HighlightTransferError.invalidQr:
        return 'That QR code is not a highlight transfer.';
    }
  }

  Future<void> _shareViaQr() async {
    if (!await _onlineAndSignedIn()) return;
    try {
      final session = await _transfers.create(_items);
      unawaited(
        AppAnalytics.logHighlightTransferCreated(count: session.itemCount),
      );
      if (!mounted) return;
      await showHighlightTransferQrDialog(context, session: session);
    } on HighlightTransferException catch (e) {
      if (!mounted) return;
      UIHelpers.showSnackbar(context, _transferErrorMessage(e.error));
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'highlight_transfer_create');
      if (!mounted) return;
      UIHelpers.showSnackbar(context, 'Could not create a share code.');
    }
  }

  Future<bool> _ensureCameraPermission() async {
    final request = widget.requestCameraPermission ?? CameraPermission.request;
    final granted = await request();
    if (granted) return true;
    if (!mounted) return false;
    UIHelpers.showSnackbar(
      context,
      CameraPermission.qrMessage,
      actionLabel: CameraPermission.settingsAction,
      onAction: () {
        unawaited((widget.openAppSettings ?? CameraPermission.openSettings)());
      },
    );
    return false;
  }

  Future<void> _importViaQr() async {
    if (!await _onlineAndSignedIn()) return;
    if (!mounted) return;
    if (!await _ensureCameraPermission()) return;
    if (!mounted) return;
    final raw = widget.scanQr != null
        ? await widget.scanQr!(context)
        : await Navigator.of(context).push<String>(
            MaterialPageRoute(
              builder: (_) => HighlightQrScannerPage(
                openAppSettings: widget.openAppSettings,
              ),
            ),
          );
    if (!mounted || raw == null || raw.isEmpty) return;
    try {
      final incoming = await _transfers.fetchFromQr(raw);
      final result = await _store.importAll(incoming);
      unawaited(
        AppAnalytics.logHighlightTransferImported(
          importedCount: result.savedCount,
          skippedCount: incoming.length - result.savedCount,
        ),
      );
      if (!mounted) return;
      if (result.savedCount == 0) {
        UIHelpers.showSnackbar(
          context,
          incoming.length == 1
              ? 'Already saved.'
              : 'All ${incoming.length} were already saved.',
        );
      } else {
        UIHelpers.showSnackbar(
          context,
          result.savedCount == 1
              ? 'Added 1 highlight.'
              : 'Added ${result.savedCount} highlights.',
        );
      }
    } on HighlightTransferException catch (e) {
      if (!mounted) return;
      UIHelpers.showSnackbar(context, _transferErrorMessage(e.error));
    } catch (e, st) {
      AppCrashlytics.record(e, st, reason: 'highlight_transfer_import');
      if (!mounted) return;
      UIHelpers.showSnackbar(context, 'Could not import highlights.');
    }
  }

  Future<void> _pickCustomDate() async {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final initial = _customDay ?? today;
    final picked = widget.pickDate != null
        ? await widget.pickDate!(context)
        : await showDatePicker(
            context: context,
            initialDate: initial.isAfter(today) ? today : initial,
            firstDate: DateTime(now.year - 20),
            lastDate: today,
          );
    if (!mounted || picked == null) return;
    setState(() {
      _dateFilter = SavedDateFilter.custom;
      _customDay = DateTime(picked.year, picked.month, picked.day);
    });
  }

  void _clearSearch() {
    _searchController.clear();
    setState(() => _query = '');
  }

  String _formatDay(DateTime day) {
    final now = _clock();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(day.year, day.month, day.day);
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return _formatChipDate(date);
  }

  String _formatChipDate(DateTime date) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}, ${date.year}';
  }

  String _formatTime(DateTime time) {
    final local = time.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final suffix = local.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $suffix';
  }

  List<MeaningLanguage> _languagesInLibrary() {
    final languages = [
      for (final id in SavedHighlightsQuery.distinctLanguageIds(_items))
        MeaningLanguage(
          id: id,
          name: MeaningLanguageCatalog.byId(id).name,
        ),
    ];
    languages.sort((a, b) => a.name.compareTo(b.name));
    return languages;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = SavedHighlightsQuery.apply(
      _items,
      query: _query,
      dateFilter: _dateFilter,
      customDay: _customDay,
      languageId: _languageId,
      now: _clock(),
    );
    final languages = _languagesInLibrary();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved highlights'),
        elevation: 0,
        scrolledUnderElevation: 1,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Transfer highlights',
            onSelected: (value) {
              if (value == 'share') {
                unawaited(_shareViaQr());
              } else if (value == 'import') {
                unawaited(_importViaQr());
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'share',
                enabled: _items.isNotEmpty,
                child: const Text('Share via QR'),
              ),
              const PopupMenuItem(
                value: 'import',
                child: Text('Import via QR'),
              ),
            ],
          ),
        ],
      ),
      body: result.items.isEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _searchAndFilters(languages),
                Expanded(child: _buildList(theme, result)),
              ],
            )
          : CollapsingHeaderScrollView(
              header: _searchAndFilters(languages),
              body: _buildList(theme, result),
            ),
    );
  }

  Widget _searchAndFilters(List<MeaningLanguage> languages) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: TextField(
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Search highlighted phrases',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.clear),
                      onPressed: _clearSearch,
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) => setState(() => _query = value),
          ),
        ),
        _horizontalChipScroller(
          rowKey: const Key('savedDateFilters'),
          selectionKey: ValueKey(_dateFilter),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          children: [
            for (final filter in _dateFiltersWithSelectedFirst())
              if (filter == SavedDateFilter.custom)
                FilterChip(
                  avatar: Icon(
                    Icons.calendar_today,
                    size: 18,
                    color: _dateFilter == SavedDateFilter.custom
                        ? Theme.of(context).colorScheme.onSecondaryContainer
                        : null,
                  ),
                  label: Text(
                    _customDay == null
                        ? 'Custom'
                        : _formatChipDate(_customDay!),
                  ),
                  selected: _dateFilter == SavedDateFilter.custom,
                  showCheckmark: false,
                  onSelected: (_) => AppCrashlytics.capture(
                    _pickCustomDate(),
                    reason: 'saved_date_picker',
                  ),
                )
              else
                FilterChip(
                  label: Text(_dateLabel(filter)),
                  selected: _dateFilter == filter,
                  onSelected: (_) => setState(() {
                    _dateFilter = filter;
                    _customDay = null;
                  }),
                ),
          ],
        ),
        if (languages.isNotEmpty)
          _horizontalChipScroller(
            rowKey: const Key('savedLanguageFilters'),
            selectionKey: ValueKey(_languageId),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            children: [
              for (final language in _languagesWithSelectedFirst(languages))
                if (language == null)
                  FilterChip(
                    label: const Text('All'),
                    selected: _languageId == null,
                    onSelected: (_) => setState(() => _languageId = null),
                  )
                else
                  FilterChip(
                    label: Text(language.name),
                    selected: _languageId == language.id,
                    onSelected: (_) =>
                        setState(() => _languageId = language.id),
                  ),
            ],
          ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildList(ThemeData theme, SavedHighlightsQueryResult result) {
    if (_items.isEmpty) {
      return const _EmptyState(
        title: 'No saved highlights yet',
        message: 'Save phrases from a scan to see them here.',
      );
    }
    if (result.items.isEmpty) {
      return const _EmptyState(
        title: 'No highlights match these filters',
        message: 'Try a different search, date, or language.',
      );
    }

    final children = <Widget>[];
    var isFirstCard = true;
    for (final section in result.sections) {
      children.add(
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Text(
            _formatDay(section.day),
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      );
      for (final group in section.groups) {
        final cards = <Widget>[];
        for (var i = 0; i < group.items.length; i++) {
          final item = group.items[i];
          final playHint = isFirstCard && _playSwipeHint;
          isFirstCard = false;
          cards.add(
            Padding(
              padding: EdgeInsets.only(
                bottom: i == group.items.length - 1 ? 0 : 8,
              ),
              child: _dismissibleCard(theme, item, playHint: playHint),
            ),
          );
        }
        children.add(_scanGroupShell(theme, group, cards));
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.only(
        top: 8,
        bottom: MediaQuery.paddingOf(context).bottom + 24,
      ),
      children: children,
    );
  }

  Widget _scanGroupShell(
    ThemeData theme,
    SavedScanGroup group,
    List<Widget> cards,
  ) {
    final showHeader = group.items.length > 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (showHeader)
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                  child: Text(
                    '${group.items.length} from this scan',
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ...cards,
            ],
          ),
        ),
      ),
    );
  }

  Widget _dismissibleCard(
    ThemeData theme,
    SavedHighlight item, {
    required bool playHint,
  }) {
    final background = Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 16),
      decoration: BoxDecoration(
        color: theme.colorScheme.error,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        Icons.delete,
        color: theme.colorScheme.onError,
      ),
    );
    final dismissible = Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      background: background,
      confirmDismiss: (_) async => !_playSwipeHint,
      onDismissed: (_) => AppCrashlytics.capture(
        _delete(item),
        reason: 'saved_highlights_delete',
      ),
      child: ExpandableHighlightCard(
        highlight: item.highlight,
        expanded: _expandedId == item.id,
        caption: _formatTime(item.savedAt),
        onTap: () {
          setState(() {
            _expandedId = _expandedId == item.id ? null : item.id;
          });
        },
      ),
    );
    if (!playHint) return dismissible;
    return _SwipeDeleteHint(
      background: background,
      onPlayed: _onSwipeHintPlayed,
      child: dismissible,
    );
  }

  Widget _horizontalChipScroller({
    required Key rowKey,
    required Key selectionKey,
    required EdgeInsetsGeometry padding,
    required List<Widget> children,
  }) {
    return _FadingHorizontalChipRow(
      key: selectionKey,
      rowKey: rowKey,
      padding: padding,
      children: children,
    );
  }

  List<SavedDateFilter> _dateFiltersWithSelectedFirst() {
    return _withSelectedFirst(
      [
        for (final filter in SavedDateFilter.values)
          if (filter != SavedDateFilter.custom) filter,
        SavedDateFilter.custom,
      ],
      (filter) => filter == _dateFilter,
    );
  }

  List<MeaningLanguage?> _languagesWithSelectedFirst(
    List<MeaningLanguage> languages,
  ) {
    return _withSelectedFirst<MeaningLanguage?>(
      [null, ...languages],
      (language) => language?.id == _languageId,
    );
  }

  List<T> _withSelectedFirst<T>(
    List<T> items,
    bool Function(T item) isSelected,
  ) {
    final index = items.indexWhere(isSelected);
    if (index <= 0) return items;
    return [
      items[index],
      ...items.sublist(0, index),
      ...items.sublist(index + 1),
    ];
  }

  String _dateLabel(SavedDateFilter filter) {
    switch (filter) {
      case SavedDateFilter.all:
        return 'All';
      case SavedDateFilter.today:
        return 'Today';
      case SavedDateFilter.thisWeek:
        return 'This week';
      case SavedDateFilter.thisMonth:
        return 'This month';
      case SavedDateFilter.custom:
        return 'Custom';
    }
  }
}

class _FadingHorizontalChipRow extends StatefulWidget {
  const _FadingHorizontalChipRow({
    super.key,
    required this.rowKey,
    required this.padding,
    required this.children,
  });

  final Key rowKey;
  final EdgeInsetsGeometry padding;
  final List<Widget> children;

  @override
  State<_FadingHorizontalChipRow> createState() =>
      _FadingHorizontalChipRowState();
}

class _FadingHorizontalChipRowState extends State<_FadingHorizontalChipRow> {
  final _controller = ScrollController();
  var _canScrollStart = false;
  var _canScrollEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_updateFades);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void didUpdateWidget(covariant _FadingHorizontalChipRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateFades());
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_updateFades)
      ..dispose();
    super.dispose();
  }

  void _updateFades() {
    if (!_controller.hasClients) return;
    final position = _controller.position;
    final canStart = position.pixels > 0.5;
    final canEnd = position.maxScrollExtent - position.pixels > 0.5;
    if (canStart == _canScrollStart && canEnd == _canScrollEnd) return;
    setState(() {
      _canScrollStart = canStart;
      _canScrollEnd = canEnd;
    });
  }

  @override
  Widget build(BuildContext context) {
    final fadeColor = Theme.of(context).scaffoldBackgroundColor;
    return Stack(
      children: [
        SingleChildScrollView(
          key: widget.rowKey,
          controller: _controller,
          scrollDirection: Axis.horizontal,
          padding: widget.padding,
          child: Row(
            children: [
              for (var i = 0; i < widget.children.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                widget.children[i],
              ],
            ],
          ),
        ),
        if (_canScrollStart)
          _ScrollEdgeFade(
            key: ValueKey('startFade:${_keyName(widget.rowKey)}'),
            alignment: Alignment.centerLeft,
            color: fadeColor,
          ),
        if (_canScrollEnd)
          _ScrollEdgeFade(
            key: ValueKey('endFade:${_keyName(widget.rowKey)}'),
            alignment: Alignment.centerRight,
            color: fadeColor,
          ),
      ],
    );
  }

  String _keyName(Key key) {
    if (key is ValueKey) return '${key.value}';
    return key.toString();
  }
}

class _ScrollEdgeFade extends StatelessWidget {
  const _ScrollEdgeFade({
    super.key,
    required this.alignment,
    required this.color,
  });

  final Alignment alignment;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fadeRight = alignment == Alignment.centerRight;
    return Positioned(
      left: fadeRight ? null : 0,
      right: fadeRight ? 0 : null,
      top: 0,
      bottom: 0,
      width: 28,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: fadeRight ? Alignment.centerLeft : Alignment.centerRight,
              end: fadeRight ? Alignment.centerRight : Alignment.centerLeft,
              colors: [
                color.withValues(alpha: 0),
                color,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SwipeDeleteHint extends StatefulWidget {
  const _SwipeDeleteHint({
    required this.background,
    required this.child,
    required this.onPlayed,
  });

  final Widget background;
  final Widget child;
  final VoidCallback onPlayed;

  @override
  State<_SwipeDeleteHint> createState() => _SwipeDeleteHintState();
}

class _SwipeDeleteHintState extends State<_SwipeDeleteHint>
    with SingleTickerProviderStateMixin {
  static const _slideDuration = Duration(milliseconds: 1000);
  static const _pauseDuration = Duration(milliseconds: 180);

  late final AnimationController _controller;
  late final Animation<double> _slide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _slideDuration,
    );
    _slide = Tween<double>(begin: 0, end: -72).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
    unawaited(_run());
  }

  Future<void> _run() async {
    await _controller.forward();
    await Future<void>.delayed(_pauseDuration);
    if (!mounted) return;
    await _controller.reverse();
    if (!mounted) return;
    widget.onPlayed();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _slide,
      builder: (context, child) {
        return Stack(
          children: [
            Positioned.fill(child: widget.background),
            Transform.translate(
              offset: Offset(_slide.value, 0),
              child: child,
            ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
