import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final TextEditingController _composerController = TextEditingController();

  @override
  void dispose() {
    _composerController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = _composerController.text.trim();
    if (text.isEmpty) return;
    widget.controller.sendNearbyMessage(text);
    _composerController.clear();
  }

  void _showParticipantActions(
    BuildContext context, {
    required String userId,
    required String displayName,
  }) {
    if (userId == widget.controller.profile.id) return;
    final dmInput = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    backgroundColor: AppTheme.pulseMint.withValues(alpha: 0.2),
                    child: Text(
                      displayName.replaceFirst('@', '').substring(0, 1),
                      style: const TextStyle(
                        color: AppTheme.pulseMint,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          displayName,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Text(
                          'Exact coordinates hidden • DM requires approval',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: dmInput,
                decoration: const InputDecoration(
                  labelText: 'Request Direct Message',
                  hintText: 'Say hello and why you want to connect...',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    final err = widget.controller.sendDmRequest(
                      toUserId: userId,
                      toDisplayName: displayName,
                      introMessage: dmInput.text,
                    );
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          err ?? 'Message request sent to $displayName.',
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.mark_chat_unread_outlined, size: 18),
                  label: const Text('Send DM Request'),
                ),
              ),
              const Divider(height: 24),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.controller.blockUser(userId, label: displayName);
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Blocked $displayName.')),
                        );
                      },
                      icon: const Icon(Icons.block, size: 18),
                      label: const Text('Block'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        widget.controller.reportTarget(
                          targetId: userId,
                          targetLabel: displayName,
                          reason: 'Reported from nearby chat',
                        );
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Reported $displayName for review.'),
                          ),
                        );
                      },
                      icon: const Icon(Icons.flag_outlined, size: 18),
                      label: const Text('Report'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final profile = c.profile;

    if (!c.hasLocationAccess) {
      return _LocationPermissionGate(controller: c);
    }

    final participants = c.visibleNearbyParticipants;
    final messages = c.nearbyMessages;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Nearby Pulse'),
            Text(
              '${c.currentLocation.areaName} • ${(profile.nearbyRadiusMeters).round()}m radius',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => c.setVisibleInNearby(!profile.visibleInNearby),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: profile.visibleInNearby
                      ? AppTheme.pulseMint.withValues(alpha: 0.18)
                      : AppTheme.ghostViolet.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: profile.visibleInNearby
                        ? AppTheme.pulseMint
                        : AppTheme.ghostViolet,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      profile.visibleInNearby
                          ? Icons.radar
                          : Icons.visibility_off_outlined,
                      size: 15,
                      color: profile.visibleInNearby
                          ? AppTheme.pulseMint
                          : AppTheme.ghostViolet,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      profile.visibleInNearby ? 'Visible' : 'Ghost Mode',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: profile.visibleInNearby
                            ? AppTheme.pulseMint
                            : const Color(0xFFC4B5FD),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _RadiusAndLocationBar(controller: c),
          _EphemeralNoticeBanner(
            retentionHours: profile.messageRetentionHours,
            visibleCount: participants.length,
            isGhost: !profile.visibleInNearby && profile.ghostBrowseNearby,
          ),
          if (participants.isNotEmpty)
            SizedBox(
              height: 46,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                scrollDirection: Axis.horizontal,
                itemCount: participants.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final p = participants[index];
                  final distLabel = c.currentLocation.privacyDistanceLabelTo(
                    p.location,
                  );
                  return ActionChip(
                    avatar: Icon(
                      p.isAnonymous
                          ? Icons.shield_outlined
                          : Icons.alternate_email,
                      size: 15,
                      color: AppTheme.pulseMint,
                    ),
                    label: Text(
                      '${p.displayName} • $distLabel',
                      style: const TextStyle(fontSize: 12),
                    ),
                    onPressed: () => _showParticipantActions(
                      context,
                      userId: p.userId,
                      displayName: p.displayName,
                    ),
                  );
                },
              ),
            ),
          Expanded(
            child: !profile.visibleInNearby && !profile.ghostBrowseNearby
                ? const _BrowseDisabledState()
                : messages.isEmpty
                ? const _EmptyNearbyChatState()
                : ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    itemCount: messages.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg.senderId == profile.id;
                      final distLabel = c.currentLocation
                          .privacyDistanceLabelTo(msg.originPoint);
                      final expiryLabel = formatRemainingTime(
                        msg.expiresAt,
                        c.now,
                      );
                      return _ChatBubble(
                        message: msg,
                        isMe: isMe,
                        distanceLabel: distLabel,
                        expiryLabel: expiryLabel,
                        onTapSender: () => _showParticipantActions(
                          context,
                          userId: msg.senderId,
                          displayName: msg.senderDisplayName,
                        ),
                      );
                    },
                  ),
          ),
          _MessageComposer(
            controller: _composerController,
            identityLabel: profile.activeDisplayName,
            retentionHours: profile.messageRetentionHours,
            onSend: _handleSend,
          ),
        ],
      ),
    );
  }
}

class _RadiusAndLocationBar extends StatelessWidget {
  const _RadiusAndLocationBar({required this.controller});

  final AppController controller;

  static const List<double> _radii = <double>[250, 500, 1000, 2500];

