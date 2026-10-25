import 'package:flutter/material.dart';

import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class ExploreEventsScreen extends StatefulWidget {
  const ExploreEventsScreen({super.key, required this.controller});

  final AppController controller;

  @override
  State<ExploreEventsScreen> createState() => _ExploreEventsScreenState();
}

class _ExploreEventsScreenState extends State<ExploreEventsScreen> {
  EventAccessType? _accessFilter;
  bool _onlyJoined = false;

  void _openEventSheet(BuildContext context, ProximityEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.darkSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: _EventDetailSheet(
          controller: widget.controller,
          eventId: event.id,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final allEvents = c.discoverableEvents;
    final filtered = allEvents.where((e) {
      if (_onlyJoined && !e.participantIds.contains(c.profile.id)) return false;
      if (_accessFilter != null && e.accessType != _accessFilter) return false;
      return true;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Text('Explore Local Events'),
            Text(
              'Around ${c.currentLocation.areaName}',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: <Widget>[
          if (c.eventAlerts.isNotEmpty) ...<Widget>[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.expiryAmber.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppTheme.expiryAmber.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: AppTheme.expiryAmber,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      c.eventAlerts.first,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _EventRadarOverview(
            currentLocation: c.currentLocation,
            events: filtered,
            onSelectEvent: (e) => _openEventSheet(context, e),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: <Widget>[
                FilterChip(
                  label: const Text('All'),
                  selected: _accessFilter == null && !_onlyJoined,
                  onSelected: (_) => setState(() {
                    _accessFilter = null;
                    _onlyJoined = false;
                  }),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Joined'),
                  selected: _onlyJoined,
                  onSelected: (v) => setState(() => _onlyJoined = v),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Public'),
                  selected: _accessFilter == EventAccessType.public,
                  onSelected: (v) => setState(
                    () => _accessFilter = v ? EventAccessType.public : null,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Join Code'),
                  selected: _accessFilter == EventAccessType.joinCode,
                  onSelected: (v) => setState(
                    () => _accessFilter = v ? EventAccessType.joinCode : null,
                  ),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Invite Only'),
                  selected: _accessFilter == EventAccessType.inviteOnly,
                  onSelected: (v) => setState(
                    () => _accessFilter = v ? EventAccessType.inviteOnly : null,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'No active events match this filter in your area.',
                  style: TextStyle(color: Color(0xFF94A3B8)),
                ),
              ),
            )
          else
            ...filtered.map(
              (event) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _EventCard(
                  event: event,
                  currentLocation: c.currentLocation,
                  now: c.now,
                  isJoined: event.participantIds.contains(c.profile.id),
                  isHost: event.hostId == c.profile.id,
                  onTap: () => _openEventSheet(context, event),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _EventRadarOverview extends StatelessWidget {
  const _EventRadarOverview({
    required this.currentLocation,
    required this.events,
    required this.onSelectEvent,
  });

  final GeoPoint currentLocation;
  final List<ProximityEvent> events;
  final ValueChanged<ProximityEvent> onSelectEvent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: <Color>[Color(0xFF132238), Color(0xFF161F35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF283558)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.map_outlined,
                size: 16,
                color: AppTheme.pulseMint,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Local Area Map • ${currentLocation.areaName}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${events.length} active',
                style: const TextStyle(fontSize: 12, color: AppTheme.pulseMint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: events.map((e) {
              final dist = currentLocation.privacyDistanceLabelTo(e.location);
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelectEvent(e),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.darkCanvas.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppTheme.pulseMint.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(
                        Icons.place_outlined,
                        size: 14,
                        color: AppTheme.pulseMint,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${e.title} ($dist)',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _EventCard extends StatelessWidget {
  const _EventCard({
    required this.event,
    required this.currentLocation,
    required this.now,
    required this.isJoined,
    required this.isHost,
    required this.onTap,
  });

  final ProximityEvent event;
  final GeoPoint currentLocation;
  final DateTime now;
  final bool isJoined;
  final bool isHost;
  final VoidCallback onTap;

  String get _accessLabel {
    switch (event.accessType) {
      case EventAccessType.public:
        return 'Public';
      case EventAccessType.joinCode:
        return 'Join Code';
      case EventAccessType.inviteOnly:
        return 'Invite Only';
    }
  }

  IconData get _accessIcon {
    switch (event.accessType) {
      case EventAccessType.public:
        return Icons.public;
      case EventAccessType.joinCode:
        return Icons.password_outlined;
      case EventAccessType.inviteOnly:
        return Icons.lock_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final distanceLabel = currentLocation.privacyDistanceLabelTo(
      event.location,
    );
    final remainingLabel = formatRemainingTime(event.expiresAt, now);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.eventIndigo.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      event.categoryTag,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFA5B4FC),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.darkSurface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(
                          _accessIcon,
                          size: 12,
                          color: const Color(0xFFCBD5E1),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _accessLabel,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFFCBD5E1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.expiryAmber.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '⏳ $remainingLabel',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.expiryAmber,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                event.title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                event.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: Color(0xFF94A3B8),
                  height: 1.35,
                ),
              ),
              if (event.lastMovedNotice != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  '📍 ${event.lastMovedNotice}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppTheme.expiryAmber,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  const Icon(
                    Icons.place_outlined,
                    size: 14,
                    color: AppTheme.pulseMint,
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      '${event.location.areaName} • $distanceLabel • ${event.radiusMeters.round()}m zone',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFFCBD5E1),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isHost
                        ? 'Hosting (${event.participantIds.length})'
                        : isJoined
                        ? 'Joined (${event.participantIds.length})'
                        : '${event.participantIds.length} in event',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: isJoined || isHost
                          ? AppTheme.pulseMint
                          : const Color(0xFF94A3B8),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EventDetailSheet extends StatefulWidget {
  const _EventDetailSheet({required this.controller, required this.eventId});

  final AppController controller;
  final String eventId;

  @override
  State<_EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<_EventDetailSheet> {
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _chatController = TextEditingController();
  String? _joinError;

  @override
  void dispose() {
    _codeController.dispose();
    _chatController.dispose();
    super.dispose();
  }

  void _showEditDialog(BuildContext context, ProximityEvent event) {
    final titleCtrl = TextEditingController(text: event.title);
    final descCtrl = TextEditingController(text: event.description);
    double radius = event.radiusMeters;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              title: const Text('Edit Event Details'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(labelText: 'Title'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: descCtrl,
                    decoration: const InputDecoration(labelText: 'Description'),
                  ),
                  const SizedBox(height: 12),
                  Text('Discovery radius: ${radius.round()}m'),
                  Slider(
                    value: radius,
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    onChanged: (v) => setDialogState(() => radius = v),
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () {
                    widget.controller.updateEventDetails(
                      event.id,
                      title: titleCtrl.text,
                      description: descCtrl.text,
                      radiusMeters: radius,
                    );
                    Navigator.of(ctx).pop();
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final event = c.eventById(widget.eventId);
        if (event == null) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('This event has ended or expired.'),
            ),
          );
        }

        final isAuthorized = c.isAuthorizedForEvent(event.id);
        final isHost = event.hostId == c.profile.id;
        final messages = c.eventMessagesFor(event.id);

        return Padding(
          padding: EdgeInsets.only(
            left: 18,
            right: 18,
            top: 16,
            bottom: MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      event.title,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Text(
                '${event.location.areaName} • ${event.radiusMeters.round()}m discovery radius • Expires in ${formatRemainingTime(event.expiresAt, c.now)}',
                style: const TextStyle(fontSize: 12, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 6),
              Text(
                event.description,
                style: const TextStyle(fontSize: 13, color: Color(0xFFE2E8F0)),
              ),
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.ghostViolet.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: <Widget>[
                    Icon(
                      Icons.privacy_tip_outlined,
                      size: 16,
                      color: Color(0xFFC4B5FD),
                    ),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Attendance Privacy: Joining this event never makes you appear in general Nearby discovery.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Color(0xFFDDD6FE),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (isHost) ...<Widget>[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: <Widget>[
                    OutlinedButton.icon(
                      onPressed: () => _showEditDialog(context, event),
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                    ),
                    PopupMenuButton<GeoPoint>(
                      tooltip: 'Move Event Location',
                      onSelected: (newLoc) {
                        c.moveEventLocation(event.id, newLoc);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Moved event to ${newLoc.areaName}. Expiry & chat preserved.',
                            ),
                          ),
                        );
                      },
                      itemBuilder: (_) => AppController.presetLocations
                          .map(
                            (loc) => PopupMenuItem<GeoPoint>(
                              value: loc,
                              child: Text('Move to ${loc.areaName}'),
                            ),
                          )
                          .toList(),
                      child: IgnorePointer(
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(
                            Icons.edit_location_alt_outlined,
                            size: 16,
                          ),
                          label: const Text('Move Location'),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        c.endEvent(event.id);
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.stop_circle_outlined, size: 16),
                      label: const Text('End Event'),
                    ),
                  ],
                ),
              ],
              const Divider(height: 22),
              if (!isAuthorized) ...<Widget>[
                const Text(
                  'Join to unlock Event Chat',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                if (event.accessType == EventAccessType.joinCode) ...<Widget>[
                  TextField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Enter Event Join Code',
                      hintText: 'Ask host or check event board',
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                if (_joinError != null) ...<Widget>[
                  Text(
                    _joinError!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () {
                      final err = c.joinEvent(
                        event.id,
                        joinCode: _codeController.text,
                      );
                      setState(() => _joinError = err);
                    },
                    icon: const Icon(Icons.login),
                    label: Text(
                      event.accessType == EventAccessType.inviteOnly
                          ? 'Request / Verify Invite'
                          : 'Join Event',
                    ),
                  ),
                ),
              ] else ...<Widget>[
                Row(
                  children: <Widget>[
                    const Text(
                      'Dedicated Event Chat',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Spacer(),
                    if (!isHost)
                      TextButton(
                        onPressed: () => c.leaveEvent(event.id),
                        child: const Text('Leave Event'),
                      ),
                  ],
                ),
                Expanded(
                  child: messages.isEmpty
                      ? const Center(
                          child: Text(
                            'No messages yet. Say hi to attendees!',
                            style: TextStyle(color: Color(0xFF94A3B8)),
                          ),
                        )
                      : ListView.separated(
                          itemCount: messages.length,
                          separatorBuilder: (_, _) => const SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final m = messages[index];
                            if (m.isSystemNotice) {
                              return Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppTheme.expiryAmber.withValues(
                                    alpha: 0.14,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  '📍 ${m.body}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: AppTheme.expiryAmber,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              );
                            }
                            return Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.darkCard,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Text(
                                    m.senderDisplayName,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.pulseMint,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(m.body),
                                ],
                              ),
                            );
                          },
                        ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: TextField(
                        controller: _chatController,
                        decoration: const InputDecoration(
                          hintText: 'Message event participants...',
                          isDense: true,
                        ),
                        onSubmitted: (_) {
                          if (c.sendEventMessage(
                            event.id,
                            _chatController.text,
                          )) {
                            _chatController.clear();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () {
                        if (c.sendEventMessage(
                          event.id,
                          _chatController.text,
                        )) {
                          _chatController.clear();
                        }
                      },
                      icon: const Icon(Icons.send_rounded, size: 18),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class CreateEventScreen extends StatefulWidget {
  const CreateEventScreen({
    super.key,
    required this.controller,
    required this.onCreated,
  });

  final AppController controller;
  final VoidCallback onCreated;

  @override
  State<CreateEventScreen> createState() => _CreateEventScreenState();
}

class _CreateEventScreenState extends State<CreateEventScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(
    text: 'Campus Pop-Up',
  );
  final TextEditingController _joinCodeController = TextEditingController();

  late GeoPoint _selectedLocation;
  double _radiusMeters = 400;
  int _durationHours = 3;
  EventAccessType _accessType = EventAccessType.public;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.controller.currentLocation;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _joinCodeController.dispose();
    super.dispose();
  }

  void _submit() {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    if (title.isEmpty || desc.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter an event title and description.'),
        ),
      );
      return;
    }
    if (_accessType == EventAccessType.joinCode &&
        _joinCodeController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a join code for this event.'),
        ),
      );
      return;
    }

    widget.controller.createEvent(
      title: title,
      description: desc,
      categoryTag: _categoryController.text,
      location: _selectedLocation,
      radiusMeters: _radiusMeters,
      duration: Duration(hours: _durationHours),
      accessType: _accessType,
      rawJoinCode: _joinCodeController.text,
    );

    _titleController.clear();
    _descController.clear();
    _joinCodeController.clear();

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Temporary local event published!')),
    );
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Host Temporary Event')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Event Details',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'e.g., Sunset Chess & Matcha',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What is happening and where to spot the group',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category / Cover Label',
                      hintText: 'e.g., Board Games, Live Music, Study Sprint',
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
                    'Geography & Expiration',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<GeoPoint>(
                    initialValue: _selectedLocation,
                    decoration: const InputDecoration(
                      labelText: 'Event Location',
                    ),
                    items: AppController.presetLocations
                        .map(
                          (loc) => DropdownMenuItem<GeoPoint>(
                            value: loc,
                            child: Text(loc.areaName),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setState(() => _selectedLocation = v);
                    },
                  ),
                  const SizedBox(height: 14),
                  Text(
                    'Independent Discovery Radius: ${_radiusMeters.round()}m',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Slider(
                    value: _radiusMeters,
                    min: 100,
                    max: 2000,
                    divisions: 19,
                    label: '${_radiusMeters.round()}m',
                    onChanged: (v) => setState(() => _radiusMeters = v),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Duration (Auto-Expires)',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: <int>[1, 2, 4, 12, 24].map((hrs) {
                      return ChoiceChip(
                        label: Text('${hrs}h'),
                        selected: _durationHours == hrs,
                        onSelected: (_) => setState(() => _durationHours = hrs),
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
                    'Access Control',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  SegmentedButton<EventAccessType>(
                    segments: const <ButtonSegment<EventAccessType>>[
                      ButtonSegment<EventAccessType>(
                        value: EventAccessType.public,
                        label: Text('Public'),
                        icon: Icon(Icons.public, size: 16),
                      ),
                      ButtonSegment<EventAccessType>(
                        value: EventAccessType.joinCode,
                        label: Text('Join Code'),
                        icon: Icon(Icons.password, size: 16),
                      ),
                      ButtonSegment<EventAccessType>(
                        value: EventAccessType.inviteOnly,
                        label: Text('Invite Only'),
                        icon: Icon(Icons.lock_outline, size: 16),
                      ),
                    ],
                    selected: <EventAccessType>{_accessType},
                    onSelectionChanged: (s) =>
                        setState(() => _accessType = s.first),
                  ),
                  if (_accessType == EventAccessType.joinCode) ...<Widget>[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _joinCodeController,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Secret Join Code (stored hashed)',
                        hintText: 'Enter code required to join chat',
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: _submit,
            icon: const Icon(Icons.rocket_launch_outlined),
            label: const Padding(
              padding: EdgeInsets.symmetric(vertical: 14),
              child: Text('Launch Temporary Event'),
            ),
          ),
        ],
      ),
    );
  }
}
