import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/constants/app_constants.dart';

enum QuotaRequestOutcome { mailed, copiedId, couldNotSend }

class QuotaRequestResult {
  const QuotaRequestResult(this.outcome, {this.uid});
  final QuotaRequestOutcome outcome;
  final String? uid;
}

class QuotaRequestMailer {
  QuotaRequestMailer({
    Future<bool> Function(Uri uri)? launch,
    String? Function()? uidReader,
    Future<void> Function(String text)? copy,
  })  : _launch = launch,
        _uidReader = uidReader,
        _copy = copy;

  final Future<bool> Function(Uri uri)? _launch;
  final String? Function()? _uidReader;
  final Future<void> Function(String text)? _copy;

  String? _readUid() {
    if (_uidReader != null) return _uidReader();
    return FirebaseAuth.instance.currentUser?.uid;
  }

  Future<bool> _launchMailto(Uri uri) => (_launch ?? _defaultLaunch)(uri);

  static Future<bool> _defaultLaunch(Uri uri) =>
      launchUrl(uri, mode: LaunchMode.externalApplication);

  Future<void> _copyUid(String uid) => (_copy ?? _defaultCopy)(uid);

  static Future<void> _defaultCopy(String text) =>
      Clipboard.setData(ClipboardData(text: text));

  Future<QuotaRequestResult> send() async {
    final uid = _readUid();
    if (uid == null || uid.isEmpty) {
      return const QuotaRequestResult(QuotaRequestOutcome.couldNotSend);
    }

    final uri = Uri(
      scheme: 'mailto',
      path: AppConstants.supportEmail,
      query: _encodeQuery({
        'subject': 'Extra scan quota request',
        'body': 'Please increase my daily scan quota.\nSupport ID: $uid',
      }),
    );

    try {
      if (await _launchMailto(uri)) {
        return QuotaRequestResult(QuotaRequestOutcome.mailed, uid: uid);
      }
    } catch (_) {}

    await _copyUid(uid);
    return QuotaRequestResult(QuotaRequestOutcome.copiedId, uid: uid);
  }

  static String _encodeQuery(Map<String, String> params) {
    return params.entries
        .map((e) =>
            '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }
}
