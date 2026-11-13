import '../brand_colors.dart';
import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../widgets/club_header.dart';
import 'group_settings_screen.dart';

import '../session.dart';
import '../otp_api.dart';
import '../feed_store.dart';
import '../message_alerts.dart';
import '../legal_documents.dart';
import 'chat_settings_screen.dart';
import 'follow_settings_screen.dart';
import 'follow_requests_screen.dart';
import 'login_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ClubScaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: const ClubHeader(
        title: 'Settings',
        showBack: true,
        backKey: ValueKey('settings-back-btn'),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // Section 1: Privacy & Communication
          _buildSectionHeader('PRIVACY & CHAT'),
          const SizedBox(height: 8),
          _SettingsTile(
            icon: Icons.chat_bubble_outline_rounded,
            iconColor: brandAccent,
            title: 'Chat Settings',
            subtitle: 'Messages, permissions & media downloads',
            onTap: () => _open(context, const ChatSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.groups_outlined,
            iconColor: brandAccent,
            title: 'Group Settings',
            subtitle: 'Invitations and group privacy',
            onTap: () => _open(context, const GroupSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.manage_accounts_outlined,
            iconColor: brandAccent,
            title: 'Follow Settings',
            subtitle: 'Follow approval and privacy controls',
            onTap: () => _open(context, const FollowSettingsScreen()),
          ),
          _SettingsTile(
            icon: Icons.person_add_alt_1_outlined,
            iconColor: brandAccent,
            title: 'Follow Requests',
            subtitle: 'Pending requests from other fans',
            onTap: () => _open(context, const FollowRequestsScreen()),
          ),

          const SizedBox(height: 24),

          // Section 3: About
          _buildSectionHeader('ABOUT'),
          const SizedBox(height: 8),
          for (final document in LegalDocument.values)
            _SettingsTile(
              icon: document == LegalDocument.terms
                  ? Icons.description_outlined
                  : Icons.privacy_tip_outlined,
              iconColor: brandAccent,
              title: document.title,
              subtitle: 'Read on the Highlanders website',
              onTap: () => openLegalDocument(context, document),
            ),
          // Container(
          //   padding: const EdgeInsets.all(16),
          //   decoration: BoxDecoration(
          //     color: Colors.white,
          //     borderRadius: BorderRadius.circular(16),
          //     border: Border.all(color: const Color(0xFFEFEFEF)),
          //   ),
          //   child: Row(
          //     children: [
          //       Image.asset(
          //         'assets/images/club-logo.png',
          //         width: 36,
          //         height: 36,
          //         errorBuilder: (_, __, ___) => const Icon(
          //           Icons.shield_outlined,
          //           color: Color(0xFF881A1A),
          //           size: 32,
          //         ),
          //       ),
          //       const SizedBox(width: 14),
          //       const Expanded(
          //         child: Column(
          //           crossAxisAlignment: CrossAxisAlignment.start,
          //           children: [
          //             Text(
          //               'NorthEast United FC',
          //               style: TextStyle(
          //                 fontWeight: FontWeight.w800,
          //                 fontSize: 14,
          //                 color: Color(0xFF1E2229),
          //               ),
          //             ),
          //             SizedBox(height: 2),
          //             Text(
          //               'Official Highlanders Fan Experience • v1.0.0',
          //               style: TextStyle(
          //                 fontSize: 11,
          //                 color: Color(0xFF8A92A0),
          //               ),
          //             ),
          //           ],
          //         ),
          //       ),
          //     ],
          //   ),
          // ),

          const SizedBox(height: 32),

          // Log Out Button
          SizedBox(
            width: double.infinity,
            height: 50,
            child: OutlinedButton.icon(
              key: const ValueKey('logout-button'),
              style: OutlinedButton.styleFrom(
                foregroundColor: brandAccent,
                side: const BorderSide(color: brandAccent, width: 1.5),
                backgroundColor: brandAccentLight,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: const Icon(Icons.logout_rounded, size: 18),
              label: const Text(
                'Log out',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
              ),
              onPressed: () => _confirmLogout(context),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF8A92A0),
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  Future<void> _confirmLogout(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Log Out',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: const Text(
          'Are you sure you want to log out of your Highlanders account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: brandAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Log Out'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      await MessageAlerts.stop();
      await Session.logout();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
      return;
    }

    if (!context.mounted) return;
    FeedStore.clear();
    OtpApi.instance.mobileVerificationToken = '';
    OtpApi.instance.emailVerificationToken = '';
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFECEEF2)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x05000000),
            blurRadius: 6,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF1E2229),
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: Color(0xFF8A92A0)),
        ),
        trailing: const Icon(
          Icons.chevron_right_rounded,
          color: Color(0xFFB5BDCA),
          size: 22,
        ),
        onTap: onTap,
      ),
    );
  }
}
