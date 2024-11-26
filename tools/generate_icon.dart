import 'dart:io';
import 'package:flutter_svg/flutter_svg.dart';
import 'dart:ui' as ui;

Future<void> main() async {
  // Load SVG file
  final svg = File('assets/icon/kratom.svg').readAsStringSync();
  
  // Convert SVG to PNG
  final pictureInfo = await vg.loadPicture(SvgStringLoader(svg), null);
  
  final image = await pictureInfo.picture.toImage(1024, 1024);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();
  
  // Save PNG files
  await File('assets/icon/icon.png').writeAsBytes(pngBytes);
  await File('assets/icon/icon_foreground.png').writeAsBytes(pngBytes);
} 