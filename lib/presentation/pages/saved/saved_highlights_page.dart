import 'dart:async';

import 'package:flutter/material.dart';

import '../../../core/firebase/app_analytics.dart';
import '../../../core/firebase/app_crashlytics.dart';
import '../../../data/services/hybrid_saved_highlights_repository.dart';
import '../../../data/services/saved_highlights_query.dart';
import '../../../data/services/saved_highlights_store.dart';
import '../../../data/services/swipe_delete_hint_store.dart';
import '../../../domain/entities/meaning_language.dart';
import '../../../domain/entities/saved_highlight.dart';
import '../../widgets/highlight/expandable_highlight_card.dart';

class SavedHighlightsPage extends StatefulWidget {
  const SavedHighlightsPage({
    super.key,
    this.store,
    this.clock,
    this.pickDate,
    this.swipeHintStore,
  });

  final SavedHighlightsStore? store;
  final DateTime Function()? clock;
  final Future<DateTime?> Function(BuildContext context)? pickDate;
  final SwipeDeleteHintStore? swipeHintStore;

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
      ),
      body: Column(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final filter in SavedDateFilter.values)
                  if (filter != SavedDateFilter.custom)
                    FilterChip(
                      label: Text(_dateLabel(filter)),
                      selected: _dateFilter == filter,
                      onSelected: (_) => setState(() {
                        _dateFilter = filter;
                        _customDay = null;
                      }),
                    ),
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
                ),
              ],
            ),
          ),
          if (languages.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('All'),
                    selected: _languageId == null,
                    onSelected: (_) => setState(() => _languageId = null),
                  ),
                  for (final language in languages)
                    FilterChip(
                      label: Text(language.name),
                      selected: _languageId == language.id,
                      onSelected: (_) => setState(() {
                        _languageId = language.id;
                      }),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Expanded(child: _buildList(theme, result)),
        ],
      ),
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
      padding: EdgeInsets.only(
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
