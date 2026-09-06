import 'package:flutter_test/flutter_test.dart';
import 'package:highlighted_text_reader/core/constants/app_constants.dart';
import 'package:highlighted_text_reader/data/services/quota_request_mailer.dart';

void main() {
  test('no uid returns couldNotSend', () async {
    final mailer = QuotaRequestMailer(
      uidReader: () => null,
      launch: (_) async => true,
    );

    final result = await mailer.send();

    expect(result.outcome, QuotaRequestOutcome.couldNotSend);
    expect(result.uid, isNull);
  });

  test('successful launch returns mailed', () async {
    Uri? launched;
    final mailer = QuotaRequestMailer(
      uidReader: () => 'uid-1',
      launch: (uri) async {
        launched = uri;
        return true;
      },
    );

    final result = await mailer.send();

    expect(result.outcome, QuotaRequestOutcome.mailed);
    expect(result.uid, 'uid-1');
    expect(launched?.scheme, 'mailto');
    expect(launched?.path, AppConstants.supportEmail);
    expect(launched?.queryParameters['subject'], 'Extra scan quota request');
    expect(
      launched?.queryParameters['body'],
      'Please increase my daily scan quota.\nSupport ID: uid-1',
    );
  });

  test('failed launch copies uid and returns copiedId', () async {
    String? copied;
    final mailer = QuotaRequestMailer(
      uidReader: () => 'uid-2',
      launch: (_) async => false,
      copy: (text) async => copied = text,
    );

    final result = await mailer.send();

    expect(result.outcome, QuotaRequestOutcome.copiedId);
    expect(result.uid, 'uid-2');
    expect(copied, 'uid-2');
  });
}
