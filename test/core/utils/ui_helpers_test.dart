import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/core/utils/camera_permission.dart';
import 'package:highlighted_text_reader/core/utils/ui_helpers.dart';

void main() {
  testWidgets('shows an Open Settings action on a permission snackbar', (
    tester,
  ) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  UIHelpers.showSnackbar(
                    context,
                    CameraPermission.photoMessage,
                    actionLabel: CameraPermission.settingsAction,
                    onAction: () => opened++,
                  );
                },
                child: const Text('Show'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(find.text(CameraPermission.photoMessage), findsOneWidget);
    expect(find.text(CameraPermission.settingsAction), findsOneWidget);
    expect(tester.widget<SnackBar>(find.byType(SnackBar)).duration, const Duration(seconds: 3));
    expect(find.byType(SnackBarAction), findsNothing);

    tester
        .widget<TextButton>(
          find.widgetWithText(TextButton, CameraPermission.settingsAction),
        )
        .onPressed!();
    await tester.pump();
    expect(opened, 1);
  });
}
