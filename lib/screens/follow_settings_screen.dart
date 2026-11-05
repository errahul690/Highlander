import '../widgets/club_page_body.dart';

import 'package:flutter/material.dart';

import '../community_api.dart';
import '../theme.dart';
import '../widgets/club_bar.dart';
import 'follow_requests_screen.dart';

class FollowSettingsScreen extends StatefulWidget {
  const FollowSettingsScreen({super.key});
  @override
  State<FollowSettingsScreen> createState() => _FollowSettingsScreenState();
}

class _FollowSettingsScreenState extends State<FollowSettingsScreen> {
  bool _loading = true, _loaded = false, _saving = false, _approval = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data =
          await CommunityApi.instance.request('/follow-settings') as Map;
      if (mounted) {
        setState(() {
          _approval = data['approvalRequired'] == true;
          _loaded = true;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await CommunityApi.instance.request(
        '/follow-settings',
        method: 'PUT',
        body: {'approvalRequired': _approval},
      );
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (error) {
      if (mounted) {
        setState(() => _error = '$error'.replaceFirst('Exception: ', ''));
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => ClubScaffold(
    appBar: const ClubBar(title: 'Follow settings'),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : !_loaded
        ? Center(
            child: TextButton(
              onPressed: _load,
              child: Text('${_error ?? 'Could not load settings.'} Retry'),
            ),
          )
        : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Who can follow me?',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                activeThumbColor: authRed,
                title: const Text('Approve follow requests'),
                subtitle: Text(
                  _approval
                      ? 'People must send a request. You choose who can follow you.'
                      : 'Anyone can follow you immediately.',
                ),
                value: _approval,
                onChanged: _saving
                    ? null
                    : (value) => setState(() => _approval = value),
              ),
              const SizedBox(height: 12),
              const Text(
                'Existing followers stay connected. Changing this setting applies to new follows. Existing pending requests still need to be reviewed.',
                style: TextStyle(color: authMuted),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Text(_error!, style: const TextStyle(color: authRed)),
                ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(_saving ? 'Saving…' : 'Save settings'),
              ),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FollowRequestsScreen(),
                        ),
                      ),
                icon: const Icon(Icons.person_add_alt_outlined),
                label: const Text('View follow requests'),
              ),
            ],
          ),
  );
}
