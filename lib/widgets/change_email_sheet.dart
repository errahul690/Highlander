import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../otp_api.dart';
import '../theme.dart';

class VerifiedEmailChange {
  const VerifiedEmailChange(this.email, this.proof, this.currentEmailProof);
  final String email, proof, currentEmailProof;
}

class ChangeEmailSheet extends StatefulWidget {
  const ChangeEmailSheet({super.key, required this.currentEmail});
  final String currentEmail;
  @override
  State<ChangeEmailSheet> createState() => _ChangeEmailSheetState();
}

class _ChangeEmailSheetState extends State<ChangeEmailSheet> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _codeFocus = FocusNode();
  Timer? _timer;
  String? _requestId, _error;
  int _seconds = 0;
  bool _busy = false, _deliverySkipped = false;
  String _currentEmailProof = '';
  bool get _verifyingCurrent => _currentEmailProof.isEmpty;
  @override
  void initState() {
    super.initState();
    _email.text = widget.currentEmail.trim().toLowerCase();
  }

  String get email => _email.text.trim().toLowerCase();
  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _seconds > 0) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        (!_verifyingCurrent &&
            email == widget.currentEmail.trim().toLowerCase())) {
      setState(() => _error = 'Enter a different, valid email address.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final result = _requestId == null
          ? await OtpApi.instance.sendEmail(email)
          : await OtpApi.instance.resendEmail(email, _requestId!);
      if (!mounted) return;
      setState(() {
        _requestId = result.requestId;
        _seconds = result.resendAfterSeconds;
        _deliverySkipped = result.deliverySkipped;
        _code.clear();
      });
      _codeFocus.requestFocus();
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          if (_seconds > 0) _seconds--;
        });
        if (_seconds == 0) timer.cancel();
      });
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _verify() async {
    if (_busy || _requestId == null || _code.text.length != 6) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await OtpApi.instance.verifyEmail(email, _code.text, _requestId!);
      final proof = OtpApi.instance.emailVerificationToken;
      if (proof.isEmpty) {
        throw const OtpApiException('Verify the email address again.');
      }
      if (!mounted) return;
      if (_verifyingCurrent) {
        _timer?.cancel();
        setState(() {
          _currentEmailProof = proof;
          _email.clear();
          _code.clear();
          _requestId = null;
          _seconds = 0;
          _deliverySkipped = false;
        });
        FocusScope.of(context).unfocus();
      } else {
        Navigator.pop(
          context,
          VerifiedEmailChange(email, proof, _currentEmailProof),
        );
      }
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F3),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.mark_email_read_outlined,
                        color: authRed,
                        size: 26,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, color: authMuted),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _step(
                        '1',
                        'Existing email',
                        true,
                        complete: !_verifyingCurrent,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _step('2', 'New email', !_verifyingCurrent),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                const Text(
                  'Change email',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: clubInk,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _verifyingCurrent
                      ? 'First, verify your existing email to keep your account secure.'
                      : 'Enter your new email address. We’ll send an OTP to verify it.',
                  style: const TextStyle(
                    color: authMuted,
                    fontSize: 14,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                if (!_verifyingCurrent) ...[
                  const Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 16,
                        color: Color(0xFF22834A),
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'Existing email verified',
                          style: TextStyle(
                            color: Color(0xFF22834A),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                TextField(
                  key: const ValueKey('change-email-address'),
                  controller: _email,
                  readOnly: _busy || _verifyingCurrent,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: _verifyingCurrent
                        ? 'Existing email address'
                        : 'New email address',
                    prefixIcon: const Icon(Icons.email_outlined),
                    prefixIconColor: authMuted,
                    filled: true,
                    fillColor: _verifyingCurrent
                        ? const Color(0xFFF4F5F7)
                        : Colors.white,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: authRed, width: 1.5),
                    ),
                  ),
                  onChanged: (_) {
                    _timer?.cancel();
                    setState(() {
                      _requestId = null;
                      _seconds = 0;
                      _error = null;
                      _deliverySkipped = false;
                      _code.clear();
                    });
                  },
                ),
                if (_requestId != null) ...[
                  const SizedBox(height: 18),
                  Text(
                    _deliverySkipped
                        ? 'Development mode: use your master OTP. No email was sent.'
                        : 'Enter the 6-digit code sent to ${_verifyingCurrent ? 'your existing' : 'your new'} email.',
                    style: const TextStyle(color: authMuted, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const ValueKey('change-email-code'),
                    controller: _code,
                    focusNode: _codeFocus,
                    readOnly: _busy,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    textInputAction: TextInputAction.done,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 8,
                    ),
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(6),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Email OTP',
                      floatingLabelBehavior: FloatingLabelBehavior.always,
                      hintText: '000000',
                      hintStyle: const TextStyle(
                        color: Color(0xFFBCC1CB),
                        fontSize: 24,
                        letterSpacing: 8,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: authRed,
                          width: 1.5,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() => _error = null),
                    onSubmitted: (_) => _verify(),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: authRed),
                    onPressed: _busy || _seconds > 0 ? null : _send,
                    child: Text(
                      _seconds > 0
                          ? 'Resend OTP in ${_seconds}s'
                          : 'Resend OTP',
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      semanticsLabel: _error,
                      style: const TextStyle(color: authRed, fontSize: 13),
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  style: authButtonStyle(),
                  onPressed: _busy
                      ? null
                      : _requestId == null
                      ? _send
                      : _code.text.length == 6
                      ? _verify
                      : null,
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: authRed,
                          ),
                        )
                      : Text(
                          _requestId == null
                              ? 'Send OTP'
                              : _verifyingCurrent
                              ? 'Verify existing email'
                              : 'Verify new email',
                        ),
                ),
                if (!_verifyingCurrent) ...[
                  const SizedBox(height: 10),
                  const Text(
                    'Save your profile after verification to apply the change.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: authMuted,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: authMuted),
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _step(
    String number,
    String label,
    bool active, {
    bool complete = false,
  }) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        height: 3,
        decoration: BoxDecoration(
          color: active ? authRed : const Color(0xFFE7E9ED),
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${complete ? '✓' : number}  $label',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: active ? authRed : authMuted,
        ),
      ),
    ],
  );
}
