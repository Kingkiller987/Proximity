import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.allowSimulatedLocation,
    this.apiBaseUrl = '',
    this.mapTileUrlTemplate = defaultDevTileUrlTemplate,
    this.mapUserAgentPackageName = 'com.proximity.app',
    this.maxImageBytes = 5 * 1024 * 1024,
    this.maxLocationAgeSeconds = 30,
    this.maxGpsAccuracyMeters = 50.0,
  });

  /// Default tile URL for local development and iOS Simulator testing only.
  /// Production deployments MUST pass `--dart-define=MAP_TILE_URL_TEMPLATE=...`
  /// pointing to an authorized commercial or self-hosted tile provider per the
  /// OpenStreetMap Tile Usage Policy.
  static const String defaultDevTileUrlTemplate =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const allowSim = bool.fromEnvironment(
      'ALLOW_SIMULATED_LOCATION',
      defaultValue: true,
    );
    const tileUrl = String.fromEnvironment(
      'MAP_TILE_URL_TEMPLATE',
      defaultValue: defaultDevTileUrlTemplate,
    );
    const userAgent = String.fromEnvironment(
      'MAP_USER_AGENT_PACKAGE',
      defaultValue: 'com.proximity.app',
    );
    const maxImgBytes = int.fromEnvironment(
      'MAX_IMAGE_BYTES',
      defaultValue: 5 * 1024 * 1024,
    );
    const apiBase = String.fromEnvironment('API_BASE_URL', defaultValue: '');

    return const AppConfig(
      environment: env,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      allowSimulatedLocation: allowSim,
      apiBaseUrl: apiBase,
      mapTileUrlTemplate: tileUrl,
      mapUserAgentPackageName: userAgent,
      maxImageBytes: maxImgBytes,
    );
  }

  final String environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool allowSimulatedLocation;
  final String apiBaseUrl;
  final String mapTileUrlTemplate;
  final String mapUserAgentPackageName;
  final int maxImageBytes;
  final int maxLocationAgeSeconds;
  final double maxGpsAccuracyMeters;

  bool get hasApiConfigured => apiBaseUrl.trim().isNotEmpty;

  bool get hasSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Enforces that production environments do not rely on the public
  /// OpenStreetMap tile endpoint (`tile.openstreetmap.org`).
  bool get isTileProviderValidForEnvironment {
    if (mapTileUrlTemplate.trim().isEmpty) return false;
    if (environment.toLowerCase() == 'production') {
      return !mapTileUrlTemplate.contains('tile.openstreetmap.org');
    }
    return true;
  }
}
