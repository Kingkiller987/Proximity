import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/config/app_config.dart';
import '../../core/media/native_image_picker_helper.dart';
import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';
import '../map/proximity_map_view.dart';
import 'event_member_picker_sheet.dart';
import 'host_movement_dialog.dart';
import 'platform_date_time_picker.dart';

enum _ExploreDisplayMode { list, map }

class ExploreEventsScreen extends StatefulWidget {
  const ExploreEventsScreen({super.key, required this.controller, this.config});

  final AppController controller;
  final AppConfig? config;

  @override
  State<ExploreEventsScreen> createState() => _ExploreEventsScreenState();
}

class _ExploreEventsScreenState extends State<ExploreEventsScreen> {
  EventAccessType? _accessFilter;
  bool _onlyJoined = false;
  _ExploreDisplayMode _displayMode = _ExploreDisplayMode.map;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    if (_searchQuery != _searchController.text) {
      setState(() {
        _searchQuery = _searchController.text;
      });
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _openEventSheet(BuildContext context, ProximityEvent event) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.88,
        child: EventDetailSheet(
          controller: widget.controller,
          eventId: event.id,
        ),
      ),
    );
  }

  void _openLandmarkSheet(BuildContext context, LandmarkDiscovery landmark) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.52,
        child: LandmarkDetailSheet(
          landmark: landmark,
          controller: widget.controller,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final allEvents = c.discoverableEvents;
        final trimmedQuery = _searchQuery.trim().toLowerCase();
        final filtered = allEvents.where((e) {
          if (_onlyJoined && !e.isJoined) return false;
          if (_accessFilter != null && e.accessType != _accessFilter) {
            return false;
          }
          if (trimmedQuery.isNotEmpty) {
            final titleMatch = e.title.toLowerCase().contains(trimmedQuery);
            final descMatch = e.description.toLowerCase().contains(
              trimmedQuery,
            );
            final areaMatch = e.areaName.toLowerCase().contains(trimmedQuery);
            final venueAreaMatch =
                e.venuePoint?.areaName.toLowerCase().contains(trimmedQuery) ??
                false;
            if (!titleMatch && !descMatch && !areaMatch && !venueAreaMatch) {
              return false;
            }
          }
          return true;
        }).toList();

        Widget buildFilterMenu() {
          String currentLabel;
          if (_onlyJoined) {
            currentLabel = 'Joined';
          } else if (_accessFilter == EventAccessType.public) {
            currentLabel = 'Public';
          } else if (_accessFilter == EventAccessType.joinCode) {
            currentLabel = 'Join Code';
          } else if (_accessFilter == EventAccessType.inviteOnly) {
            currentLabel = 'Invite Only';
          } else {
            currentLabel = 'All';
          }

          return PopupMenuButton<String>(
            key: const Key('explore-filter-menu-btn'),
            initialValue: currentLabel,
            onSelected: (val) {
              setState(() {
                if (val == 'All') {
                  _accessFilter = null;
                  _onlyJoined = false;
                } else if (val == 'Joined') {
                  _accessFilter = null;
                  _onlyJoined = true;
                } else if (val == 'Public') {
                  _accessFilter = EventAccessType.public;
                  _onlyJoined = false;
                } else if (val == 'Join Code') {
                  _accessFilter = EventAccessType.joinCode;
                  _onlyJoined = false;
                } else if (val == 'Invite Only') {
                  _accessFilter = EventAccessType.inviteOnly;
                  _onlyJoined = false;
                }
              });
            },
            itemBuilder: (context) => const <PopupMenuEntry<String>>[
              PopupMenuItem<String>(value: 'All', child: Text('All')),
              PopupMenuItem<String>(value: 'Joined', child: Text('Joined')),
              PopupMenuItem<String>(value: 'Public', child: Text('Public')),
              PopupMenuItem<String>(
                value: 'Join Code',
                child: Text('Join Code'),
              ),
              PopupMenuItem<String>(
                value: 'Invite Only',
                child: Text('Invite Only'),
              ),
            ],
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 7),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Icon(
                    Icons.filter_list,
                    size: 14,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    'Filter: $currentLabel',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 1),
                  Icon(
                    Icons.arrow_drop_down,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          );
        }

        Widget buildSearchAndFilterRow() {
          return Row(
            children: <Widget>[
              Expanded(
                child: SizedBox(
                  height: 38,
                  child: TextField(
                    key: const Key('explore-event-search-field'),
                    controller: _searchController,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                    decoration: InputDecoration(
                      isDense: true,
                      hintText: 'Search events or areas...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        size: 16,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      prefixIconConstraints: const BoxConstraints(
                        minWidth: 26,
                        minHeight: 26,
                      ),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              key: const Key('explore-search-clear-btn'),
                              icon: Icon(
                                Icons.clear,
                                size: 14,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchController.clear();
                              },
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                              splashRadius: 14,
                            )
                          : null,
                      suffixIconConstraints: const BoxConstraints(
                        minWidth: 24,
                        minHeight: 24,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      filled: true,
                      fillColor: Theme.of(context)
                          .colorScheme
                          .surfaceContainerLow,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: AppTheme.pulseMint),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              buildFilterMenu(),
            ],
          );
        }

        Widget buildSegmentedSwitch() {
          return SegmentedButton<_ExploreDisplayMode>(
            segments: const <ButtonSegment<_ExploreDisplayMode>>[
              ButtonSegment<_ExploreDisplayMode>(
                value: _ExploreDisplayMode.list,
                label: Text('List'),
                icon: Icon(Icons.list_alt_outlined, size: 16),
              ),
              ButtonSegment<_ExploreDisplayMode>(
                value: _ExploreDisplayMode.map,
                label: Text('Map'),
                icon: Icon(Icons.map_outlined, size: 16),
              ),
            ],
            selected: <_ExploreDisplayMode>{_displayMode},
            onSelectionChanged: (s) => setState(() => _displayMode = s.first),
          );
        }

        Widget buildHostMovementBanner() {
          if (c.pendingHostMovementEventId == null) {
            return const SizedBox.shrink();
          }
          final eventId = c.pendingHostMovementEventId!;
          return Container(
            key: const Key('host-movement-banner'),
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.expiryAmber.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppTheme.expiryAmber.withValues(alpha: 0.6),
              ),
            ),
            child: Row(
              children: <Widget>[
                const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: AppTheme.expiryAmber,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You moved outside your hosted event boundary.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton(
                  key: const Key('host-movement-banner-action-btn'),
                  onPressed: () {
                    HostMovementDialog.show(
                      context,
                      controller: c,
                      eventId: eventId,
                    );
                  },
                  child: const Text('Options', style: TextStyle(fontSize: 12)),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 16),
                  onPressed: () {
                    c.dismissHostMovementPrompt(eventId);
                  },
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text('Explore Local Events'),
                Text(
                  'Around ${c.currentLocation.areaName}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          body: _displayMode == _ExploreDisplayMode.map
              ? Column(
                  children: <Widget>[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: Column(
                        children: <Widget>[
                          buildHostMovementBanner(),
                          if (c.eventAlerts.isNotEmpty) ...<Widget>[
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppTheme.expiryAmber.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: AppTheme.expiryAmber.withValues(
                                    alpha: 0.45,
                                  ),
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
                            const SizedBox(height: 8),
                          ],
                          SizedBox(
                            width: double.infinity,
                            child: buildSegmentedSwitch(),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ProximityMapView(
                        key: const Key('explore-expanded-map'),
                        controller: c,
                        config: widget.config,
                        events: filtered,
                        height: null,
                        onSelectEvent: (e) => _openEventSheet(context, e),
                        onSelectLandmarkDiscovery: (lm) =>
                            _openLandmarkSheet(context, lm),
                      ),
                    ),
                  ],
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  children: <Widget>[
                    buildHostMovementBanner(),
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
                    buildSegmentedSwitch(),
                    const SizedBox(height: 12),
                    _EventRadarOverview(
                      currentLocation: c.currentLocation,
                      events: filtered,
                      onSelectEvent: (e) => _openEventSheet(context, e),
                    ),
                    const SizedBox(height: 12),
                    buildSearchAndFilterRow(),
                    const SizedBox(height: 14),
                    if (filtered.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: Column(
                            children: <Widget>[
                              const Icon(
                                Icons.event_busy,
                                key: Key('explore-empty-events-icon'),
                                size: 40,
                                color: Color(0xFF64748B),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'No events found',
                                key: const Key('explore-empty-events-text'),
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurface,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'No active events match your search or filter in this area.',
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    else
                      ...filtered.map(
                        (event) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: _EventCard(
                            event: event,
                            now: c.now,
                            onTap: () => _openEventSheet(context, event),
                          ),
                        ),
                      ),
                  ],
                ),
        );
      },
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
        color:
            Theme.of(context).cardTheme.color ??
            Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
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
              return InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => onSelectEvent(e),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainer,
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
                      Flexible(
                        child: Text(
                          '${e.title} (${e.distanceLabel})',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
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
    required this.now,
    required this.onTap,
  });

  final ProximityEvent event;
  final DateTime now;
  final VoidCallback onTap;

  String get _accessLabel {
    switch (event.accessType) {
      case EventAccessType.public:
        return 'Public Access';
      case EventAccessType.joinCode:
        return 'Join Code Required';
      case EventAccessType.inviteOnly:
        return 'Invite Only Event';
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
    final distanceLabel = event.distanceLabel;
    final remainingLabel = formatRemainingTime(event.expiresAt, now);
    final lifecycleStatus = event.statusAt(now);
    Color statusBgColor;
    Color statusTextColor;
    String statusText;
    switch (lifecycleStatus) {
      case EventLifecycleStatus.scheduled:
        statusBgColor = const Color(0xFF0284C7).withValues(alpha: 0.2);
        statusTextColor = const Color(0xFF38BDF8);
        statusText = 'Scheduled';
        break;
      case EventLifecycleStatus.active:
        statusBgColor = AppTheme.pulseMint.withValues(alpha: 0.18);
        statusTextColor = AppTheme.pulseMint;
        statusText = 'Live';
        break;
      case EventLifecycleStatus.ended:
        statusBgColor = const Color(0xFF64748B).withValues(alpha: 0.2);
        statusTextColor = const Color(0xFF94A3B8);
        statusText = 'Ended';
        break;
      case EventLifecycleStatus.cancelled:
        statusBgColor = const Color(0xFFDC2626).withValues(alpha: 0.2);
        statusTextColor = const Color(0xFFF87171);
        statusText = 'Cancelled';
        break;
    }

    final attendanceText = event.isHost
        ? 'Hosting (${event.participantCount ?? 1})'
        : event.isJoined
        ? 'Joined (${event.participantCount ?? 1})'
        : event.participantCount != null
        ? '${event.participantCount} in event'
        : 'Attendance private';

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (event.posterBytes != null &&
                  event.posterBytes!.isNotEmpty) ...<Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.memory(
                    event.posterBytes!,
                    key: Key('event-thumbnail-${event.id}'),
                    width: 76,
                    height: 76,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
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
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: statusBgColor,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusTextColor,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainer,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              Icon(
                                _accessIcon,
                                size: 12,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _accessLabel,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
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
                            lifecycleStatus == EventLifecycleStatus.scheduled
                                ? '⏳ Starts soon'
                                : '⏳ $remainingLabel',
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
                    const SizedBox(height: 6),
                    Text(
                      '🗓 ${event.dateRangeLabel} • ${event.dailyHoursLabel}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
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
                            '${event.areaName} • $distanceLabel • ${event.radiusMeters.round()}m zone',
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFFCBD5E1),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          attendanceText,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: event.isJoined || event.isHost
                                ? AppTheme.pulseMint
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class EventDetailSheet extends StatefulWidget {
  const EventDetailSheet({
    super.key,
    required this.controller,
    required this.eventId,
  });

  final AppController controller;
  final String eventId;

  @override
  State<EventDetailSheet> createState() => _EventDetailSheetState();
}

class _EventDetailSheetState extends State<EventDetailSheet> {
  final TextEditingController _codeController = TextEditingController();
  String? _joinError;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  void _showHostTransferSheet(BuildContext context, ProximityEvent event) {
    EventMemberPickerSheet.show(
      context,
      controller: widget.controller,
      eventId: event.id,
      onTransferInitiated: (nomineeId, nomineeName) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Host invitation sent to $nomineeName.')),
        );
      },
    );
  }

  void _showRescheduleDialog(BuildContext context, ProximityEvent event) {
    final c = widget.controller;
    final existingSchedule = event.schedule;
    final now = c.now;
    final baseStart =
        existingSchedule?.startDate ?? DateTime(now.year, now.month, now.day);
    final baseEnd =
        existingSchedule?.endDate ?? baseStart.add(const Duration(days: 1));
    final openMinutes = existingSchedule?.defaultOpenMinutes ?? 10 * 60;
    final closeMinutes = existingSchedule?.defaultCloseMinutes ?? 18 * 60;
    final venueTz =
        event.schedule?.venueTimezone ??
        event.venuePoint?.timezone ??
        'America/New_York';

    DateTime selStart = baseStart;
    DateTime selEnd = baseEnd;
    TimeOfDay selOpen = TimeOfDay(
      hour: openMinutes ~/ 60,
      minute: openMinutes % 60,
    );
    TimeOfDay selClose = TimeOfDay(
      hour: closeMinutes ~/ 60,
      minute: closeMinutes % 60,
    );
    String? dialogError;

    showDialog<void>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final isOvernight =
                (selClose.hour * 60 + selClose.minute) <=
                (selOpen.hour * 60 + selOpen.minute);
            final candidate = EventSchedule(
              startDate: selStart,
              endDate: selEnd,
              venueTimezone: venueTz,
              defaultOpenMinutes: selOpen.hour * 60 + selOpen.minute,
              defaultCloseMinutes: selClose.hour * 60 + selClose.minute,
            );
            final inPast = candidate.isStartInPast(c.now);

            return AlertDialog(
              title: const Text('Reschedule Event'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Venue Timezone: $venueTz',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      dense: true,
                      title: const Text('Start Date'),
                      subtitle: Text(
                        DateFormat('EEE, MMM d, yyyy').format(selStart),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      onTap: () async {
                        final picked =
                            await PlatformDateTimePicker.showPlatformDatePicker(
                              context,
                              initialDate: selStart,
                              firstDate: DateTime(now.year, now.month, now.day),
                              lastDate: selStart.add(const Duration(days: 365)),
                            );
                        if (picked != null) {
                          setDialogState(() {
                            selStart = picked;
                            if (selEnd.isBefore(selStart)) selEnd = selStart;
                          });
                        }
                      },
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('End Date'),
                      subtitle: Text(
                        DateFormat('EEE, MMM d, yyyy').format(selEnd),
                      ),
                      trailing: const Icon(
                        Icons.calendar_today_outlined,
                        size: 18,
                      ),
                      onTap: () async {
                        final picked =
                            await PlatformDateTimePicker.showPlatformDatePicker(
                              context,
                              initialDate: selEnd.isBefore(selStart)
                                  ? selStart
                                  : selEnd,
                              firstDate: selStart,
                              lastDate: selStart.add(const Duration(days: 365)),
                            );
                        if (picked != null) {
                          setDialogState(() => selEnd = picked);
                        }
                      },
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('Start Time'),
                      subtitle: Text(selOpen.format(context)),
                      trailing: const Icon(Icons.schedule_outlined, size: 18),
                      onTap: () async {
                        final picked =
                            await PlatformDateTimePicker.showPlatformTimePicker(
                              context,
                              initialTime: selOpen,
                            );
                        if (picked != null) {
                          setDialogState(() => selOpen = picked);
                        }
                      },
                    ),
                    ListTile(
                      dense: true,
                      title: const Text('End Time'),
                      subtitle: Text(selClose.format(context)),
                      trailing: const Icon(Icons.schedule_outlined, size: 18),
                      onTap: () async {
                        final picked =
                            await PlatformDateTimePicker.showPlatformTimePicker(
                              context,
                              initialTime: selClose,
                            );
                        if (picked != null) {
                          setDialogState(() => selClose = picked);
                        }
                      },
                    ),
                    if (isOvernight) ...<Widget>[
                      const SizedBox(height: 6),
                      const Text(
                        '🌙 Overnight Schedule (+1d)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.expiryAmber,
                        ),
                      ),
                    ],
                    if (inPast) ...<Widget>[
                      const SizedBox(height: 8),
                      const Text(
                        '⚠️ Start time is in the past. Please choose a future date/time.',
                        style: TextStyle(fontSize: 12, color: Colors.redAccent),
                      ),
                    ],
                    if (dialogError != null) ...<Widget>[
                      const SizedBox(height: 8),
                      Text(
                        dialogError!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: inPast
                      ? null
                      : () {
                          final err = candidate.validateScheduleAgainst(
                            now: c.now,
                          );
                          if (err != null) {
                            setDialogState(() => dialogError = err);
                            return;
                          }
                          c.rescheduleEvent(event.id, candidate);
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Event rescheduled successfully.'),
                            ),
                          );
                        },
                  child: const Text('Save Schedule'),
                ),
              ],
            );
          },
        );
      },
    );
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
        final status = event.statusAt(c.now);

        Color statusBg;
        Color statusColor;
        String statusLabel;
        switch (status) {
          case EventLifecycleStatus.scheduled:
            statusBg = const Color(0xFF0284C7).withValues(alpha: 0.2);
            statusColor = const Color(0xFF38BDF8);
            statusLabel = 'Scheduled';
            break;
          case EventLifecycleStatus.active:
            statusBg = AppTheme.pulseMint.withValues(alpha: 0.18);
            statusColor = AppTheme.pulseMint;
            statusLabel = 'Live';
            break;
          case EventLifecycleStatus.ended:
            statusBg = const Color(0xFF64748B).withValues(alpha: 0.2);
            statusColor = const Color(0xFF94A3B8);
            statusLabel = 'Ended';
            break;
          case EventLifecycleStatus.cancelled:
            statusBg = const Color(0xFFDC2626).withValues(alpha: 0.2);
            statusColor = const Color(0xFFF87171);
            statusLabel = 'Cancelled';
            break;
        }

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
                    child: Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            event.title,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            statusLabel,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: statusColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    key: const Key('share-event-btn'),
                    tooltip: 'Share Event',
                    icon: const Icon(Icons.share_outlined),
                    onPressed: () async {
                      final box = context.findRenderObject() as RenderBox?;
                      final originRect = box != null
                          ? box.localToGlobal(Offset.zero) & box.size
                          : null;
                      final inviteLink = 'proximity://event/${event.id}';
                      await SharePlus.instance.share(
                        ShareParams(
                          text:
                              'Join "${event.title}" on Proximity: $inviteLink',
                          subject: event.title,
                          sharePositionOrigin: originRect,
                        ),
                      );
                    },
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Expanded(
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: <Widget>[
                    if (event.posterBytes != null) ...<Widget>[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.memory(
                          event.posterBytes!,
                          key: const Key('event-detail-poster-image'),
                          height: 180,
                          width: double.infinity,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    Text(
                      '${event.areaName} • ${event.distanceLabel} • ${event.radiusMeters.round()}m discovery radius • ${status == EventLifecycleStatus.scheduled ? "Starts soon" : "Expires in ${formatRemainingTime(event.expiresAt, c.now)}"}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Schedule: ${event.dateRangeLabel} • ${event.dailyHoursLabel}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.pulseMint,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      event.description,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFFE2E8F0),
                      ),
                    ),
                    if (event.pendingHostTransferUserId ==
                        c.profile.id) ...<Widget>[
                      const SizedBox(height: 10),
                      Container(
                        key: const Key('pending-host-transfer-banner'),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.eventIndigo.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppTheme.eventIndigo),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            const Row(
                              children: <Widget>[
                                Icon(
                                  Icons.stars,
                                  color: Color(0xFFA5B4FC),
                                  size: 18,
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Host Ownership Transfer Offered',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFA5B4FC),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'You have been nominated to take over as host. Accepting independently verifies your venue location.',
                              style: TextStyle(fontSize: 12),
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: <Widget>[
                                FilledButton(
                                  key: const Key('accept-host-transfer-btn'),
                                  onPressed: () async {
                                    if (c.profile.isAnonymous) {
                                      final confirmed = await showDialog<bool>(
                                        context: context,
                                        builder: (dialogCtx) => AlertDialog(
                                          key: const Key(
                                            'anonymous-host-transfer-confirm-dialog',
                                          ),
                                          title: const Text(
                                            'Accept Event Ownership?',
                                          ),
                                          content: Text(
                                            'Your public profile (@${c.profile.username}) will be visible as the host of this event. Your anonymous setting for Nearby chats will not be changed.',
                                          ),
                                          actions: <Widget>[
                                            TextButton(
                                              key: const Key(
                                                'cancel-host-transfer-btn',
                                              ),
                                              onPressed: () =>
                                                  Navigator.of(dialogCtx)
                                                      .pop(false),
                                              child: const Text('Cancel'),
                                            ),
                                            ElevatedButton(
                                              key: const Key(
                                                'confirm-host-transfer-btn',
                                              ),
                                              onPressed: () =>
                                                  Navigator.of(dialogCtx)
                                                      .pop(true),
                                              child: const Text(
                                                'Confirm & Accept',
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                      if (confirmed != true) return;
                                    }
                                    final err = c.acceptEventHostTransfer(
                                      event.id,
                                    );
                                    if (err != null) {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            SnackBar(
                                              content: Text(err),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                    } else {
                                      if (!context.mounted) return;
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'You are now the host of ${event.title}!',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  child: const Text('Accept Host Role'),
                                ),
                                OutlinedButton(
                                  key: const Key('decline-host-transfer-btn'),
                                  onPressed: () {
                                    c.cancelOrRejectEventHostTransfer(event.id);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Host transfer declined.',
                                        ),
                                      ),
                                    );
                                  },
                                  child: const Text('Decline'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (isHost) ...<Widget>[
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          if (status == EventLifecycleStatus.scheduled)
                            FilledButton.icon(
                              key: const Key('start-event-btn'),
                              onPressed: () {
                                final err = c.startEvent(event.id);
                                if (err != null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(err),
                                      backgroundColor: Colors.redAccent,
                                    ),
                                  );
                                } else {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        '${event.title} is now active for attendees!',
                                      ),
                                    ),
                                  );
                                }
                              },
                              icon: const Icon(Icons.play_arrow_rounded),
                              label: const Text(
                                'Start Event (Verify Location)',
                              ),
                            ),
                          OutlinedButton.icon(
                            key: const Key('transfer-host-btn'),
                            onPressed: () {
                              if (event.pendingHostTransferUserId != null) {
                                c.cancelOrRejectEventHostTransfer(event.id);
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Host transfer cancelled.'),
                                  ),
                                );
                              } else {
                                _showHostTransferSheet(context, event);
                              }
                            },
                            icon: Icon(
                              event.pendingHostTransferUserId != null
                                  ? Icons.person_remove_outlined
                                  : Icons.person_add_alt_1_outlined,
                              size: 16,
                            ),
                            label: Text(
                              event.pendingHostTransferUserId != null
                                  ? 'Cancel Transfer'
                                  : 'Transfer Host',
                            ),
                          ),
                          OutlinedButton.icon(
                            key: const Key('reschedule-event-btn'),
                            onPressed: () =>
                                _showRescheduleDialog(context, event),
                            icon: const Icon(
                              Icons.event_repeat_outlined,
                              size: 16,
                            ),
                            label: const Text('Reschedule'),
                          ),
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
                              c.cancelEvent(event.id);
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.cancel_outlined, size: 16),
                            label: const Text('Cancel Event'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () {
                              c.endEvent(event.id);
                              Navigator.of(context).pop();
                            },
                            icon: const Icon(
                              Icons.stop_circle_outlined,
                              size: 16,
                            ),
                            label: const Text('End Event'),
                          ),
                        ],
                      ),
                    ],
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
                    const Divider(height: 22),
                    if (!isAuthorized) ...<Widget>[
                      const Text(
                        'Join to unlock Event Chat',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      if (event.accessType ==
                          EventAccessType.joinCode) ...<Widget>[
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
                          const Expanded(
                            child: Text(
                              'Dedicated Event Chat',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton(
                            key: const Key('leave-event-btn'),
                            onPressed: () {
                              final err = c.leaveEvent(event.id);
                              if (err != null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(err),
                                    backgroundColor: Colors.redAccent,
                                  ),
                                );
                              } else {
                                Navigator.of(context).pop();
                              }
                            },
                            child: const Text('Leave Event'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          key: const Key('open-chat-in-nearby-btn'),
                          onPressed: () {
                            c.navigateToNearbyEvent(event.id);
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.forum_outlined, size: 18),
                          label: const Text('Open Chat in Nearby'),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
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

enum EventLocationMode { hostCurrent, specificPlace, areaWide }

class _CreateEventScreenState extends State<CreateEventScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController(
    text: 'Campus Pop-Up',
  );
  final TextEditingController _joinCodeController = TextEditingController();
  final TextEditingController _placeNameController = TextEditingController();
  final TextEditingController _areaNameController = TextEditingController();

  Uint8List? _posterBytes;
  EventLocationMode _locationMode = EventLocationMode.specificPlace;
  late GeoPoint _selectedReferenceLocation;
  double _radiusMeters = 400;

  late DateTime _startDate;
  late DateTime _endDate;
  TimeOfDay _startTime = const TimeOfDay(hour: 10, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 18, minute: 0);
  EventAccessType _accessType = EventAccessType.public;

  @override
  void initState() {
    super.initState();
    final curr = widget.controller.currentLocation;
    _selectedReferenceLocation =
        AppController.presetLocations.any((p) => p == curr)
        ? curr
        : AppController.presetLocations.first;
    if (widget.controller.hasFreshAccurateLocation) {
      _locationMode = EventLocationMode.hostCurrent;
    }
    final now = widget.controller.now;
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate;
    _startTime = TimeOfDay(hour: (now.hour + 1) % 24, minute: 0);
    final closeHour = (now.hour + 4) % 24;
    _endTime = TimeOfDay(hour: closeHour, minute: 0);
    if (now.hour + 4 >= 24) {
      _endDate = _startDate.add(const Duration(days: 1));
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _categoryController.dispose();
    _joinCodeController.dispose();
    _placeNameController.dispose();
    _areaNameController.dispose();
    super.dispose();
  }

  Future<void> _pickPoster() async {
    final result = await NativeImagePickerHelper().promptAndPickSanitizedImage(
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
    if (result.sanitizedBytes != null && mounted) {
      setState(() => _posterBytes = result.sanitizedBytes);
    }
  }

  GeoPoint _buildSelectedLocation() {
    switch (_locationMode) {
      case EventLocationMode.hostCurrent:
        final curr = widget.controller.currentLocation;
        return GeoPoint(
          latitude: curr.latitude,
          longitude: curr.longitude,
          areaName: curr.areaName,
        );
      case EventLocationMode.specificPlace:
        final name = _placeNameController.text.trim();
        return GeoPoint(
          latitude: _selectedReferenceLocation.latitude,
          longitude: _selectedReferenceLocation.longitude,
          areaName: name.isNotEmpty
              ? name
              : _selectedReferenceLocation.areaName,
        );
      case EventLocationMode.areaWide:
        final area = _areaNameController.text.trim();
        return GeoPoint(
          latitude: _selectedReferenceLocation.latitude,
          longitude: _selectedReferenceLocation.longitude,
          areaName: area.isNotEmpty
              ? area
              : '${_selectedReferenceLocation.areaName} Area',
        );
    }
  }

  EventSchedule _buildCandidateSchedule() {
    final now = widget.controller.now;
    final today = DateTime(now.year, now.month, now.day);
    final effectiveStart = today; // Lock Start Date strictly to today
    final effectiveEnd = _endDate.isBefore(effectiveStart)
        ? effectiveStart
        : _endDate;
    final loc = _buildSelectedLocation();

    return EventSchedule(
      venueTimezone: loc.timezone,
      startDate: effectiveStart,
      endDate: effectiveEnd,
      defaultOpenMinutes: _startTime.hour * 60 + _startTime.minute,
      defaultCloseMinutes: _endTime.hour * 60 + _endTime.minute,
    );
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

    if (_locationMode == EventLocationMode.hostCurrent &&
        !widget.controller.hasFreshAccurateLocation) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot create event at current location without a fresh, accurate GPS fix.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final schedule = _buildCandidateSchedule();
    final schedErr = schedule.validateScheduleAgainst(
      now: widget.controller.now,
    );
    if (schedErr != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(schedErr), backgroundColor: Colors.redAccent),
      );
      return;
    }

    if (schedule.endDate.isAtSameMomentAs(schedule.startDate) &&
        schedule.defaultCloseMinutes <= schedule.defaultOpenMinutes) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'End Time must be after Start Time for same-day events. For overnight events, set End Date to tomorrow.',
          ),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    final eventLocation = _buildSelectedLocation();
    try {
      widget.controller.createEvent(
        title: title,
        description: desc,
        categoryTag: _categoryController.text,
        location: eventLocation,
        radiusMeters: _radiusMeters,
        duration: schedule.expiresAtInstant.difference(
          schedule.startsAtInstant,
        ),
        accessType: _accessType,
        rawJoinCode: _joinCodeController.text,
        schedule: schedule,
        posterBytes: _posterBytes,
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString().replaceFirst('ArgumentError: ', '')),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    _titleController.clear();
    _descController.clear();
    _joinCodeController.clear();
    _placeNameController.clear();
    _areaNameController.clear();
    setState(() => _posterBytes = null);

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Temporary local event published!')),
    );
    widget.onCreated();
  }

  @override
  Widget build(BuildContext context) {
    final now = widget.controller.now;
    final candidateSchedule = _buildCandidateSchedule();
    final isOvernight =
        (_endTime.hour * 60 + _endTime.minute) <=
        (_startTime.hour * 60 + _startTime.minute);
    final inPast = candidateSchedule.isStartInPast(now);
    final selectedLocation = _buildSelectedLocation();

    return Scaffold(
      appBar: AppBar(title: const Text('Host Temporary Event')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (widget.controller.profile.isAnonymous) ...<Widget>[
            Container(
              key: const Key('anonymous-hosting-warning-banner'),
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.ghostViolet.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.ghostViolet.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                children: <Widget>[
                  const Icon(
                    Icons.visibility_outlined,
                    size: 20,
                    color: AppTheme.ghostViolet,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'You are currently in Anonymous Mode for Nearby chats. If you create this event, your public profile (@${widget.controller.profile.username}) will be shown as the host.',
                      style: const TextStyle(fontSize: 12, height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
                    key: const Key('create-event-title-field'),
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Event Title',
                      hintText: 'e.g., Sunset Chess & Matcha',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('create-event-desc-field'),
                    controller: _descController,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                      hintText: 'What is happening and where to spot the group',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    key: const Key('create-event-category-field'),
                    controller: _categoryController,
                    decoration: const InputDecoration(
                      labelText: 'Category / Cover Label',
                      hintText: 'e.g., Board Games, Live Music, Study Sprint',
                    ),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Event Poster (Optional)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
                  if (_posterBytes != null) ...<Widget>[
                    Stack(
                      children: <Widget>[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.memory(
                            _posterBytes!,
                            height: 140,
                            width: double.infinity,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 6,
                          right: 6,
                          child: CircleAvatar(
                            radius: 16,
                            backgroundColor: Colors.black54,
                            child: IconButton(
                              padding: EdgeInsets.zero,
                              icon: const Icon(
                                Icons.close,
                                size: 18,
                                color: Colors.white,
                              ),
                              onPressed: () =>
                                  setState(() => _posterBytes = null),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...<Widget>[
                    OutlinedButton.icon(
                      onPressed: _pickPoster,
                      icon: const Icon(Icons.image_outlined, size: 18),
                      label: const Text('Add Event Poster (Max 5MB)'),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Section 1: Independent Location Configuration
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text(
                    'Event Location',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      ChoiceChip(
                        key: const Key('location-mode-current'),
                        avatar: const Icon(Icons.my_location, size: 16),
                        label: const Text("Host's Location"),
                        selected:
                            _locationMode == EventLocationMode.hostCurrent,
                        onSelected: (_) => setState(
                          () => _locationMode = EventLocationMode.hostCurrent,
                        ),
                      ),
                      ChoiceChip(
                        key: const Key('location-mode-place'),
                        avatar: const Icon(Icons.place_outlined, size: 16),
                        label: const Text('Specific Place'),
                        selected:
                            _locationMode == EventLocationMode.specificPlace,
                        onSelected: (_) => setState(
                          () => _locationMode = EventLocationMode.specificPlace,
                        ),
                      ),
                      ChoiceChip(
                        key: const Key('location-mode-area'),
                        avatar: const Icon(Icons.map_outlined, size: 16),
                        label: const Text('Area-Wide'),
                        selected: _locationMode == EventLocationMode.areaWide,
                        onSelected: (_) => setState(
                          () => _locationMode = EventLocationMode.areaWide,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_locationMode ==
                      EventLocationMode.hostCurrent) ...<Widget>[
                    if (!widget.controller.hasFreshAccurateLocation)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.redAccent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.redAccent),
                        ),
                        child: Text(
                          '⚠️ Cannot use current location: '
                          '${!widget.controller.hasLocationAccess ? "Location permissions not granted." : (widget.controller.latestLocationFix?.accuracyMeters != null && widget.controller.latestLocationFix!.accuracyMeters > 50 ? "GPS accuracy is insufficient (${widget.controller.latestLocationFix!.accuracyMeters.round()}m > 50m)." : "GPS location fix is stale (> 30s old).")}\n'
                          'Please wait for a fresh GPS fix or select "Specific Place".',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.redAccent,
                          ),
                        ),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.pulseMint.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppTheme.pulseMint.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              '📍 Host Position: ${widget.controller.currentLocation.areaName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Coordinates: ${widget.controller.currentLocation.latitude.toStringAsFixed(4)}, ${widget.controller.currentLocation.longitude.toStringAsFixed(4)}\n'
                              'Saved independently as event coordinates. Host movement will not auto-relocate event.',
                              style: TextStyle(
                                fontSize: 11,
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ] else if (_locationMode ==
                      EventLocationMode.specificPlace) ...<Widget>[
                    TextField(
                      key: const Key('create-event-place-name-field'),
                      controller: _placeNameController,
                      decoration: const InputDecoration(
                        labelText: 'Specific Place / Meeting Point',
                        hintText:
                            'e.g. Student Center Room 302, Fountain Steps',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<GeoPoint>(
                      initialValue: _selectedReferenceLocation,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Reference Landmark / Area Coordinates',
                        isDense: true,
                      ),
                      items: AppController.presetLocations
                          .map(
                            (loc) => DropdownMenuItem<GeoPoint>(
                              value: loc,
                              child: Text(
                                loc.areaName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedReferenceLocation = v);
                        }
                      },
                    ),
                  ] else ...<Widget>[
                    TextField(
                      key: const Key('create-event-area-name-field'),
                      controller: _areaNameController,
                      decoration: const InputDecoration(
                        labelText: 'Broader Area / Neighborhood Name',
                        hintText: 'e.g. West Campus & Residential Quads',
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<GeoPoint>(
                      initialValue: _selectedReferenceLocation,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Center Reference Point',
                        isDense: true,
                      ),
                      items: AppController.presetLocations
                          .map(
                            (loc) => DropdownMenuItem<GeoPoint>(
                              value: loc,
                              child: Text(
                                loc.areaName,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _selectedReferenceLocation = v);
                        }
                      },
                    ),
                  ],
                  const SizedBox(height: 14),
                  Text(
                    'Discovery Radius: ${_radiusMeters.round()}m',
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
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Section 6: Simplified Event Scheduling
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'Event Schedule (${selectedLocation.timezone})',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  // Start Date (Locked to today)
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                    ),
                    title: const Text('Start Date'),
                    subtitle: Text(
                      '${DateFormat('EEE, MMM d, yyyy').format(_startDate)} (Today - Fixed)',
                    ),
                    trailing: const Tooltip(
                      message: 'Start Date is fixed to today',
                      child: Icon(Icons.lock_outline, size: 16),
                    ),
                  ),
                  // Start Time
                  ListTile(
                    key: const Key('create-event-start-time-tile'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined, size: 18),
                    title: const Text('Start Time'),
                    subtitle: Text(_startTime.format(context)),
                    trailing: const Text(
                      'Change',
                      style: TextStyle(color: AppTheme.pulseMint, fontSize: 12),
                    ),
                    onTap: () async {
                      final picked =
                          await PlatformDateTimePicker.showPlatformTimePicker(
                            context,
                            initialTime: _startTime,
                          );
                      if (picked != null) {
                        setState(() => _startTime = picked);
                      }
                    },
                  ),
                  // End Date (Selectable >= Start Date)
                  ListTile(
                    key: const Key('create-event-end-date-tile'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                    ),
                    title: const Text('End Date'),
                    subtitle: Text(
                      DateFormat('EEE, MMM d, yyyy').format(_endDate),
                    ),
                    trailing: const Text(
                      'Change',
                      style: TextStyle(color: AppTheme.pulseMint, fontSize: 12),
                    ),
                    onTap: () async {
                      final picked =
                          await PlatformDateTimePicker.showPlatformDatePicker(
                            context,
                            initialDate: _endDate.isBefore(_startDate)
                                ? _startDate
                                : _endDate,
                            firstDate: _startDate,
                            lastDate: _startDate.add(const Duration(days: 365)),
                          );
                      if (picked != null) {
                        setState(() => _endDate = picked);
                      }
                    },
                  ),
                  // End Time
                  ListTile(
                    key: const Key('create-event-end-time-tile'),
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_outlined, size: 18),
                    title: const Text('End Time'),
                    subtitle: Text(_endTime.format(context)),
                    trailing: const Text(
                      'Change',
                      style: TextStyle(color: AppTheme.pulseMint, fontSize: 12),
                    ),
                    onTap: () async {
                      final picked =
                          await PlatformDateTimePicker.showPlatformTimePicker(
                            context,
                            initialTime: _endTime,
                          );
                      if (picked != null) {
                        setState(() => _endTime = picked);
                      }
                    },
                  ),
                  if (_endDate.isAfter(_startDate) || isOvernight) ...<Widget>[
                    const SizedBox(height: 6),
                    Text(
                      '🌙 Overnight or Multi-Day Event: Schedule continues through ${DateFormat('EEE, MMM d').format(_endDate)} at ${_endTime.format(context)}.',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.expiryAmber,
                      ),
                    ),
                  ],
                  if (inPast) ...<Widget>[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.redAccent.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.redAccent),
                      ),
                      child: Text(
                        '⚠️ Scheduled start time is in the past (${selectedLocation.timezone}). Please pick a future start time.',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.redAccent,
                        ),
                      ),
                    ),
                  ],
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
                  LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth < 360) {
                        return Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: <Widget>[
                            ChoiceChip(
                              avatar: const Icon(Icons.public, size: 16),
                              label: const Text('Public'),
                              selected: _accessType == EventAccessType.public,
                              onSelected: (_) => setState(
                                () => _accessType = EventAccessType.public,
                              ),
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.password, size: 16),
                              label: const Text('Join Code'),
                              selected: _accessType == EventAccessType.joinCode,
                              onSelected: (_) => setState(
                                () => _accessType = EventAccessType.joinCode,
                              ),
                            ),
                            ChoiceChip(
                              avatar: const Icon(Icons.lock_outline, size: 16),
                              label: const Text('Invite Only'),
                              selected:
                                  _accessType == EventAccessType.inviteOnly,
                              onSelected: (_) => setState(
                                () => _accessType = EventAccessType.inviteOnly,
                              ),
                            ),
                          ],
                        );
                      }
                      return SegmentedButton<EventAccessType>(
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
                      );
                    },
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
            key: const Key('launch-temporary-event-btn'),
            onPressed: inPast ? null : _submit,
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

class LandmarkDetailSheet extends StatelessWidget {
  const LandmarkDetailSheet({
    super.key,
    required this.landmark,
    this.controller,
    this.onOpenChat,
  });

  final LandmarkDiscovery landmark;
  final AppController? controller;
  final VoidCallback? onOpenChat;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  landmark.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.pulseMint.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppTheme.pulseMint.withValues(alpha: 0.5),
                  ),
                ),
                child: Text(
                  landmark.category.label,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.pulseMint,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Area: ${landmark.areaName} • ${landmark.distanceMeters.round()}m away',
            style: TextStyle(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Row(
              children: <Widget>[
                Icon(
                  landmark.isEligible
                      ? Icons.check_circle_outline
                      : Icons.info_outline,
                  color: landmark.isEligible
                      ? AppTheme.pulseMint
                      : const Color(0xFF94A3B8),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    landmark.isEligible
                        ? 'You are within this landmark\'s ${landmark.radiusMeters.round()}m chat radius.'
                        : 'Outside the ${landmark.radiusMeters.round()}m chat radius for this landmark.',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (landmark.isEligible)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                key: const Key('open-landmark-chat-in-nearby-btn'),
                onPressed: () {
                  Navigator.of(context).pop();
                  if (controller != null) {
                    controller!.navigateToNearbyLandmark(landmark.id);
                  }
                  onOpenChat?.call();
                },
                icon: const Icon(Icons.forum_outlined, size: 18),
                label: const Text('Open Chat in Nearby'),
              ),
            ),
        ],
      ),
    );
  }
}
