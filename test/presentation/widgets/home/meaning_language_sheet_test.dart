import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/domain/entities/meaning_language.dart';
import 'package:highlighted_text_reader/presentation/widgets/home/meaning_language_sheet.dart';

void main() {
  testWidgets('selecting Urdu returns that language', (tester) async {
    MeaningLanguage? picked;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () async {
                  picked = await MeaningLanguageSheet.show(
                    context,
                    selected: MeaningLanguage.english,
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Urdu'),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.tap(find.text('Urdu'));
    await tester.pumpAndSettle();

    expect(picked?.id, 'ur');
  });
}
