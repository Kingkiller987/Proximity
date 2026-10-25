import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final TextEditingController _anonCtrl;
  late final TextEditingController _userCtrl;

  @override
  void initState() {
    super.initState();
    _anonCtrl = TextEditingController(
      text: widget.controller.profile.anonymousHandle,
    );
    _userCtrl = TextEditingController(text: widget.controller.profile.username);
  }

  @override
  void dispose() {
    _anonCtrl.dispose();
    _userCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = c.profile;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppTheme.pulseMint.withValues(
                          alpha: 0.2,
                        ),
                        child: Icon(
                          p.isAnonymous
                              ? Icons.shield_outlined
                              : Icons.alternate_email,
                          color: AppTheme.pulseMint,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              p.activeDisplayName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              p.isAnonymous
                                  ? 'Active Mode: Anonymous Display Name'
                                  : 'Active Mode: Chosen Username',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  SegmentedButton<IdentityMode>(
                    segments: const <ButtonSegment<IdentityMode>>[
                      ButtonSegment<IdentityMode>(
                        value: IdentityMode.anonymous,
                        label: Text('Anonymous Handle'),
                        icon: Icon(Icons.shield_outlined, size: 16),
                      ),
                      ButtonSegment<IdentityMode>(
                        value: IdentityMode.username,
                        label: Text('Username'),
                        icon: Icon(Icons.alternate_email, size: 16),
                      ),
                    ],
                    selected: <IdentityMode>{p.identityMode},
                    onSelectionChanged: (s) => c.setIdentityMode(s.first),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: TextField(
                          controller: _anonCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Anonymous Handle',
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _userCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Username',
                            prefixText: '@',
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerRight,
                    child: OutlinedButton(
                      onPressed: () {
                        c.updateProfileHandles(
                          anonymousHandle: _anonCtrl.text,
                          username: _userCtrl.text,
                        );
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Identity handles updated.'),
                          ),
                        );
                      },
                      child: const Text('Save Handles'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: Text(
                      'Attendance & Discovery Privacy',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  SwitchListTile(
                    title: const Text('Appear in General Nearby Discovery'),
                    subtitle: const Text(
                      'When off, you never appear in the nearby participants list.',
                    ),
                    value: p.visibleInNearby,
                    onChanged: c.setVisibleInNearby,
                  ),
                  SwitchListTile(
                    title: const Text('Browse Nearby Chat in Ghost Mode'),
                    subtitle: const Text(
                      'Read general nearby messages without appearing as an active participant.',
                    ),
                    value: p.ghostBrowseNearby,
                    onChanged: c.setGhostBrowseNearby,
                  ),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Text(
                      'Event Attendance Isolation: Joining an event only shows you inside that event and never exposes you in general Nearby discovery.',
                      style: TextStyle(fontSize: 12, color: Color(0xFFC4B5FD)),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Ephemeral Message Retention',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Messages you send in general nearby chat expire automatically after:',
                    style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: <int>[6, 12, 24].map((hrs) {
                      return ChoiceChip(
                        label: Text('$hrs hours'),
                        selected: p.messageRetentionHours == hrs,
                        onSelected: (_) => c.setMessageRetentionHours(hrs),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Location Permission & Simulator Mode',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: LocationPermissionState.values.map((st) {
                      return ChoiceChip(
                        label: Text(st.name),
                        selected: c.permissionState == st,
                        onSelected: (_) => c.setPermissionState(st),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Safety Ledger • ${c.blockedUserIds.length} Blocked, ${c.reports.length} Reports',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (c.blockedUserIds.isEmpty && c.reports.isEmpty)
                    const Text(
                      'No blocked users or active safety reports.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
                    ),
                  ...c.blockedUserLabels.entries.map(
                    (entry) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text('Blocked: ${entry.value}'),
                      trailing: TextButton(
                        onPressed: () => c.unblockUser(entry.key),
                        child: const Text('Unblock'),
                      ),
                    ),
                  ),
                  ...c.reports.map(
                    (rep) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(
                        Icons.flag_outlined,
                        size: 16,
                        color: AppTheme.expiryAmber,
                      ),
                      title: Text('Reported ${rep.targetLabel}'),
                      subtitle: Text(rep.reason),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
