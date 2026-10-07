import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reads only artwork regions from copied references. All screen UI is Flutter.
class ReferenceArtwork extends StatelessWidget {
  const ReferenceArtwork({
    super.key,
    required this.asset,
    required this.region,
    this.fit = BoxFit.contain,
    this.alignment = Alignment.center,
    this.semanticLabel,
    this.dateLabel,
    this.transparentBackground = false,
  });
  final String asset;
  final Rect region;
  final BoxFit fit;
  final Alignment alignment;
  final String? semanticLabel;
  final String? dateLabel;
  final bool transparentBackground;
  static final Map<String, Future<ui.Image>> _images = {};
  static final Map<String, ui.Image> _decoded = {};

  static Future<void> preload() async {
    await Future.wait([
      _load('assets/images/welcome_reference.png'),
      _load('assets/images/brand_reference.png'),
      _load('assets/images/login_reference.png'),
      _load('assets/images/profile_reference.png'),
    ]);
  }

  static Future<ui.Image> _load(String asset) =>
      _images.putIfAbsent(asset, () async {
        final bytes = await rootBundle.load(asset);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes),
        );
        final frame = await codec.getNextFrame();
        codec.dispose();
        _decoded[asset] = frame.image;
        return frame.image;
      });

  @override
  Widget build(BuildContext context) => Semantics(
    label: semanticLabel,
    image: semanticLabel != null,
    excludeSemantics: true,
    child: FutureBuilder<ui.Image>(
      future: _load(asset),
      initialData: _decoded[asset],
      builder: (context, snapshot) => snapshot.hasData
          ? CustomPaint(
              painter: _RegionPainter(
                snapshot.data!,
                region,
                fit,
                alignment,
                dateLabel,
                transparentBackground,
              ),
              size: Size.infinite,
            )
          : const SizedBox.expand(),
    ),
  );
}

class _RegionPainter extends CustomPainter {
  const _RegionPainter(
    this.image,
    this.region,
    this.fit,
    this.alignment,
    this.dateLabel,
    this.transparentBackground,
  );
  final ui.Image image;
  final Rect region;
  final BoxFit fit;
  final Alignment alignment;
  final String? dateLabel;
  final bool transparentBackground;

  @override
  void paint(Canvas canvas, Size size) {
    final fitted = applyBoxFit(fit, region.size, size);
    final source = alignment.inscribe(fitted.source, region);
    final destination = alignment.inscribe(
      fitted.destination,
      Offset.zero & size,
    );
    canvas.drawImageRect(
      image,
      source,
      destination,
      Paint()
        ..filterQuality = FilterQuality.medium
        ..colorFilter = transparentBackground
            ? const ColorFilter.matrix([
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                0,
                0,
                0,
                1,
                0,
                0,
                -1,
                -1,
                -1,
                0,
                765,
              ])
            : null,
    );
    // Replace the illustration's old date without changing the reference file.
    if (dateLabel != null && fit == BoxFit.contain) {
      canvas.save();
      canvas.translate(destination.left, destination.top);
      canvas.scale(destination.width / region.width);
      canvas.translate(435 - region.left, 1092 - region.top);
      canvas.rotate(.11);
      canvas.drawRect(
        const Rect.fromLTWH(0, 0, 217, 36),
        Paint()..color = const Color(0xFFFDFEFF),
      );
      final text = TextPainter(
        text: TextSpan(
          text: dateLabel,
          style: const TextStyle(
            fontFamily: 'NunitoSans',
            fontSize: 17,
            color: Color(0xFF627FA7),
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, const Offset(3, 4));
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_RegionPainter oldDelegate) =>
      image != oldDelegate.image ||
      region != oldDelegate.region ||
      fit != oldDelegate.fit ||
      alignment != oldDelegate.alignment ||
      dateLabel != oldDelegate.dateLabel ||
      transparentBackground != oldDelegate.transparentBackground;
}

class BrandLogo extends StatelessWidget {
  const BrandLogo({super.key, this.width = 205, this.stacked = false});
  final double width;
  final bool stacked;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    height: stacked ? width * .78 : width * .285,
    child: ReferenceArtwork(
      asset: stacked
          ? 'assets/images/welcome_reference.png'
          : 'assets/images/brand_reference.png',
      region: stacked
          ? const Rect.fromLTWH(278, 111, 391, 302)
          : const Rect.fromLTWH(134, 110, 339, 94),
      semanticLabel: 'Chega Junto. Saúde mais perto de você.',
      transparentBackground: true,
    ),
  );
}
