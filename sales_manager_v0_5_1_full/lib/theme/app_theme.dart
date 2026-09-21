import 'dart:ui';
import 'package:flutter/material.dart';

/// ثيم "Liquid Glass" — سطوح شفافة معتّمة (Frosted Glass) فوق خلفية
/// متدرّجة هادئة، بنفس روح تصميم iOS الزجاجي.
class AppTheme {
  // ── الخلفية المتدرجة (تظهر خلف كل سطح زجاجي في التطبيق) ──
  static const bgTop = Color(0xFFEAF0FF); // أزرق ثلجي فاتح
  static const bgMid = Color(0xFFF1E9FF); // بنفسجي فاتح
  static const bgBottom = Color(0xFFFFEBF2); // وردي فاتح

  static const bg = bgMid; // لون احتياطي في الأماكن اللي مش بتقبل Gradient

  static const backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [bgTop, bgMid, bgBottom],
  );

  // كتل الضوء الملوّنة المعتّمة اللي بتدي إحساس "السائل" خلف الزجاج
  static const blobA = Color(0xFF7C8CFF); // إنديجو
  static const blobB = Color(0xFFFF8FB1); // وردي مرجاني
  static const blobC = Color(0xFF7CE0C6); // نعناعي

  // ── السطوح الزجاجية ──
  static const panel = Color(0xF2FFFFFF); // أبيض شبه معتم (بديل بدون بلور)
  static const panel2 = Color(0xFFF3F1FA); // خلفية الحقول
  static const glassTint = Color(0xB3FFFFFF); // الملء الزجاجي الفعلي (~70% أبيض)
  static const glassBorder = Color(0x99FFFFFF); // حد الإضاءة اللامع حول الزجاج
  static const glassShadow = Color(0x1F5B4FCF);

  // ── ألوان الهوية ──
  static const primary = Color(0xFF5E5CE6); // إنديجو زاهي (System Indigo بتاع آبل)
  static const accent = Color(0xFFFF6482); // وردي مرجاني زاهي
  static const mint = Color(0xFF30D6B8); // نجاح / إيجابي
  static const text = Color(0xFF1C1B2E); // كحلي غامق قريب من الأسود
  static const muted = Color(0xFF6E6A85); // رمادي بنفسجي هادئ

  static const shadowColor = glassShadow;

  /// ديكوريشن الكارت الزجاجي المستخدم في كل التطبيق (StatBox, الكروت, ...).
  /// مش بلور حقيقي (BoxDecoration مينفعش يعمل بلور لحاجة وراه) لكنه بيقلّد
  /// نفس الإحساس: ملء شفاف بتدرّج لمعة، حد لامع، وظل ملوّن ناعم.
  static BoxDecoration card({double radius = 22, Color? tint}) => BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            (tint ?? Colors.white).withOpacity(.78),
            (tint ?? Colors.white).withOpacity(.52),
          ],
        ),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: glassBorder, width: 1.2),
        boxShadow: [
          BoxShadow(color: shadowColor, blurRadius: 28, offset: const Offset(0, 12)),
        ],
      );

  /// زجاج حقيقي (Backdrop Blur فعلي) — يُستخدم للعناصر اللي فوق محتوى
  /// متحرك/سكرول (الشريط السفلي، القائمة الجانبية، كارت تسجيل الدخول).
  static Widget glass({
    required Widget child,
    double radius = 28,
    double blur = 20,
    Color tint = Colors.white,
    double opacity = .55,
    EdgeInsetsGeometry? padding,
    Border? border,
    BoxConstraints? constraints,
  }) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          constraints: constraints,
          decoration: BoxDecoration(
            color: tint.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: border ?? Border.all(color: glassBorder, width: 1.2),
          ),
          child: child,
        ),
      ),
    );
  }

  static ThemeData dark() => ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.transparent,
    fontFamily: 'Arial',
    colorScheme: const ColorScheme.light(
      primary: primary,
      secondary: accent,
      surface: panel,
      onSurface: text,
    ),
    textTheme: const TextTheme(
      bodyLarge: TextStyle(color: text),
      bodyMedium: TextStyle(color: text),
      titleLarge: TextStyle(color: text, fontWeight: FontWeight.w800),
      titleMedium: TextStyle(color: text, fontWeight: FontWeight.w700),
    ),
    iconTheme: const IconThemeData(color: text),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      foregroundColor: text,
    ),
    cardTheme: CardThemeData(
      color: glassTint,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: glassBorder, width: 1.2),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: const Color(0xF7FFFFFF),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: Color(0xF2FFFFFF),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: Colors.white.withOpacity(.55),
      selectedColor: primary.withOpacity(.16),
      labelStyle: const TextStyle(color: text, fontWeight: FontWeight.w700),
      shape: const StadiumBorder(side: BorderSide(color: glassBorder)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: primary),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primary,
      foregroundColor: Colors.white,
      elevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white.withOpacity(.55),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glassBorder),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: glassBorder),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primary, width: 1.6),
      ),
      hintStyle: const TextStyle(color: muted),
    ),
  );
}
