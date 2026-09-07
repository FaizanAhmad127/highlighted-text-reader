import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/domain/entities/highlight.dart';
import 'package:highlighted_text_reader/presentation/widgets/highlight/expandable_highlight_card.dart';

void main() {
  const highlight = Highlight(
    text: 'a highlighted phrase',
    literal: 'plain meaning',
    contextual: 'used this way here',
    color: '0xFFE8C547',
  );

  testWidgets('tapping the phrase opens the meanings section', (tester) async {
    var tapped = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpandableHighlightCard(
            highlight: highlight,
            expanded: false,
            onTap: () => tapped = true,
          ),
        ),
      ),
    );

    await tester.tap(find.text('a highlighted phrase'));
    await tester.pump();

    expect(tapped, isTrue);
  });

  testWidgets('tapping the bookmark saves without expanding', (tester) async {
    var tapped = false;
    var saved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpandableHighlightCard(
            highlight: highlight,
            expanded: false,
            onTap: () => tapped = true,
            saved: false,
            onSave: () => saved = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Save'));
    await tester.pump();

    expect(saved, isTrue);
    expect(tapped, isFalse);
  });

  testWidgets('tapping a filled bookmark unsaves without expanding', (
    tester,
  ) async {
    var tapped = false;
    var unsaved = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ExpandableHighlightCard(
            highlight: highlight,
            expanded: false,
            onTap: () => tapped = true,
            saved: true,
            onSave: () => unsaved = true,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Unsave'));
    await tester.pump();

    expect(unsaved, isTrue);
    expect(tapped, isFalse);
  });

  testWidgets('renders an optional caption under the phrase', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ExpandableHighlightCard(
            highlight: highlight,
            expanded: false,
            onTap: _noop,
            caption: 'Sep 7, 2026',
          ),
        ),
      ),
    );

    expect(find.text('Sep 7, 2026'), findsOneWidget);
  });
}

void _noop() {}
