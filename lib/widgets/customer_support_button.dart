import 'package:flutter/material.dart';

import '../community_api.dart';
import '../screens/chat_screen.dart';
import 'header_action_icon.dart';

class CustomerSupportButton extends StatefulWidget {
  const CustomerSupportButton({super.key});
  @override
  State<CustomerSupportButton> createState() => _CustomerSupportButtonState();
}

class _CustomerSupportButtonState extends State<CustomerSupportButton> {
  bool _loading = false;
  Future<void> _open() async {
    setState(() => _loading = true);
    try {
      final contact = await CommunityApi.instance.request('/support-contact');
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            title: 'Highlander Care',
            isCare: true,
            recipientEmail: '${contact['email']}',
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$error'.replaceFirst('Exception: ', ''))),
        );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) => HeaderActionVisibility(
    kind: 'admin_chat',
    child: IconButton(
      key: const ValueKey('header-customer-support'),
      tooltip: 'Highlander Care',
      constraints: const BoxConstraints.tightFor(width: 32, height: 40),
      style: IconButton.styleFrom(
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        minimumSize: const Size(32, 40),
        padding: EdgeInsets.zero,
      ),
      padding: EdgeInsets.zero,
      onPressed: _loading ? null : _open,
      icon: _loading
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const HeaderActionIcon(
              kind: 'admin_chat',
              fallback: Icons.headset_mic_outlined,
              size: 22,
            ),
    ),
  );
}
