import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'otp_api.dart';

enum LegalDocument {
  terms('Terms of Service', '/terms-of-service'),
  privacy('Privacy Policy', '/privacy-policy');

  const LegalDocument(this.title, this.path);

  final String title;
  final String path;
}

Future<void> openLegalDocument(
  BuildContext context,
  LegalDocument document,
) async {
  try {
    final base = Uri.parse(OtpApi.frontendUrl);
    if (!['http', 'https'].contains(base.scheme) || base.host.isEmpty) {
      throw const FormatException('Website URL is not configured');
    }
    final opened = await launchUrl(
      base.resolve(document.path),
      mode: LaunchMode.externalApplication,
    );
    if (opened) return;
  } catch (_) {
    // Keep the login form available if no browser can open the page.
  }
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Could not open ${document.title}. Please try again.'),
      ),
    );
  }
}
