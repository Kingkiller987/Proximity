import 'package:flutter/material.dart';

import '../../core/config/app_config.dart';
import '../../core/media/native_image_picker_helper.dart';
import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../chat/chat_image_widgets.dart';
import '../profile/report_user_dialog.dart';
import '../profile/user_profile_sheet.dart';
import 'nearby_members_sidebar.dart';

enum _NearbyViewTab { nearbyChats, events }

class NearbyScreen extends StatefulWidget {
  const NearbyScreen({super.key, required this.controller, this.config});

  final AppController controller;
  final AppConfig? config;

  @override
  State<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends State<NearbyScreen> {
  final TextEditingController _composerController = TextEditingController();
  final NativeImagePickerHelper _imagePicker = NativeImagePickerHelper();
  _NearbyViewTab _activeView = _NearbyViewTab.nearbyChats;
  String? _selectedEventId;

  @override
  void dispose() {
    widget.controller.setCurrentlyActiveChannelId(null);
    _composerController.dispose();
    super.dispose();
  }

  String? get _activeChannelId {
    final active = widget.controller.activeLandmarkChats;
    if (active.isEmpty) return null;
    return active.any((c) => c.id == widget.controller.selectedLandmarkId)
        ? widget.controller.selectedLandmarkId
        : active.first.id;
  }

  Future<void> _handleAttachPhoto() async {
    final channelId = _activeView == _NearbyViewTab.nearbyChats
        ? _activeChannelId
        : _selectedEventId;
    if (channelId == null) return;

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
      widget.controller.stageImageUpload(
        channelId: channelId,
        rawBytes: result.sanitizedBytes!,
      );
    }
  }

  void _handleSend() {
    final text = _composerController.text.trim();
    if (_activeView == _NearbyViewTab.nearbyChats) {
      final channelId = _activeChannelId;
      if (channelId == null) return;
      final pending = widget.controller.pendingUploadsForChannel(channelId);
      final stagedId = pending.isNotEmpty ? pending.first.uploadId : null;
      if (text.isEmpty && stagedId == null) return;

      if (widget.controller.sendLandmarkMessage(
        channelId,
        text,
        stagedUploadId: stagedId,
      )) {
        _composerController.clear();
      }
    } else {
      final eventId = _selectedEventId;
      if (eventId == null) return;
      final pending = widget.controller.pendingUploadsForChannel(eventId);
      final stagedId = pending.isNotEmpty ? pending.first.uploadId : null;
      if (text.isEmpty && stagedId == null) return;

      if (widget.controller.sendEventMessage(
        eventId,
        text,
        stagedUploadId: stagedId,
      )) {
        _composerController.clear();
      }
    }
  }

