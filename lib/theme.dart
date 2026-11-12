import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'brand_colors.dart';

const clubRed = brandAccent;
const clubBlood = brandAccentDark;
const clubInk = Color(0xFF101014);
const clubCloud = Color(0xFFF6F5F2);
const clubLine = Color(0xFFE7E4DE);
const authRed = brandAccent;
const authMuted = Color(0xFF596275);
const clubFontFamily = 'Gilroy';
const authFontFamily = 'Gilroy';

ButtonStyle authButtonStyle({
  String fontFamily = clubFontFamily,
  Color disabledBackgroundColor = const Color(0xFFF9D7D9),
  Color disabledForegroundColor = authRed,
}) => FilledButton.styleFrom(
  backgroundColor: authRed,
  foregroundColor: Colors.white,
  disabledBackgroundColor: disabledBackgroundColor,
  disabledForegroundColor: disabledForegroundColor,
  minimumSize: const Size.fromHeight(48),
  textStyle: TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
  ),
  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
);

class AuthTheme extends StatelessWidget {
  const AuthTheme({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Theme(
    data: clubTheme(fontFamily: authFontFamily),
    child: child,
  );
}

ThemeData clubTheme({String fontFamily = clubFontFamily}) {
  final base = ThemeData(
    useMaterial3: true,
    fontFamily: fontFamily,
    colorScheme: ColorScheme.fromSeed(
      seedColor: brandAccent,
      primary: brandAccent,
      onPrimary: Colors.white,
      secondary: brandAccent,
      primaryContainer: brandAccentLight,
    ),
    scaffoldBackgroundColor: clubCloud,
  );
  return base.copyWith(
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    textTheme: base.textTheme
        .copyWith(
          titleLarge: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: clubInk,
            height: 1.3,
          ),
          titleMedium: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: clubInk,
            height: 1.4,
          ),
          titleSmall: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: clubInk,
            height: 1.4,
          ),
          bodyLarge: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: clubInk,
            height: 1.35,
          ),
          bodyMedium: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w400,
            color: clubInk,
            height: 1.35,
          ),
          bodySmall: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w400,
            color: authMuted,
            height: 1.3,
          ),
          labelLarge: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          labelMedium: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.4,
          ),
          labelSmall: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w400,
            height: 1.4,
          ),
        )
        .apply(fontFamily: fontFamily),
    iconTheme: const IconThemeData(size: 20, color: clubInk),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(iconSize: 20),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        iconSize: 18,
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: brandAccent,
        foregroundColor: Colors.white,
        disabledBackgroundColor: brandAccentLight,
        disabledForegroundColor: authMuted,
      ),
    ),
    tabBarTheme: const TabBarThemeData(
      labelColor: brandAccent,
      unselectedLabelColor: authMuted,
      indicatorColor: brandAccent,
    ),
    chipTheme: base.chipTheme.copyWith(
      selectedColor: brandAccent,
      checkmarkColor: Colors.white,
      labelStyle: WidgetStateTextStyle.resolveWith((states) => TextStyle(
        fontFamily: fontFamily,
        color: states.contains(WidgetState.selected) ? Colors.white : clubInk,
      )),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: brandAccent,
        side: const BorderSide(color: brandAccent),
        iconSize: 18,
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: brandAccent,
        iconSize: 18,
        textStyle: TextStyle(
          fontFamily: fontFamily,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      minVerticalPadding: 6,
      iconColor: clubInk,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: clubRed,
      foregroundColor: Colors.white,
      elevation: 0,
      centerTitle: true,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      labelStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: authMuted,
      ),
      hintStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: authMuted,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: clubLine),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: clubLine),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: clubRed, width: 1.5),
      ),
    ),
  );
}
