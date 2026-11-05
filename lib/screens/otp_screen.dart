import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../feed_startup.dart';
import '../session.dart';
import '../otp_api.dart';
import '../theme.dart';
import 'complete_profile_screen.dart';
import 'shell.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, this.sendOnOpen = false});
  final bool sendOnOpen;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _timer;
  static const _resendCooldownSeconds = 60;
  int _seconds = _resendCooldownSeconds;
  bool _loading = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openKeyboard());
    if (widget.sendOnOpen) {
      _sending = true;
      _startTimer();
      unawaited(_deliver());
    } else {
      _seconds = Session.otpResendSeconds < _resendCooldownSeconds
          ? _resendCooldownSeconds
          : Session.otpResendSeconds;
      if (_seconds > 0) _startTimer();
    }
  }

  Future<void> _deliver() async {
    try {
      FeedStartup.start();
      final result = await OtpApi.instance.sendEmail(Session.email);
      if (!mounted) return;
      Session.emailOtpRequestId = result.requestId;
      Session.emailOtpDeliverySkipped = result.deliverySkipped;
      Session.otpResendSeconds =
          result.resendAfterSeconds < _resendCooldownSeconds
          ? _resendCooldownSeconds
          : result.resendAfterSeconds;
      setState(() {
        _sending = false;
        _error = null;
        if (_seconds == 0) _seconds = Session.otpResendSeconds;
      });
      if (_seconds > 0 && _timer?.isActive != true) _startTimer();
    } catch (error) {
      _keepTimerInsteadOfWaitError(error);
    }
  }

  void _keepTimerInsteadOfWaitError(Object error) {
    if (!mounted) return;
    final message = error.toString();
    final alreadyWaiting =
        _seconds > 0 &&
        message.toLowerCase().contains('please wait before requesting');
    if (alreadyWaiting) {
      setState(() {
        _sending = false;
        _error = null;
      });
      return;
    }
    _timer?.cancel();
    setState(() {
      _sending = false;
      _seconds = 0;
      _error = message;
    });
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_seconds > 0) setState(() => _seconds--);
      if (_seconds == 0) timer.cancel();
    });
  }

  void _openKeyboard() {
    if (!mounted || _loading) return;
    final route = ModalRoute.of(context);
    final animation = route?.animation;
    if (animation != null && !animation.isCompleted) {
      void listener(AnimationStatus status) {
        if (status != AnimationStatus.completed) return;
        animation.removeStatusListener(listener);
        if (mounted) _openKeyboard();
      }

      animation.addStatusListener(listener);
      return;
    }
    _codeFocus.requestFocus();
    SystemChannels.textInput.invokeMethod<void>('TextInput.show');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeFocus.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    if (_code.text.length != 6 || _loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      FeedStartup.start();
      // Reuse the verified proof when retrying a failed account lookup.
      if (!Session.emailVerified ||
          OtpApi.instance.emailVerificationToken.isEmpty) {
        await OtpApi.instance.verifyEmail(
          Session.email,
          _code.text,
          Session.emailOtpRequestId,
        );
        Session.emailVerified = true;
      }
      final profile = await OtpApi.instance.findEmailProfile(Session.email);
      if (!mounted) return;
      Session.emailVerified = true;
      FocusScope.of(context).unfocus();
      if (profile != null) {
        await Session.saveProfile(profile);
        FeedStartup.start();
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AppShell()),
          (_) => false,
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const CompleteProfileScreen()),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _resend() async {
    if (_loading || _sending || _seconds > 0) return;
    setState(() {
      _sending = true;
      _seconds = _resendCooldownSeconds;
      _error = null;
    });
    _startTimer();
    if (Session.emailOtpRequestId.isEmpty) {
      await _deliver();
      return;
    }
    try {
      final result = await OtpApi.instance.resendEmail(
        Session.email,
        Session.emailOtpRequestId,
      );
      Session.emailVerified = false;
      Session.emailOtpRequestId = result.requestId;
      Session.emailOtpDeliverySkipped = result.deliverySkipped;
      Session.otpResendSeconds =
          result.resendAfterSeconds < _resendCooldownSeconds
          ? _resendCooldownSeconds
          : result.resendAfterSeconds;
      if (!mounted) return;
      setState(() {
        _seconds = Session.otpResendSeconds;
        _code.clear();
      });
      _startTimer();
    } catch (error) {
      _keepTimerInsteadOfWaitError(error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  String get _otpHint {
    if (_sending || Session.emailOtpRequestId.isEmpty) return '';
    if (Session.emailOtpDeliverySkipped) {
      return 'Test mode: enter the master OTP. No email was sent.';
    }
    return 'Enter the 6-digit code sent to your email';
  }

  void _help() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Check your email address, inbox and spam folder, then try resending the code.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final masked = Session.email;
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: clubInk,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
      ),
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text.rich(
                TextSpan(
                  children: [
                    TextSpan(text: 'Verify your email '),
                    TextSpan(
                      text: 'code',
                      style: TextStyle(color: authRed),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 12),
              if (_otpHint.isNotEmpty)
                Text(
                  _otpHint,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: authMuted, fontSize: 15),
                ),
              const SizedBox(height: 8),
              Wrap(
                alignment: WrapAlignment.center,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                children: [
                  Text(
                    masked,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text(
                      'Change',
                      style: TextStyle(color: authRed),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 34),
              Center(
                child: Container(
                  width: 168,
                  height: 168,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        Color(0xFFE78B8D),
                        Color(0xFFF9E8E9),
                        Colors.white,
                      ],
                    ),
                  ),
                  child: Center(
                    child: Container(
                      width: 68,
                      height: 68,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [Color(0xFFED5B59), Color(0xFF9E1526)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Color(0x44B52529),
                            blurRadius: 12,
                            offset: Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.sms_rounded,
                        color: Colors.white,
                        size: 36,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 38),
              const Text(
                'Verification code',
                style: TextStyle(color: authMuted, fontSize: 15),
              ),
              const SizedBox(height: 10),
              // A single input supports pasting and autofilling the whole code.
              LayoutBuilder(
                builder: (context, constraints) {
                  final cellWidth = (constraints.maxWidth - 40) / 6;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _openKeyboard,
                    child: Stack(
                      children: [
                      ExcludeSemantics(
                        child: Row(
                          children: [
                            for (var i = 0; i < 6; i++) ...[
                              if (i > 0) const SizedBox(width: 8),
                              Container(
                                width: cellWidth,
                                height: 60,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color:
                                        (_code.text.length == i ||
                                            (_code.text.length == 6 && i == 5))
                                        ? authRed
                                        : const Color(0xFFD8DBE2),
                                    width: _code.text.length == i ? 1.5 : 1,
                                  ),
                                ),
                                child: Text(
                                  i < _code.text.length ? _code.text[i] : '',
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned.fill(
                        child: TextField(
                          focusNode: _codeFocus,
                          controller: _code,
                          autofocus: true,
                          keyboardType: TextInputType.number,
                          textInputAction: TextInputAction.done,
                          readOnly: _loading,
                          onTap: _openKeyboard,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          style: const TextStyle(color: Colors.transparent),
                          showCursor: false,
                          enableInteractiveSelection: false,
                          decoration: const InputDecoration(
                            labelText: 'Six-digit verification code',
                            floatingLabelBehavior: FloatingLabelBehavior.never,
                            labelStyle: TextStyle(color: Colors.transparent),
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                          onChanged: (_) => setState(() => _error = null),
                          onSubmitted: (_) => _verify(),
                        ),
                      ),
                    ],
                    ),
                  );
                },
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(_error!, style: const TextStyle(color: authRed)),
                ),
              const SizedBox(height: 14),
              SizedBox(
                height: 36,
                child: Center(
                  child: _seconds > 0
                      ? Text(
                          'Resend code in ${(_seconds ~/ 60).toString().padLeft(2, '0')}:${(_seconds % 60).toString().padLeft(2, '0')}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: authMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        )
                      : OutlinedButton.icon(
                          key: const ValueKey('otp-resend'),
                          onPressed: _loading || _sending ? null : _resend,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: authRed,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          icon: const Icon(Icons.refresh_rounded, size: 18),
                          label: const Text('Resend OTP'),
                        ),
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                style: authButtonStyle(),
                onPressed:
                    _code.text.length == 6 &&
                        !_loading &&
                        !_sending &&
                        Session.emailOtpRequestId.isNotEmpty
                    ? _verify
                    : null,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(_loading ? 'Please wait…' : 'Verify & continue'),
                    const SizedBox(width: 14),
                    if (_loading)
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.arrow_forward),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.verified_user_outlined, color: authMuted),
                  SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'Never share your OTP',
                      style: TextStyle(color: authMuted),
                    ),
                  ),
                ],
              ),
              // const SizedBox(height: 20),
              // Wrap(
              //   alignment: WrapAlignment.center,
              //   crossAxisAlignment: WrapCrossAlignment.center,
              //   children: [
              //     const Text(
              //       'Having trouble?',
              //       style: TextStyle(color: authMuted),
              //     ),
              //     TextButton(
              //       onPressed: _help,
              //       child: const Text(
              //         'Get help',
              //         style: TextStyle(color: authRed),
              //       ),
              //     ),
              //   ],
              // ),
            ],
          ),
        ),
      ),
    );
  }
}