  void _showParticipantSheet(String userId) {
    if (userId == widget.controller.profile.id) return;
    final projection = widget.controller.publicProjectionForUser(userId);
    showUserProfileSheet(
      context,
      projection: projection,
      distanceLabel: '~100m away',
      onSendDm: () {
        widget.controller.sendDmRequest(
          toUserId: userId,
          toDisplayName: projection.displayName,
          introMessage: 'Hello!',
        );
      },
      onBlock: () =>
          widget.controller.blockUser(userId, label: projection.displayName),
      onReport: () => ReportUserDialog.show(
        context,
        controller: widget.controller,
        targetId: userId,
        targetLabel: projection.displayName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final profile = c.profile;

        if (!c.hasLocationAccess) {
          return _LocationPermissionGate(controller: c);
        }

        final participants = c.visibleNearbyParticipants;
        final activeLandmarks = c.activeLandmarkChats;

        if (c.requestedNearbyTargetId != null) {
          if (c.requestedNearbyIsEvent) {
            _activeView = _NearbyViewTab.events;
            _selectedEventId = c.requestedNearbyTargetId;
          } else {
            _activeView = _NearbyViewTab.nearbyChats;
          }
        }

        final activeChannelId = _activeChannelId;
        final selectedLandmark = activeLandmarks
            .where((l) => l.id == activeChannelId)
            .firstOrNull;
        final joinedEvents = c.joinedEvents;
        if (_selectedEventId == null && joinedEvents.isNotEmpty) {
          _selectedEventId = joinedEvents.first.id;
        } else if (joinedEvents.isNotEmpty &&
            !joinedEvents.any((e) => e.id == _selectedEventId)) {
          _selectedEventId = joinedEvents.first.id;
        }

        final messages = _activeView == _NearbyViewTab.nearbyChats
            ? (activeChannelId != null
                  ? c.landmarkMessagesFor(activeChannelId)
                  : const <ChatMessage>[])
            : (_selectedEventId != null
                  ? c.eventMessagesFor(_selectedEventId!)
                  : const <ChatMessage>[]);

        final activeUploadChannelId = _activeView == _NearbyViewTab.nearbyChats
            ? activeChannelId
            : _selectedEventId;
        final pendingUploads = activeUploadChannelId != null
            ? c.pendingUploadsForChannel(activeUploadChannelId)
            : const <PendingImageUpload>[];

        return Scaffold(
          endDrawer: NearbyMembersSidebar(controller: c),
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Nearby Pulse'),
                Text(
                  selectedLandmark != null
                      ? selectedLandmark.headerDistanceLabel
                      : '${c.currentLocation.areaName} • Outside landmark zones',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              Builder(
                builder: (ctx) => IconButton(
                  key: const Key('nearby-members-sidebar-btn'),
                  tooltip: 'Nearby Members',
                  icon: const Icon(Icons.people_outline),
                  onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: c.toggleGhostMode,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: profile.isGhostMode
                          ? AppTheme.ghostViolet.withAlpha(45)
                          : AppTheme.pulseMint.withAlpha(45),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: profile.isGhostMode
                            ? AppTheme.ghostViolet
                            : AppTheme.pulseMint,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          profile.isGhostMode
                              ? Icons.visibility_off_outlined
                              : Icons.radar,
                          size: 15,
                          color: profile.isGhostMode
                              ? AppTheme.ghostViolet
                              : AppTheme.pulseMint,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Ghost Mode',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: profile.isGhostMode
                                ? const Color(0xFFC4B5FD)
                                : AppTheme.pulseMint,
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
              // 2-Way Switch: Nearby Chats | Events You're In
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('nearby-chats-tab'),
                        label: const Center(
                          child: Text(
                            'Nearby Chats',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        selected: _activeView == _NearbyViewTab.nearbyChats,
                        onSelected: (_) => setState(
                          () => _activeView = _NearbyViewTab.nearbyChats,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ChoiceChip(
                        key: const Key('nearby-events-tab'),
                        label: const Center(
                          child: Text(
                            "Events You're In",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        selected: _activeView == _NearbyViewTab.events,
                        onSelected: (_) =>
                            setState(() => _activeView = _NearbyViewTab.events),
                      ),
                    ),
                  ],
                ),
              ),
              if (!c.hasFreshAccurateLocation)
                Container(
                  margin: const EdgeInsets.all(16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:
                        Theme.of(context).cardTheme.color ??
                        Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppTheme.expiryAmber),
                  ),
                  child: Row(
                    children: <Widget>[
                      const Icon(
                        Icons.location_off_outlined,
                        color: AppTheme.expiryAmber,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Location fix expired or unavailable. Fresh location required to access proximity chat.',
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else if (_activeView == _NearbyViewTab.nearbyChats) ...<Widget>[
                // Proximity-chat dropdown
                if (activeLandmarks.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        key: const Key('nearby-proximity-chat-dropdown'),
                        isExpanded: true,
                        menuMaxHeight: (MediaQuery.sizeOf(context).height * 0.5)
                            .clamp(160.0, 320.0),
                        value:
                            activeLandmarks.any((l) => l.id == activeChannelId)
                            ? activeChannelId
                            : activeLandmarks.first.id,
                        items: activeLandmarks.map((lm) {
                          return DropdownMenuItem<String>(
                            value: lm.id,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                Text(
                                  lm.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  lm.headerDistanceLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) c.selectLandmark(id);
                        },
                      ),
                    ),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(12),
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    child: Center(
                      child: Text(
                        'Outside landmark zones. Move closer to enter a landmark proximity chat.',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                _PrivacyBanner(
                  visibleCount: participants.length,
                  isGhost: profile.isGhostMode,
                ),
                Expanded(
                  child: !c.canParticipateInNearby
                      ? const _BrowseDisabledState()
                      : messages.isEmpty
                      ? const _EmptyNearbyChatState()
                      : ListView.separated(
                          key: const Key('nearby-message-list'),
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                          itemCount: messages.length,
                          separatorBuilder: (_, _) =>
                              const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isMe = msg.senderId == profile.id;
                            return _ChatBubble(
                              controller: c,
                              message: msg,
                              isMe: isMe,
                              distanceLabel: msg.distanceLabel,
                              onTapSender: () =>
                                  _showParticipantSheet(msg.senderId),
                            );
                          },
                        ),
                ),
                StagedImagePreviewBar(
                  pendingUploads: pendingUploads,
                  onCancel: (id) => c.cancelStagedUpload(id),
                ),
                _MessageComposer(
                  controller: _composerController,
                  identityLabel: profile.activeDisplayName,
                  enabled:
                      c.canParticipateInNearby && activeLandmarks.isNotEmpty,
                  onAttachPhoto: _handleAttachPhoto,
                  onSend: _handleSend,
                ),
              ] else ...<Widget>[
                // Events You're In View
                if (joinedEvents.isEmpty)
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Text(
                          "You haven't joined any active events in this radius yet.\nDiscover events in the Explore tab.",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  )
                else ...<Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    color: Theme.of(context).colorScheme.surface,
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: _selectedEventId,
                        items: joinedEvents.map((evt) {
                          return DropdownMenuItem<String>(
                            value: evt.id,
                            child: Text(
                              '${evt.title} (${evt.participantCount} attendees)',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          );
                        }).toList(),
                        onChanged: (id) {
                          if (id != null) {
                            setState(() => _selectedEventId = id);
                          }
                        },
                      ),
                    ),
                  ),
                  Expanded(
                    child: messages.isEmpty
                        ? Center(
                            child: Text(
                              'No messages in this event chat yet.',
                              style: TextStyle(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                            itemCount: messages.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 10),
                            itemBuilder: (context, index) {
                              final msg = messages[index];
                              final isMe = msg.senderId == profile.id;
                              return _ChatBubble(
                                controller: c,
                                message: msg,
                                isMe: isMe,
                                distanceLabel: msg.distanceLabel,
                                onTapSender: () =>
                                    _showParticipantSheet(msg.senderId),
                              );
                            },
                          ),
                  ),
                  StagedImagePreviewBar(
                    pendingUploads: pendingUploads,
                    onCancel: (id) => c.cancelStagedUpload(id),
                  ),
                  _MessageComposer(
                    controller: _composerController,
                    identityLabel: profile.activeDisplayName,
                    enabled: true,
                    onAttachPhoto: _handleAttachPhoto,
                    onSend: _handleSend,
                  ),
                ],
              ],
            ],
          ),
        );
      },
    );
  }
}

class _PrivacyBanner extends StatelessWidget {
  const _PrivacyBanner({required this.visibleCount, required this.isGhost});

  final int visibleCount;
  final bool isGhost;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Row(
        children: <Widget>[
          Icon(
            isGhost ? Icons.visibility_off_outlined : Icons.people_outline,
            size: 15,
            color: isGhost ? AppTheme.ghostViolet : AppTheme.pulseMint,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              isGhost
                  ? 'Browsing privately (hidden from $visibleCount visible nearby)'
                  : '$visibleCount visible participant(s) in radius',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({
    required this.controller,
    required this.message,
    required this.isMe,
    required this.distanceLabel,
    required this.onTapSender,
  });

  final AppController controller;
  final ChatMessage message;
  final bool isMe;
  final String distanceLabel;
  final VoidCallback onTapSender;

  @override
  Widget build(BuildContext context) {
    final sentTime = formatMessageTimestamp(message.createdAt, controller.now);
    final theme = Theme.of(context);
    final isLight = theme.brightness == Brightness.light;

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
                  ? AppTheme.radarTeal.withAlpha(isLight ? 45 : 66)
                  : (theme.cardTheme.color ?? theme.colorScheme.surface),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isMe
                    ? AppTheme.pulseMint.withAlpha(128)
                    : theme.colorScheme.outlineVariant,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Builder(
                      builder: (context) {
                        final projection = controller.publicProjectionForUser(
                          message.senderId,
                        );
                        final hasAvatar =
                            !message.isAnonymous &&
                            projection.avatarBytes != null &&
                            projection.avatarBytes!.isNotEmpty;

                        if (hasAvatar) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ClipOval(
                              child: Image.memory(
                                projection.avatarBytes!,
                                width: 16,
                                height: 16,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => const Icon(
                                  Icons.person_outline,
                                  size: 13,
                                  color: AppTheme.pulseMint,
                                ),
                              ),
                            ),
                          );
                        }

                        return Padding(
                          padding: const EdgeInsets.only(right: 4),
                          child: Icon(
                            message.isAnonymous
                                ? Icons.person
                                : Icons.person_outline,
                            size: 13,
                            color: message.isAnonymous
                                ? theme.colorScheme.onSurfaceVariant
                                : AppTheme.pulseMint,
                          ),
                        );
                      },
                    ),
                    Flexible(
                      child: Text(
                        isMe
                            ? '${message.senderDisplayName} (You)'
                            : message.senderDisplayName,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: isMe
                              ? (isLight
                                    ? AppTheme.radarTeal
                                    : AppTheme.pulseMint)
                              : theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      distanceLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
                if (message.body.isNotEmpty) ...<Widget>[
                  const SizedBox(height: 6),
                  Text(
                    message.body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.35,
                      color: isLight
                          ? const Color(0xFF0F172A)
                          : const Color(0xFFF8FAFC),
                    ),
                  ),
                ],
                if (message.attachment != null)
                  ChatImageBubble(
                    controller: controller,
                    attachment: message.attachment!,
                  ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 2,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: <Widget>[
                    Text(
                      sentTime,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                    if (!isMe)
                      const Text(
                        'Tap for user sheet',
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
    required this.enabled,
    required this.onAttachPhoto,
    required this.onSend,
  });

  final TextEditingController controller;
  final String identityLabel;
  final bool enabled;
  final VoidCallback onAttachPhoto;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
        ),
        child: Row(
          children: <Widget>[
            IconButton(
              key: const Key('nearby-attach-photo-btn'),
              tooltip: 'Attach EXIF-stripped photo',
              onPressed: enabled ? onAttachPhoto : null,
              icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            ),
            Expanded(
              child: TextField(
                controller: controller,
                enabled: enabled,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Post as $identityLabel...'
                      : 'Enter a landmark radius to post...',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: enabled ? onSend : null,
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
                  Text(
                    'Proximity uses your coarse area to show nearby chats and local temporary events. Your exact coordinates are never shown to other users, and you can browse in Ghost Mode.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(Icons.radar, size: 40, color: AppTheme.pulseMint),
            const SizedBox(height: 10),
            const Text(
              'Quiet in this landmark right now',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Select another landmark or start a conversation for people nearby.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
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
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Icon(
              Icons.visibility_off,
              size: 40,
              color: AppTheme.ghostViolet,
            ),
            const SizedBox(height: 10),
            const Text(
              'Nearby Feed Paused',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Both Nearby Visibility and Ghost Browsing are turned off in your Profile settings.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
