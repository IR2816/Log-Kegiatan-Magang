@JS()
library;

import 'dart:convert';
import 'dart:js_interop';

@JS('downloadFileFromBytes')
external void _downloadFile(JSString fileName, JSString base64Data);

/// Triggers a file download in the browser.
void triggerWebDownload(String fileName, List<int> bytes) {
  final base64 = base64Encode(bytes);
  _downloadFile(fileName.toJS, base64.toJS);
}