  @override
  Widget build(BuildContext context) {
    final currentRadius = controller.profile.nearbyRadiusMeters;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: AppTheme.darkSurface,
        border: Border(bottom: BorderSide(color: Color(0xFF283558))),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<GeoPoint>(
                isExpanded: true,
                isDense: true,
                value: controller.currentLocation,
                icon: const Icon(
                  Icons.my_location_outlined,
                  size: 16,
                  color: AppTheme.pulseMint,
                ),
                items: AppController.presetLocations.map((loc) {
                  return DropdownMenuItem<GeoPoint>(
                    value: loc,
                    child: Text(
                      loc.areaName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (loc) {
                  if (loc != null) controller.setSimulatedLocation(loc);
                },
              ),
            ),
          ),
          const SizedBox(width: 8),
          Wrap(
            spacing: 4,
            children: _radii.map((r) {
              final selected = (currentRadius - r).abs() < 1;
              final label = r >= 1000
                  ? '${(r / 1000).toStringAsFixed(r == 1000 ? 0 : 1)}km'
                  : '${r.round()}m';
              return ChoiceChip(
                label: Text(label, style: const TextStyle(fontSize: 11)),
                selected: selected,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => controller.setNearbyRadiusMeters(r),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _EphemeralNoticeBanner extends StatelessWidget {
  const _EphemeralNoticeBanner({
    required this.retentionHours,
    required this.visibleCount,
    required this.isGhost,
  });

  final int retentionHours;
  final int visibleCount;
  final bool isGhost;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: const Color(0xFF162038),
      child: Row(
        children: <Widget>[
          const Icon(
            Icons.timer_outlined,
            size: 15,
            color: AppTheme.expiryAmber,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isGhost
                  ? 'Auto-expires in ${retentionHours}h • Browsing privately (hidden from $visibleCount visible nearby)'
                  : 'Auto-expires in ${retentionHours}h • $visibleCount visible participant(s) in radius',
              style: const TextStyle(fontSize: 12, color: Color(0xFFCBD5E1)),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.message,
    required this.isMe,
    required this.distanceLabel,
    required this.expiryLabel,
    required this.onTapSender,
  });

  final ChatMessage message;
  final bool isMe;
  final String distanceLabel;
  final String expiryLabel;
  final VoidCallback onTapSender;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 340),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isMe ? null : onTapSender,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isMe
                  ? AppTheme.radarTeal.withValues(alpha: 0.26)
                  : AppTheme.darkCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMe
                    ? AppTheme.pulseMint.withValues(alpha: 0.5)
                    : const Color(0xFF283558),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(
                      message.isAnonymous
                          ? Icons.shield_outlined
                          : Icons.verified_user_outlined,
                      size: 13,
                      color: message.isAnonymous
                          ? const Color(0xFF94A3B8)
                          : AppTheme.pulseMint,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        isMe
                            ? '${message.senderDisplayName} (You)'
                            : message.senderDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isMe
                              ? AppTheme.pulseMint
                              : const Color(0xFFE2E8F0),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      distanceLabel,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  message.body,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.35,
                    color: Color(0xFFF8FAFC),
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.expiryAmber.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '⏳ $expiryLabel',
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.expiryAmber,
                        ),
                      ),
                    ),
                    if (!isMe)
                      const Text(
                        'Tap to request DM / safety',
                        style: TextStyle(
                          fontSize: 10,
                          color: Color(0xFF64748B),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MessageComposer extends StatelessWidget {
  const _MessageComposer({
    required this.controller,
    required this.identityLabel,
    required this.retentionHours,
    required this.onSend,
  });

  final TextEditingController controller;
  final String identityLabel;
  final int retentionHours;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: const BoxDecoration(
          color: AppTheme.darkSurface,
          border: Border(top: BorderSide(color: Color(0xFF283558))),
        ),
        child: Row(
          children: <Widget>[
            Expanded(
              child: TextField(
                controller: controller,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText:
                      'Post as $identityLabel (${retentionHours}h expiry)...',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onSend,
              icon: const Icon(Icons.send_rounded, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationPermissionGate extends StatelessWidget {
  const _LocationPermissionGate({required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    final denied = controller.permissionState == LocationPermissionState.denied;
    return Scaffold(
      appBar: AppBar(title: const Text('Nearby Pulse')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    denied
                        ? Icons.location_disabled_outlined
                        : Icons.explore_outlined,
                    size: 48,
                    color: denied ? AppTheme.expiryAmber : AppTheme.pulseMint,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    denied
                        ? 'Location Permission Denied'
                        : 'Enable Proximity Discovery',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Proximity uses your coarse area to show nearby chats and local temporary events. Your exact coordinates are never shown to other users, and you can browse in Ghost Mode.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Color(0xFF94A3B8), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => controller.setPermissionState(
                        LocationPermissionState.granted,
                      ),
                      icon: const Icon(Icons.my_location),
                      label: const Text('Grant While-In-Use Location'),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => controller.setPermissionState(
                        LocationPermissionState.simulated,
                      ),
                      icon: const Icon(Icons.science_outlined),
                      label: const Text('Use Simulated Campus Location'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyNearbyChatState extends StatelessWidget {
  const _EmptyNearbyChatState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.radar, size: 44, color: AppTheme.pulseMint),
            SizedBox(height: 12),
            Text(
              'Quiet in this radius right now',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Expand your discovery radius above or start a temporary conversation for people nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _BrowseDisabledState extends StatelessWidget {
  const _BrowseDisabledState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.visibility_off, size: 44, color: AppTheme.ghostViolet),
            SizedBox(height: 12),
            Text(
              'Nearby Feed Paused',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            SizedBox(height: 6),
            Text(
              'Both Nearby Visibility and Ghost Browsing are turned off in your Profile settings.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Color(0xFF94A3B8)),
            ),
          ],
        ),
      ),
    );
  }
}
