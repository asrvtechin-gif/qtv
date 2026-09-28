import 'dart:html' as html;

void triggerWebApkDownload(String targetUrl) {
  if (targetUrl.startsWith('http')) {
    html.window.open(targetUrl, '_blank');
  } else {
    try {
      final anchor = html.AnchorElement(href: targetUrl)
        ..setAttribute('download', 'app-release.apk')
        ..setAttribute('target', '_blank')
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      anchor.remove();
    } catch (e) {
      html.window.open(targetUrl, '_blank');
    }
  }
}
