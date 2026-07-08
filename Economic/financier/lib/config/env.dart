/// Environment configuration loaded from --dart-define or .env
class Env {
  static String get supabaseUrl => const String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://mgyohqvbcpripmkgipvs.supabase.co',
      );
  static String get supabaseAnonKey => const String.fromEnvironment(
        'SUPABASE_ANON_KEY',
        defaultValue: 'sb_publishable_p0NuPgDrOUq8quIw1PFflg__T3UXHhz',
      );
  static bool get isDev => const bool.fromEnvironment('DEV', defaultValue: true);
  static bool get enableSyncLog => const bool.fromEnvironment('SYNC_LOG', defaultValue: false);
}
