import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppFontSizes {
  AppFontSizes._();

  static double get xs => 10.sp;
  static double get sm => 11.sp;
  static double get md => 12.sp;
  static double get lg => 14.sp;
  static double get xl => 16.sp;
  static double get xxl => 18.sp;
  static double get h2 => 24.sp;
  static double get h1 => 32.sp;
}

class AppTextStyles {
  AppTextStyles._();

  static const Color textDark = Color(0xFF333333);
  static const Color textWhite = Colors.white;
  static const Color textWhite70 = Colors.white70;
  static const Color textWhite54 = Colors.white54;

  static const String _fontFamily = 'PlusJakartaSans';

  static TextStyle _base({
    required double fontSize,
    FontWeight fontWeight = FontWeight.w400,
    Color color = textDark,
    double height = 1.2,
    List<Shadow>? shadows,
  }) {
    return TextStyle(
      fontFamily: _fontFamily,
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      shadows: shadows,
    );
  }

  static TextStyle get h1 => _base(
    fontSize: AppFontSizes.h1,
    fontWeight: FontWeight.w700,
    color: textDark,
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.3),
        offset: Offset(2, 2),
        blurRadius: 4,
      ),
    ],
  );

  static TextStyle get h2 =>
      _base(fontSize: AppFontSizes.h2, fontWeight: FontWeight.w700);

  static TextStyle get title =>
      _base(fontSize: AppFontSizes.xxl, fontWeight: FontWeight.w700);

  static TextStyle get subtitle =>
      _base(fontSize: AppFontSizes.xl, fontWeight: FontWeight.w600);

  static TextStyle get body => _base(fontSize: AppFontSizes.lg);

  static TextStyle get bodySmall => _base(fontSize: AppFontSizes.md);

  static TextStyle get caption => _base(fontSize: AppFontSizes.sm);

  static TextStyle get micro => _base(fontSize: AppFontSizes.xs);

  static TextStyle get button =>
      _base(fontSize: AppFontSizes.xl, fontWeight: FontWeight.w700);

  static TextStyle get input => _base(fontSize: AppFontSizes.lg);

  static TextStyle get inputLabel => _base(
    fontSize: AppFontSizes.lg,
    color: textWhite70,
    fontWeight: FontWeight.w500,
  );

  static TextStyle get inputHint =>
      _base(fontSize: AppFontSizes.lg, color: textWhite54);
}

class _TextStylesProxy {
  const _TextStylesProxy();

  TextStyle get h1 => AppTextStyles.h1;
  TextStyle get h2 => AppTextStyles.h2;
  TextStyle get title => AppTextStyles.title;
  TextStyle get subtitle => AppTextStyles.subtitle;
  TextStyle get body => AppTextStyles.body;
  TextStyle get bodySmall => AppTextStyles.bodySmall;
  TextStyle get caption => AppTextStyles.caption;
  TextStyle get micro => AppTextStyles.micro;
  TextStyle get button => AppTextStyles.button;
  TextStyle get input => AppTextStyles.input;
  TextStyle get inputLabel => AppTextStyles.inputLabel;
  TextStyle get inputHint => AppTextStyles.inputHint;
}

extension AppSizes on BuildContext {
  // _SpaceProxy get space => const _SpaceProxy();
  // _GapVProxy get gapV => const _GapVProxy();
  // _GapHProxy get gapH => const _GapHProxy();
  // _PaddingProxy get pad => const _PaddingProxy();

  // _RadiusProxy get radius => const _RadiusProxy();
  // _HeightsProxy get heights => const _HeightsProxy();
  // _IconSizeProxy get icons => const _IconSizeProxy();
  // _AvatarSizeProxy get avatar => const _AvatarSizeProxy();
  _TextStylesProxy get textStyles => const _TextStylesProxy();
}
