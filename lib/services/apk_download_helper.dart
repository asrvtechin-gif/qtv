import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apk_download_stub.dart'
    if (dart.library.html) 'apk_download_web.dart';

class ApkDownloadHelper {
  /// GitHub Release Direct Download URL for app-release.apk
  static const String apkDownloadUrl =
      'https://github.com/asrvtechin-gif/qtv/releases/download/v1.0.0/app-release.apk';

  static Future<void> downloadApk() async {
    if (kIsWeb) {
      triggerWebApkDownload(apkDownloadUrl);
    } else {
      final Uri apkUri = Uri.parse(apkDownloadUrl);
      if (await canLaunchUrl(apkUri)) {
        await launchUrl(apkUri, mode: LaunchMode.externalApplication);
      } else {
        await launchUrl(apkUri);
      }
    }
  }
}
