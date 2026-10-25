import 'package:flutter/foundation.dart';

@immutable
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.supabaseUrl,
    required this.supabaseAnonKey,
    required this.allowSimulatedLocation,
  });

  factory AppConfig.fromEnvironment() {
    const env = String.fromEnvironment('APP_ENV', defaultValue: 'development');
    const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
    const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
    const allowSim = bool.fromEnvironment(
      'ALLOW_SIMULATED_LOCATION',
      defaultValue: true,
    );

    return const AppConfig(
      environment: env,
      supabaseUrl: supabaseUrl,
      supabaseAnonKey: supabaseAnonKey,
      allowSimulatedLocation: allowSim,
    );
  }

  final String environment;
  final String supabaseUrl;
  final String supabaseAnonKey;
  final bool allowSimulatedLocation;

  bool get hasSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
