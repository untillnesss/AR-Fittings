import 'dart:typed_data';

class ArCoreImage {
  ArCoreImage({
    required this.bytes,
    required this.width,
    required this.height,
  })  : assert(width > 0),
        assert(height > 0);

  final Uint8List bytes;
  final int width;
  final int height;

  Map<String, dynamic> toMap() => <String, dynamic>{
        'bytes': bytes,
        'width': width,
        'height': height
      }..removeWhere((String k, dynamic v) => v == null);
}
