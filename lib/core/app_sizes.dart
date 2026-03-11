import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class AppFontSizes {
  AppFontSizes._();

  // Big Titles
  static double get h1 => 32.sp;

  // Medium Titles
  static double get md => 12.sp;
  static double get lg => 14.sp;
}

class AppTextStyles {
  AppTextStyles._();

  static final Color textColor1 = const Color(0xFF333333);

  static const String _fontFamily = 'PlusJakartaSans';

  static TextStyle get h1 => TextStyle(
    fontFamily: _fontFamily,
    fontSize: AppFontSizes.h1,
    fontWeight: FontWeight.bold,
    height: 1.2,
    color: textColor1,
    shadows: [
      Shadow(
        color: Colors.black.withOpacity(0.3),
        offset: Offset(2, 2),
        blurRadius: 4,
      ),
    ],
  );
}

class _TextStylesProxy {
  const _TextStylesProxy();
  TextStyle get h1 => AppTextStyles.h1;
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
