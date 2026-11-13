import 'package:flutter/material.dart';

import '../community_api.dart';
import '../theme.dart';

class GroupAddPrivacyToggle extends StatefulWidget {
  const GroupAddPrivacyToggle({super.key});
  @override
  State<GroupAddPrivacyToggle> createState() => _GroupAddPrivacyToggleState();
}

class _GroupAddPrivacyToggleState extends State<GroupAddPrivacyToggle> {
  Map<String, dynamic>? _settings;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final result = await CommunityApi.instance.request('/settings') as Map;
      if (mounted) {
        setState(() {
          _settings = Map<String, dynamic>.from(result);
          _error = null;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load group privacy.');
    }
  }

  Future<void> _save(bool value) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await CommunityApi.instance.request(
        '/settings',
        method: 'PUT',
        body: {'allowGroupAdds': value},
      );
      if (mounted) setState(() => _settings!['allowGroupAdds'] = value);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save group privacy. Try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    color: Colors.white,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: Color(0xFFECEEF2)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SwitchListTile(
          key: const ValueKey('allow-group-adds'),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          title: const Text(
            'Allow direct group adds',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            _settings == null
                ? 'Loading your preference...'
                : _settings!['allowGroupAdds'] == true
                ? 'People can add you directly.'
                : 'Send me an invitation first.',
            style: const TextStyle(fontSize: 13, color: authMuted, height: 1.4),
          ),
          value: _settings?['allowGroupAdds'] == true,
          onChanged: _settings == null || _busy ? null : _save,
          activeThumbColor: authRed,
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                Expanded(
                  child: Text(_error!, style: const TextStyle(color: authRed)),
                ),
                if (_settings == null)
                  TextButton(onPressed: _load, child: const Text('Retry')),
              ],
            ),
          ),
      ],
    ),
  );
}
