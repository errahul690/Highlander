import 'dart:typed_data';
import 'dart:ui' as ui;

/// Keeps ready-to-paint gallery images independently of Flutter's shared cache.
/// Callers own a clone so eviction cannot dispose an image still on screen.
class GalleryDecodedCache {
  GalleryDecodedCache({this.maximumBytes = 32 * 1024 * 1024});

  final int maximumBytes;
  final _images = <(Uint8List, int), ui.Image>{};
  final _pending = <(Uint8List, int), Future<ui.Image>>{};
  int _size = 0;

  ui.Image? lookup(Uint8List bytes, int width) {
    final key = (bytes, width);
    final image = _images.remove(key);
    if (image == null) return null;
    _images[key] = image;
    return image.clone();
  }

  Future<ui.Image> load(Uint8List bytes, int width) async {
    final ready = lookup(bytes, width);
    if (ready != null) return ready;
    final key = (bytes, width);
    final pending = _pending[key];
    if (pending != null) return (await pending).clone();
    final request = _decode(bytes, width);
    _pending[key] = request;
    try {
      return (await request).clone();
    } finally {
      _pending.remove(key);
    }
  }

  Future<ui.Image> _decode(Uint8List bytes, int width) async {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: width,
      allowUpscaling: false,
    );
    try {
      final image = (await codec.getNextFrame()).image;
      _images[(bytes, width)] = image;
      _size += image.width * image.height * 4;
      while (_size > maximumBytes && _images.length > 1) {
        final oldest = _images.remove(_images.keys.first)!;
        _size -= oldest.width * oldest.height * 4;
        oldest.dispose();
      }
      return image;
    } finally {
      codec.dispose();
    }
  }
}
