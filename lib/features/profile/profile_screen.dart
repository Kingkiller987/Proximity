import 'package:flutter/material.dart';

import '../../core/media/native_image_picker_helper.dart';
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
  late TextEditingController _bioController;
  final TextEditingController _searchController = TextEditingController();
  final NativeImagePickerHelper _imagePicker = NativeImagePickerHelper();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _bioController = TextEditingController(text: widget.controller.profile.bio);
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final text = _searchController.text.trim().toLowerCase();
    if (_searchQuery != text) {
      setState(() {
        _searchQuery = text;
      });
    }
  }

  @override
  void didUpdateWidget(ProfileScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller.profile.bio != widget.controller.profile.bio) {
      _bioController.text = widget.controller.profile.bio;
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  Future<void> _pickAvatar() async {
    final result = await _imagePicker.promptAndPickSanitizedImage(
      context,
      maxBytes: widget.controller.maxImageBytes,
    );
    if (result == null) return;
    if (result.errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(result.errorMessage!),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }
    if (result.isValid && result.sanitizedBytes != null && mounted) {
      widget.controller.updateRealProfile(avatarBytes: result.sanitizedBytes);
      setState(() {});
    }
  }

  void _saveBio() {
    widget.controller.updateRealProfile(bio: _bioController.text.trim());
    setState(() {});
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully.')),
    );
  }

  void _showChangeEmailDialog() {
    final emailCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('change-email-dialog'),
          title: const Text('Change Email Address'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.radarTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.radarTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Demo flow: 2FA email code is simulated locally (enter demo code 123456).',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (dialogError != null) ...<Widget>[
                  Text(
                    dialogError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  key: const Key('change-email-new-field'),
                  controller: emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'New Email Address',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('change-email-2fa-field'),
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code (123456)',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('submit-change-email-btn'),
              onPressed: () {
                final err = widget.controller.updateEmailDemo(
                  emailCtrl.text,
                  codeCtrl.text,
                );
                if (err != null) {
                  setDialogState(() => dialogError = err);
                } else {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Email updated successfully (demo).'),
                    ),
                  );
                }
              },
              child: const Text('Update Email'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangePasswordDialog() {
    final pwdCtrl = TextEditingController();
    final codeCtrl = TextEditingController();
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          key: const Key('change-password-dialog'),
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.radarTeal.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.radarTeal.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    'Demo flow: 2FA email code is simulated locally (enter demo code 123456). Passwords are never stored.',
                    style: TextStyle(
                      fontSize: 11,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (dialogError != null) ...<Widget>[
                  Text(
                    dialogError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                TextField(
                  key: const Key('change-password-new-field'),
                  controller: pwdCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password (min 8 chars)',
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const Key('change-password-2fa-field'),
                  controller: codeCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Verification Code (123456)',
                    isDense: true,
                  ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                pwdCtrl.clear();
                Navigator.of(ctx).pop();
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              key: const Key('submit-change-password-btn'),
              onPressed: () {
                final err = widget.controller.updatePasswordDemo(
                  pwdCtrl.text,
                  codeCtrl.text,
                );
                pwdCtrl.clear(); // Clear ephemeral password immediately
                if (err != null) {
                  setDialogState(() => dialogError = err);
                } else {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Password updated successfully (demo).'),
                    ),
                  );
                }
              },
              child: const Text('Update Password'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final p = c.profile;

    final q = _searchQuery;
    final showPersonalization =
        q.isEmpty ||
        'personalization'.contains(q) ||
        'theme'.contains(q) ||
        'dark'.contains(q) ||
        'light'.contains(q) ||
        'avatar'.contains(q) ||
        'photo'.contains(q) ||
        'bio'.contains(q) ||
        'profile picture'.contains(q);

    final showSecurity =
        q.isEmpty ||
        'security'.contains(q) ||
        'privacy'.contains(q) ||
        'email'.contains(q) ||
        'password'.contains(q) ||
        '2fa'.contains(q) ||
        'ghost mode'.contains(q) ||
        'ghost'.contains(q) ||
        'anonymous'.contains(q);

    final showMiscellaneous =
        q.isEmpty ||
        'miscellaneous'.contains(q) ||
        'blocked'.contains(q) ||
        'safety'.contains(q) ||
        'report'.contains(q) ||
        'ticket'.contains(q) ||
        'location'.contains(q) ||
        'simulator'.contains(q) ||
        'permission'.contains(q) ||
        'logout'.contains(q) ||
        'log out'.contains(q);

    final noResults =
        !showPersonalization && !showSecurity && !showMiscellaneous;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Privacy')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // Top Search Field
          TextField(
            key: const Key('settings-search-field'),
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search settings...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      key: const Key('settings-search-clear-btn'),
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        _searchController.clear();
                      },
                    )
                  : null,
              isDense: true,
              filled: true,
              fillColor: Theme.of(context).colorScheme.surfaceContainerLow,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          if (noResults) ...<Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text(
                  'No settings match your search',
                  key: const Key('settings-no-results-text'),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],

          // SECTION 1: Personalization
          if (showPersonalization) ...<Widget>[
            Card(
              key: const Key('settings-section-personalization'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.palette_outlined,
                          size: 20,
                          color: AppTheme.pulseMint,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Personalization',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Theme Switcher
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 12,
                      runSpacing: 10,
                      children: <Widget>[
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Text(
                              'App Theme',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Switch between Dark and Light mode',
                              style: TextStyle(
                                fontSize: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        SegmentedButton<ThemeMode>(
                          key: const Key('settings-theme-segmented'),
                          segments: const <ButtonSegment<ThemeMode>>[
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.dark,
                              label: Text('Dark'),
                              icon: Icon(Icons.dark_mode, size: 16),
                            ),
                            ButtonSegment<ThemeMode>(
                              value: ThemeMode.light,
                              label: Text('Light'),
                              icon: Icon(Icons.light_mode, size: 16),
                            ),
                          ],
                          selected: <ThemeMode>{c.themeMode},
                          onSelectionChanged: (set) {
                            c.setThemeMode(set.first);
                            setState(() {});
                          },
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    // Avatar & Identity
                    Row(
                      children: <Widget>[
                        GestureDetector(
                          key: const Key('profile-pick-avatar-btn'),
                          onTap: p.isAnonymous ? null : _pickAvatar,
                          child: Stack(
                            children: <Widget>[
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: AppTheme.pulseMint.withAlpha(
                                  40,
                                ),
                                backgroundImage:
                                    (!p.isAnonymous && p.avatarBytes != null)
                                    ? MemoryImage(p.avatarBytes!)
                                    : null,
                                child: (p.isAnonymous || p.avatarBytes == null)
                                    ? const Icon(
                                        Icons.person,
                                        color: AppTheme.pulseMint,
                                        size: 30,
                                      )
                                    : null,
                              ),
                              if (!p.isAnonymous)
                                Positioned(
                                  right: 0,
                                  bottom: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                      color: AppTheme.pulseMint,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt,
                                      size: 12,
                                      color: Colors.black,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                p.isAnonymous
                                    ? p.anonymousHandle
                                    : '@${p.username}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                p.isAnonymous
                                    ? 'Assigned Anonymous Identity • Immutable across sessions'
                                    : 'Public Profile Username',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    if (!p.isAnonymous) ...<Widget>[
                      const SizedBox(height: 14),
                      TextField(
                        key: const Key('profile-bio-field'),
                        controller: _bioController,
                        maxLines: 2,
                        maxLength: 160,
                        decoration: const InputDecoration(
                          labelText: 'About You (Bio)',
                          hintText: 'Share a brief intro...',
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          key: const Key('profile-save-btn'),
                          onPressed: _saveBio,
                          child: const Text('Save Bio'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SECTION 2: Security & Privacy
          if (showSecurity) ...<Widget>[
            Card(
              key: const Key('settings-section-security'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.shield_outlined,
                          size: 20,
                          color: AppTheme.eventIndigo,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Security & Privacy',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Change Email & Password Actions
                    ListTile(
                      key: const Key('settings-change-email-btn'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.email_outlined),
                      title: const Text('Change Email Address'),
                      subtitle: const Text(
                        'Update login email with 2FA verification',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showChangeEmailDialog,
                    ),
                    const Divider(height: 1),
                    ListTile(
                      key: const Key('settings-change-password-btn'),
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_reset),
                      title: const Text('Change Password'),
                      subtitle: const Text(
                        'Update password with 2FA verification',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _showChangePasswordDialog,
                    ),
                    const Divider(height: 16),
                    // Ghost Mode
                    SwitchListTile(
                      key: const Key('profile-ghost-mode-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Ghost Mode'),
                      subtitle: const Text(
                        'Pause nearby proximity chats and hide from nearby discovery while keeping access to joined events.',
                      ),
                      value: p.isGhostMode,
                      onChanged: (val) {
                        c.setGhostMode(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 16),
                    // Anonymous Mode
                    SwitchListTile(
                      key: const Key('profile-anonymous-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Anonymous Mode'),
                      subtitle: Text(
                        c.isHostingActiveEvent
                            ? 'Cannot enable Anonymous Mode while hosting active event(s). Transfer ownership or end your event(s) first.'
                            : 'Mask real profile with random alias in Nearby chats. Event hosting and DMs remain public.',
                        style: TextStyle(
                          color: c.isHostingActiveEvent
                              ? Colors.orangeAccent
                              : null,
                        ),
                      ),
                      value: p.isAnonymous,
                      onChanged: c.isHostingActiveEvent
                          ? null
                          : (val) {
                              c.setAnonymousMode(val);
                              setState(() {});
                            },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Notifications & Alerts
            Card(
              key: const Key('settings-section-notifications'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.notifications_outlined,
                          size: 20,
                          color: AppTheme.radarTeal,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Notifications',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SwitchListTile(
                      key: const Key('profile-notify-nearby-events-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Nearby Event Discovery'),
                      subtitle: const Text(
                        'Alert when a new event becomes available within discovery range.',
                      ),
                      value: p.notifyNearbyEvents,
                      onChanged: (val) {
                        c.setNotifyNearbyEvents(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 16),
                    SwitchListTile(
                      key: const Key('profile-notify-nearby-chat-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Nearby Chat Messages'),
                      subtitle: const Text(
                        'Alert on new messages in nearby landmark chats (suppressed in Ghost Mode).',
                      ),
                      value: p.notifyNearbyChat,
                      onChanged: (val) {
                        c.setNotifyNearbyChat(val);
                        setState(() {});
                      },
                    ),
                    const Divider(height: 16),
                    SwitchListTile(
                      key: const Key('profile-notify-joined-events-switch'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Joined Event Chat Messages'),
                      subtitle: const Text(
                        'Alert on new messages in event chats you participate in.',
                      ),
                      value: p.notifyJoinedEventChat,
                      onChanged: (val) {
                        c.setNotifyJoinedEventChat(val);
                        setState(() {});
                      },
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // SECTION 3: Miscellaneous
          if (showMiscellaneous) ...<Widget>[
            Card(
              key: const Key('settings-section-miscellaneous'),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    const Row(
                      children: <Widget>[
                        Icon(
                          Icons.more_horiz,
                          size: 20,
                          color: AppTheme.expiryAmber,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Miscellaneous',
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    // Location & Simulation Mode
                    const Text(
                      'Location Permissions & Simulator',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: LocationPermissionState.values.map((st) {
                        return ChoiceChip(
                          label: Text(st.name),
                          selected: c.permissionState == st,
                          onSelected: (_) {
                            c.setPermissionState(st);
                            setState(() {});
                          },
                        );
                      }).toList(),
                    ),
                    const Divider(height: 24),
                    // Safety Ledger
                    Text(
                      'Safety Ledger • ${c.blockedUserIds.length} Blocked, ${c.reports.length} Reports',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    if (c.blockedUserIds.isEmpty && c.reports.isEmpty)
                      Text(
                        'No blocked users or active safety reports.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ...c.blockedUserLabels.entries.map(
                      (entry) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text('Blocked: ${entry.value}'),
                        trailing: TextButton(
                          onPressed: () {
                            c.unblockUser(entry.key);
                            setState(() {});
                          },
                          child: const Text('Unblock'),
                        ),
                      ),
                    ),
                    ...c.reports.map(
                      (rep) => Card(
                        key: Key('safety-report-item-${rep.id}'),
                        margin: const EdgeInsets.only(top: 8),
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Row(
                                children: <Widget>[
                                  const Icon(
                                    Icons.flag_outlined,
                                    size: 16,
                                    color: Colors.redAccent,
                                  ),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      'Report: ${rep.targetLabel}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent.withAlpha(40),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      rep.preset.displayName.toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.redAccent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                rep.explanation,
                                style: const TextStyle(fontSize: 12),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: <Widget>[
                                  Text(
                                    rep.status,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: AppTheme.expiryAmber,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    '${rep.createdAt.month}/${rep.createdAt.day} ${rep.createdAt.hour}:${rep.createdAt.minute.toString().padLeft(2, '0')}',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Theme.of(context)
                                          .colorScheme
                                          .onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Log Out Button
            OutlinedButton.icon(
              key: const Key('profile-logout-btn'),
              onPressed: c.logout,
              icon: const Icon(Icons.logout, color: Colors.redAccent),
              label: const Text(
                'Log Out',
                style: TextStyle(color: Colors.redAccent),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
