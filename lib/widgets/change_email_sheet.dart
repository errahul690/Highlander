import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../otp_api.dart';
import '../theme.dart';

class VerifiedEmailChange {
  const VerifiedEmailChange(this.email, this.proof);
  final String email, proof;
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
  Timer? _timer;
  String? _requestId, _error;
  int _seconds = 0;
  bool _busy = false, _deliverySkipped = false;
  String get email => _email.text.trim().toLowerCase();
  @override
  void dispose() {
    _timer?.cancel();
    _email.dispose();
    _code.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_busy || _seconds > 0) return;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        email == widget.currentEmail.toLowerCase()) {
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
      if (proof.isEmpty)
        throw const OtpApiException('Verify the new email address again.');
      if (mounted) Navigator.pop(context, VerifiedEmailChange(email, proof));
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      24,
      24,
      24,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Change email',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Verify your new email with OTP, then save your profile.',
            style: TextStyle(color: authMuted),
          ),
          const SizedBox(height: 20),
          TextField(
            key: const ValueKey('change-email-address'),
            controller: _email,
            readOnly: _busy,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'New email address',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            onChanged: (_) {
              _timer?.cancel();
              setState(() {
                _requestId = null;
                _seconds = 0;
                _error = null;
                _code.clear();
              });
            },
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: _busy || _seconds > 0 ? null : _send,
            child: Text(
              _requestId == null
                  ? 'Send OTP'
                  : _seconds > 0
                  ? 'Resend OTP in ${_seconds}s'
                  : 'Resend OTP',
            ),
          ),
          if (_requestId != null) ...[
            Text(
              _deliverySkipped
                  ? 'Development mode: use your master OTP. No email was sent.'
                  : 'Enter the 6-digit code sent to your new email.',
              style: const TextStyle(color: authMuted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('change-email-code'),
              controller: _code,
              readOnly: _busy,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(6),
              ],
              decoration: const InputDecoration(labelText: 'Email OTP'),
              onChanged: (_) => setState(() => _error = null),
            ),
            const SizedBox(height: 16),
            FilledButton(
              style: authButtonStyle(),
              onPressed: _busy || _code.text.length != 6 ? null : _verify,
              child: Text(_busy ? 'Verifying...' : 'Verify email'),
            ),
          ],
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(_error!, style: const TextStyle(color: authRed)),
            ),
          TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    ),
  );
}
