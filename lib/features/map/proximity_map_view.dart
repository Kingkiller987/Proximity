import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/config/app_config.dart';
import '../../core/models/models.dart';
import '../../core/state/app_controller.dart';
import '../../core/theme/app_theme.dart';

class ProximityMapView extends StatefulWidget {
  const ProximityMapView({
    super.key,
    required this.controller,
    this.config,
    this.events,
    this.onSelectLandmark,
    this.onSelectLandmarkDiscovery,
    this.onSelectEvent,
    this.height,
  });

  final AppController controller;
  final AppConfig? config;
  final List<ProximityEvent>? events;
  final ValueChanged<LandmarkChat>? onSelectLandmark;
  final ValueChanged<LandmarkDiscovery>? onSelectLandmarkDiscovery;
  final ValueChanged<ProximityEvent>? onSelectEvent;
  final double? height;

  @override
  State<ProximityMapView> createState() => _ProximityMapViewState();
}

class _ProximityMapViewState extends State<ProximityMapView> {
  final MapController _mapController = MapController();
  GeoPoint? _lastCenteredLocation;

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  Widget _buildUserAvatarMarker(AppController controller, GeoPoint userLoc) {
    final avatarBytes = controller.profile.avatarBytes;
    final hasAvatar = avatarBytes != null && avatarBytes.isNotEmpty;

    Widget defaultSilhouette() {
      return Container(
        width: 34,
        height: 34,
        decoration: const BoxDecoration(
          color: AppTheme.pulseMint,
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.person,
          key: Key('map-marker-default-avatar-icon'),
          size: 20,
          color: AppTheme.darkCanvas,
        ),
      );
    }

    return Tooltip(
      key: const Key('map-marker-user-avatar'),
      message: 'You (${userLoc.areaName})',
      child: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: AppTheme.pulseMint.withValues(alpha: 0.65),
              blurRadius: 8,
              spreadRadius: 2,
            ),
          ],
        ),
        child: ClipOval(
          child: hasAvatar
              ? Image.memory(
                  avatarBytes,
                  key: const Key('map-marker-avatar-image'),
                  width: 34,
                  height: 34,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      defaultSilhouette(),
                )
              : defaultSilhouette(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final config = widget.config;
        if (!controller.hasFreshAccurateLocation) {
          return Container(
            height: widget.height,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
            child: Text(
              'Fresh, accurate location required to view interactive map.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        final userLoc = controller.currentLocation;
        final userLatLng = LatLng(userLoc.latitude, userLoc.longitude);
        if (_lastCenteredLocation != null && _lastCenteredLocation != userLoc) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              _mapController.move(userLatLng, 15.6);
            }
          });
        }
        _lastCenteredLocation = userLoc;

        final activeLandmarks = controller.activeLandmarkChats;
        final visibleEvents = widget.events ?? controller.discoverableEvents;
        final isTestEnv = config?.environment == 'test';

        return Container(
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: <Widget>[
              FlutterMap(
                key: const Key('proximity-flutter-map'),
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: userLatLng,
                  initialZoom: 15.6,
                  minZoom: 11.0,
                  maxZoom: 18.5,
                ),
                children: <Widget>[
                  if (!isTestEnv &&
                      (config == null ||
                          config.isTileProviderValidForEnvironment))
                    TileLayer(
                      urlTemplate:
                          config?.mapTileUrlTemplate ??
                          AppConfig.defaultDevTileUrlTemplate,
                      userAgentPackageName:
                          config?.mapUserAgentPackageName ??
                          'com.proximity.app',
                    ),
                  CircleLayer(
                    circles: <CircleMarker>[
                      // Discoverable landmark radius circles (active in mint, inactive in muted)
                      for (final lm in controller.discoverableLandmarks)
                        CircleMarker(
                          point: LatLng(
                            lm.center.latitude,
                            lm.center.longitude,
                          ),
                          radius: lm.radiusMeters,
                          useRadiusInMeter: true,
                          color: lm.isEligible
                              ? AppTheme.pulseMint.withValues(alpha: 0.14)
                              : const Color(0xFF64748B).withValues(alpha: 0.08),
                          borderColor: lm.isEligible
                              ? AppTheme.pulseMint.withValues(alpha: 0.65)
                              : const Color(0xFF64748B).withValues(alpha: 0.3),
                          borderStrokeWidth: lm.isEligible ? 2 : 1,
                        ),
                    ],
                  ),
                  MarkerLayer(
                    markers: <Marker>[
                      // Eligible Event pins (distinct from Landmark pins, anchored bottom-center)
                      for (final ev in visibleEvents)
                        if (ev.venuePoint != null)
                          Marker(
                            point: LatLng(
                              ev.venuePoint!.latitude,
                              ev.venuePoint!.longitude,
                            ),
                            alignment: Alignment.bottomCenter,
                            width: 156,
                            height: 44,
                            child: GestureDetector(
                              key: Key('map-marker-event-${ev.id}'),
                              onTap: widget.onSelectEvent != null
                                  ? () => widget.onSelectEvent!(ev)
                                  : null,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.eventIndigo.withValues(
                                    alpha: 0.92,
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: Colors.white70),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: <Widget>[
                                    if (ev.posterBytes != null)
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          right: 4,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(
                                            4,
                                          ),
                                          child: Image.memory(
                                            ev.posterBytes!,
                                            width: 16,
                                            height: 16,
                                            fit: BoxFit.cover,
                                          ),
                                        ),
                                      )
                                    else
                                      const Icon(
                                        Icons.event_available,
                                        size: 14,
                                        color: Colors.white,
                                      ),
                                    const SizedBox(width: 4),
                                    Flexible(
                                      child: Text(
                                        ev.title,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      // Discoverable Landmark pins (anchored top-center)
                      for (final lm in controller.discoverableLandmarks)
                        Marker(
                          point: LatLng(
                            lm.center.latitude,
                            lm.center.longitude,
                          ),
                          alignment: Alignment.topCenter,
                          width: 150,
                          height: 44,
                          child: GestureDetector(
                            key: Key('map-marker-landmark-${lm.id}'),
                            onTap: () {
                              if (widget.onSelectLandmarkDiscovery != null) {
                                widget.onSelectLandmarkDiscovery!(lm);
                              } else if (widget.onSelectLandmark != null) {
                                final active = activeLandmarks
                                    .where((c) => c.id == lm.id)
                                    .firstOrNull;
                                if (active != null) {
                                  widget.onSelectLandmark!(active);
                                }
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface
                                    .withValues(alpha: 0.92),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: lm.isEligible
                                      ? AppTheme.pulseMint
                                      : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.forum_outlined,
                                    size: 14,
                                    color: lm.isEligible
                                        ? AppTheme.pulseMint
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '${lm.name} (${lm.distanceMeters.round()}m)',
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w700,
                                        color: lm.isEligible
                                            ? Theme.of(context)
                                                  .colorScheme
                                                  .onSurface
                                            : Theme.of(context)
                                                  .colorScheme
                                                  .onSurfaceVariant,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      // User current location dot with real avatar or silhouette
                      // Rendered LAST so it is painted on top of event and landmark pins.
                      if (controller.hasFreshAccurateLocation)
                        Marker(
                          point: userLatLng,
                          alignment: Alignment.center,
                          width: 38,
                          height: 38,
                          child: _buildUserAvatarMarker(controller, userLoc),
                        ),
                    ],
                  ),
                ],
              ),
              Positioned(
                left: 10,
                bottom: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface
                        .withValues(alpha: 0.85),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${controller.discoverableLandmarks.length} landmark(s) • ${visibleEvents.length} event(s) • © OpenStreetMap',
                    style: TextStyle(
                      fontSize: 10,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
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
