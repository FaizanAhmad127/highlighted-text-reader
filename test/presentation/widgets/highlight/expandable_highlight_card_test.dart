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
}
