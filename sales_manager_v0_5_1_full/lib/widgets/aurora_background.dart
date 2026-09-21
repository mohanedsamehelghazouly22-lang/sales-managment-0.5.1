import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// خلفية "Liquid Glass": تدرّج هادئ + كتل ضوء ملوّنة معتّمة بالبلور،
/// كل الشاشات والكروت الشفافة في التطبيق بتطفو فوق الخلفية دي.
/// بتتحط مرة واحدة في main.dart (MaterialApp.builder) عشان تفضل خلف
/// أي Scaffold في التطبيق من غير ما نلمس كل شاشة لوحدها.
class AuroraBackground extends StatelessWidget {
  final Widget child;
  const AuroraBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        const DecoratedBox(decoration: BoxDecoration(gradient: AppTheme.backgroundGradient)),
        Positioned(top: -120, left: -80, child: _blob(280, AppTheme.blobA)),
        Positioned(top: 160, right: -100, child: _blob(240, AppTheme.blobB)),
        Positioned(bottom: -140, left: 40, child: _blob(260, AppTheme.blobC)),
        child,
      ],
    );
  }

  Widget _blob(double size, Color color) => ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: 90, sigmaY: 90),
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(shape: BoxShape.circle, color: color.withOpacity(.55)),
        ),
      );
}
