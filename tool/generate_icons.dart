// ignore_for_file: avoid_print, depend_on_referenced_packages
import 'dart:io';
import 'package:image/image.dart' as img;

void drawRoundedRect(
  img.Image image, {
  required int x1,
  required int y1,
  required int x2,
  required int y2,
  required int radius,
  required img.Color color,
}) {
  // Main horizontal & vertical center rects
  img.fillRect(image, x1: x1 + radius, y1: y1, x2: x2 - radius, y2: y2, color: color);
  img.fillRect(image, x1: x1, y1: y1 + radius, x2: x2, y2: y2 - radius, color: color);

  // 4 corner circles
  img.fillCircle(image, x: x1 + radius, y: y1 + radius, radius: radius, color: color);
  img.fillCircle(image, x: x2 - radius, y: y1 + radius, radius: radius, color: color);
  img.fillCircle(image, x: x1 + radius, y: y2 - radius, radius: radius, color: color);
  img.fillCircle(image, x: x2 - radius, y: y2 - radius, radius: radius, color: color);
}

void main() {
  final dir = Directory('assets/branding');
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  // 1. Generate 1024x1024 App Icon (Opaque for App Store requirements)
  final icon = img.Image(width: 1024, height: 1024, numChannels: 3);
  img.fill(icon, color: img.ColorRgb8(27, 94, 32));

  drawRoundedRect(
    icon,
    x1: 180,
    y1: 180,
    x2: 844,
    y2: 844,
    radius: 120,
    color: img.ColorRgb8(232, 245, 233),
  );

  drawRoundedRect(
    icon,
    x1: 360,
    y1: 260,
    x2: 664,
    y2: 380,
    radius: 50,
    color: img.ColorRgb8(46, 125, 50),
  );
  drawRoundedRect(
    icon,
    x1: 420,
    y1: 290,
    x2: 604,
    y2: 410,
    radius: 35,
    color: img.ColorRgb8(232, 245, 233),
  );

  img.fillCircle(
    icon,
    x: 512,
    y: 560,
    radius: 120,
    color: img.ColorRgb8(46, 125, 50),
  );
  img.fillCircle(
    icon,
    x: 540,
    y: 540,
    radius: 95,
    color: img.ColorRgb8(232, 245, 233),
  );

  img.fillCircle(
    icon,
    x: 360,
    y: 720,
    radius: 30,
    color: img.ColorRgb8(76, 175, 80),
  );
  img.fillCircle(
    icon,
    x: 512,
    y: 720,
    radius: 30,
    color: img.ColorRgb8(129, 199, 132),
  );
  img.fillCircle(
    icon,
    x: 664,
    y: 720,
    radius: 30,
    color: img.ColorRgb8(200, 230, 201),
  );

  File('assets/branding/app_icon.png').writeAsBytesSync(img.encodePng(icon));
  print('Generated assets/branding/app_icon.png (1024x1024)');

  // 2. Generate Splash Icon with TRUE TRANSPARENCY (numChannels: 4)
  // Background is 100% transparent (alpha: 0) with RGB matching the splash background (#1B5E20)
  // to avoid dark borders when filtered/rescaled.
  final splash = img.Image(width: 512, height: 512, numChannels: 4);
  img.fill(splash, color: img.ColorRgba8(27, 94, 32, 0));

  // The icon: rounded green card (#2E7D32)
  drawRoundedRect(
    splash,
    x1: 40,
    y1: 40,
    x2: 472,
    y2: 472,
    radius: 90,
    color: img.ColorRgba8(46, 125, 50, 255),
  );

  // White bag handle
  drawRoundedRect(
    splash,
    x1: 150,
    y1: 90,
    x2: 362,
    y2: 170,
    radius: 35,
    color: img.ColorRgba8(232, 245, 233, 255),
  );
  drawRoundedRect(
    splash,
    x1: 190,
    y1: 110,
    x2: 322,
    y2: 185,
    radius: 25,
    color: img.ColorRgba8(46, 125, 50, 255),
  );

  // White crescent/sprout emblem
  img.fillCircle(
    splash,
    x: 256,
    y: 280,
    radius: 70,
    color: img.ColorRgba8(232, 245, 233, 255),
  );
  img.fillCircle(
    splash,
    x: 275,
    y: 265,
    radius: 55,
    color: img.ColorRgba8(46, 125, 50, 255),
  );

  File('assets/branding/splash_icon.png').writeAsBytesSync(img.encodePng(splash));
  print('Generated assets/branding/splash_icon.png (512x512)');

  final verify = img.decodePng(File('assets/branding/splash_icon.png').readAsBytesSync())!;
  final pCorner = verify.getPixel(0, 0);
  final pCenter = verify.getPixel(256, 256);
  print('Corner (0,0): a=${pCorner.a}, r=${pCorner.r}, g=${pCorner.g}, b=${pCorner.b}');
  print('Center (256,256): a=${pCenter.a}, r=${pCenter.r}, g=${pCenter.g}, b=${pCenter.b}');
}
