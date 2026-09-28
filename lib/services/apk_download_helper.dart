import 'package:flutter/foundation.dart';
import 'package:url_launcher/url_launcher.dart';

import 'apk_download_stub.dart'
    if (dart.library.html) 'apk_download_web.dart';

class ApkDownloadHelper {
  /// Cloudinary Raw File Download URL for app-release.apk using cloud name 'n8u6logx'
  static const String apkDownloadUrl =
      'https://res.cloudinary.com/n8u6logx/raw/upload/fl_attachment/app-release.apk';

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
