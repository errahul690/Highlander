import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../feed_startup.dart';
import '../legal_documents.dart';
import '../session.dart';
import '../otp_api.dart';
import '../theme.dart';
import 'otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  String? _error;
  bool _opening = false;
  late final _termsLink = TapGestureRecognizer()
    ..onTap = () => openLegalDocument(context, LegalDocument.terms);
  late final _privacyLink = TapGestureRecognizer()
    ..onTap = () => openLegalDocument(context, LegalDocument.privacy);
  @override
  void dispose() {
    _email.dispose();
    _termsLink.dispose();
    _privacyLink.dispose();
    super.dispose();
  }

  void _continue() {
    if (_opening) return;
    final email = _email.text.trim().toLowerCase();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }
    setState(() => _error = null);
    Session.phoneVerified = false;
    Session.emailVerified = false;
    Session.phone = '';
    Session.email = email;
    Session.emailOtpRequestId = '';
    Session.emailOtpDeliverySkipped = false;
    OtpApi.instance.mobileVerificationToken = '';
    OtpApi.instance.emailVerificationToken = '';
    FocusScope.of(context).unfocus();
    FeedStartup.start();
    _opening = true;
    Navigator.of(context)
        .push(
          MaterialPageRoute(builder: (_) => const OtpScreen(sendOnOpen: true)),
        )
        .whenComplete(() {
          if (mounted) _opening = false;
        });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    if (size.width <= 0 || size.height <= 0) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return AuthTheme(
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: SystemUiOverlayStyle.light.copyWith(
          statusBarColor: Colors.transparent,
        ),
        child: Scaffold(
          backgroundColor: Colors.white,
          body: LayoutBuilder(
            builder: (context, viewport) {
              final bottomPadding = MediaQuery.paddingOf(context).bottom + 30;
              final preferredHeroHeight = (size.height * .55).clamp(
                230.0,
                560.0,
              );
              // Reserve room for the form before sizing the decorative hero.
              final heroHeight = (viewport.maxHeight - bottomPadding - 360)
                  .clamp(140.0, preferredHeroHeight);
              return SingleChildScrollView(
                key: const ValueKey('login-scroll'),
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: heroHeight,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Image.asset(
                            'assets/images/login-hero.png',
                            fit: BoxFit.cover,
                            alignment: const Alignment(0, .15),
                          ),
                          const DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Color(0x33000000),
                                  Colors.transparent,
                                  Colors.white,
                                ],
                                stops: [0, .76, 1],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: EdgeInsets.fromLTRB(25, 4, 25, bottomPadding),
                      child: AutofillGroup(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Every journey\nstarts here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Color(0xFF191919),
                                fontSize: 34,
                                height: 1.22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -1.4,
                              ),
                            ),
                            const SizedBox(height: 25),
                            const Padding(
                              padding: EdgeInsets.only(left: 10, bottom: 7),
                              child: Text(
                                'Email address',
                                style: TextStyle(
                                  fontFamily: 'Gilroy',
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  height: 25 / 17,
                                  letterSpacing: -0.35,
                                ),
                              ),
                            ),
                            TextField(
                              key: const ValueKey('login-email'),
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              textInputAction: TextInputAction.done,
                              autofillHints: const [AutofillHints.email],
                              autocorrect: false,
                              textCapitalization: TextCapitalization.none,
                              decoration: InputDecoration(
                                hintText: 'Email address',
                                errorText: _error,
                                prefixIcon: const Icon(
                                  Icons.mail_outline_rounded,
                                  size: 21,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 17,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD8DBE3),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: const BorderSide(
                                    color: Color(0xFFD8DBE3),
                                  ),
                                ),
                              ),
                              onChanged: (_) {
                                if (_error != null)
                                  setState(() => _error = null);
                              },
                            ),
                            const SizedBox(height: 24),
                            FilledButton(
                              style: authButtonStyle(fontFamily: authFontFamily)
                                  .copyWith(
                                    elevation: const WidgetStatePropertyAll(7),
                                    shadowColor: const WidgetStatePropertyAll(
                                      Color(0x66000000),
                                    ),
                                  ),
                              onPressed: _continue,
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Get OTP',
                                    style: TextStyle(
                                      fontSize: 18, // Text size
                                      fontWeight: FontWeight.bold, // Bold
                                      color: Colors.white, // Text color
                                      letterSpacing: 1.2, // Letter spacing
                                      fontFamily: authFontFamily, // Font family
                                    ),
                                  ),
                                  SizedBox(width: 14),
                                  Icon(Icons.arrow_forward_rounded),
                                ],
                              ),
                            ),
                            const SizedBox(height: 30),
                            Text.rich(
                              TextSpan(
                                children: [
                                  TextSpan(
                                    text: 'By continuing, you agree to our ',
                                  ),
                                  TextSpan(
                                    text: 'Terms of Service',
                                    recognizer: _termsLink,
                                    mouseCursor: SystemMouseCursors.click,
                                    style: const TextStyle(
                                      color: clubInk,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                  TextSpan(text: '\nand '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    recognizer: _privacyLink,
                                    mouseCursor: SystemMouseCursors.click,
                                    style: const TextStyle(
                                      color: clubInk,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ],
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: authMuted,
                                fontSize: 11,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
