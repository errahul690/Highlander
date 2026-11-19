import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:Highlanders/features/chat/data/chat_media_cache.dart';

double? chatMediaAspectRatio(Object? width, Object? height) {
  if (width is! num ||
      height is! num ||
      !width.isFinite ||
      !height.isFinite ||
      width <= 0 ||
      height <= 0 ||
      width > 32768 ||
      height > 32768) {
    return null;
  }
  return width / height;
}

Uint8List? chatMediaPreviewBytes(String value) {
  if (value.isEmpty || value.length > 12000) return null;
  try {
    final bytes = base64Decode(value);
    if (bytes.length < 24 ||
        bytes.length > 8192 ||
        bytes[0] != 137 ||
        bytes[1] != 80 ||
        bytes[2] != 78 ||
        bytes[3] != 71) {
      return null;
    }
    final header = ByteData.sublistView(bytes);
    final width = header.getUint32(16), height = header.getUint32(20);
    return width > 0 && width <= 64 && height > 0 && height <= 64
        ? bytes
        : null;
  } catch (_) {
    return null;
  }
}

/// Tiny, inline pixels and original geometry travel with the message itself.
/// Receiving a message never requires downloading the original to size it.
Future<Map<String, dynamic>> createChatMediaMetadata(Uint8List bytes) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  try {
    final descriptor = await ui.ImageDescriptor.encoded(buffer);
    try {
      final tiny = await createChatThumbnail(bytes, maxDimension: 32);
      return {
        'attachmentWidth': descriptor.width,
        'attachmentHeight': descriptor.height,
        if (tiny.length <= 8192) 'attachmentPreview': base64Encode(tiny),
      };
    } finally {
      descriptor.dispose();
    }
  } finally {
    buffer.dispose();
  }
}
