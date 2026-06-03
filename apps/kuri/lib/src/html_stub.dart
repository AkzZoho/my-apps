// Stub for dart:html on non-web platforms.
// dart:html is conditionally imported; this file is used on mobile/desktop.

class _Navigator {
  String get userAgent => '';
  dynamic get standalone => null;
}

class _MediaQueryList {
  bool get matches => false;
}

class _Window {
  _Navigator get navigator => _Navigator();
  _MediaQueryList matchMedia(String _) => _MediaQueryList();
}

// ignore: library_private_types_in_public_api
final _Window window = _Window();

class Blob {
  Blob(List<dynamic> blobParts, [Map<String, String>? options]);
}

class Url {
  static String createObjectUrlFromBlob(dynamic blob) => '';
  static void revokeObjectUrl(String url) {}
}

class AnchorElement {
  String href = '';
  void setAttribute(String name, String value) {}
  void click() {}
}
