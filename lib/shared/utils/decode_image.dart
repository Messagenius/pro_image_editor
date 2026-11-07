// Dart imports:
import 'dart:ui' as ui;

// Flutter imports:
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

// Project imports:
import '/features/crop_rotate_editor/models/transform_configs.dart';

/// Reads the size of an encoded image from its header, so no pixels are
/// decoded. The web has no header read, so it decodes and frees the image.
Future<Size> readImageSize(Uint8List bytes) async {
  if (kIsWeb) {
    final decodedImage = await decodeImageFromList(bytes);
    final size = Size(
      decodedImage.width.toDouble(),
      decodedImage.height.toDouble(),
    );
    decodedImage.dispose();
    return size;
  }

  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  final descriptor = await ui.ImageDescriptor.encoded(buffer);
  final size = Size(descriptor.width.toDouble(), descriptor.height.toDouble());
  descriptor.dispose();
  buffer.dispose();
  return size;
}

/// Decode the image being edited.
Future<ImageInfos> decodeImageInfos({
  required Uint8List bytes,
  required Size screenSize,
  TransformConfigs? configs,
}) async {
  Size rawSize = await readImageSize(bytes);

  bool rotated = configs?.is90DegRotated == true;
  int width = rawSize.width.toInt();
  int height = rawSize.height.toInt();

  double calculatePixelRatio(num width, num height) {
    bool fitToHeight = screenSize.aspectRatio > (width / height);
    double widthRatio = width / screenSize.width;
    double heightRatio = height / screenSize.height;
    return fitToHeight ? heightRatio : widthRatio;
  }

  // Calculate the pixel ratio before scaling and rotation
  double originalPixelRatio = calculatePixelRatio(width, height);

  /// If the image is rotated we also flip the width/ height
  if (rotated) {
    int hX = height;
    height = width;
    width = hX;
  }

  if (configs != null && configs.isNotEmpty) {
    width ~/= configs.scaleUser;
    height ~/= configs.scaleUser;
  }

  // Calculate final pixel ratio after scaling
  double pixelRatio = calculatePixelRatio(width, height);

  Size renderedSize = rawSize / pixelRatio;
  Size originalRenderedSize = rawSize / originalPixelRatio;

  return ImageInfos(
    rawSize: rawSize,
    renderedSize: renderedSize,
    originalRenderedSize: originalRenderedSize,
    cropRectSize: configs != null && configs.isNotEmpty
        ? configs.cropRect.size
        : renderedSize,
    pixelRatio: pixelRatio,
    isRotated: configs?.is90DegRotated ?? false,
  );
}

/// Contains information about an image's size and rotation status.
class ImageInfos {
  /// Creates an instance of [ImageInfos].
  const ImageInfos({
    required this.rawSize,
    required this.renderedSize,
    required this.originalRenderedSize,
    required this.cropRectSize,
    required this.pixelRatio,
    required this.isRotated,
  });

  /// The raw size of the image.
  final Size rawSize;

  /// The size of the image after rendering.
  final Size renderedSize;

  /// The size of the image after rendering without any transformations.
  final Size originalRenderedSize;

  /// The size of the cropping rectangle.
  final Size cropRectSize;

  /// The pixel ratio of the image.
  final double pixelRatio;

  /// Whether the image is rotated.
  final bool isRotated;

  /// Creates a copy of the current [ImageInfos] instance with optional
  /// updated values.
  ImageInfos copyWith({
    Size? rawSize,
    Size? renderedSize,
    Size? originalRenderedSize,
    Size? cropRectSize,
    double? pixelRatio,
    bool? isRotated,
  }) {
    return ImageInfos(
      rawSize: rawSize ?? this.rawSize,
      renderedSize: renderedSize ?? this.renderedSize,
      originalRenderedSize: originalRenderedSize ?? this.originalRenderedSize,
      cropRectSize: cropRectSize ?? this.cropRectSize,
      pixelRatio: pixelRatio ?? this.pixelRatio,
      isRotated: isRotated ?? this.isRotated,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ImageInfos &&
        other.rawSize == rawSize &&
        other.renderedSize == renderedSize &&
        other.cropRectSize == cropRectSize &&
        other.pixelRatio == pixelRatio &&
        other.isRotated == isRotated;
  }

  @override
  int get hashCode {
    return rawSize.hashCode ^
        renderedSize.hashCode ^
        cropRectSize.hashCode ^
        pixelRatio.hashCode ^
        isRotated.hashCode;
  }
}
