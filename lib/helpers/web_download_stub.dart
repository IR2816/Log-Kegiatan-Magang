/// Stub implementation for non-web platforms.
/// The actual download is handled by dart:html on web.
void triggerWebDownload(String fileName, List<int> bytes) {
  // No-op on mobile/desktop - downloads are handled by file system
  throw UnsupportedError('Web download is only available on web platform');
}
