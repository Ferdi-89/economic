class AppConfig {
  static late final String supabaseUrl;
  static late final String supabaseAnonKey;
  static late final String appName;
  static late final String appVersion;

  static void initialize() {
    supabaseUrl = const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'https://mgyohqvbcpripmkgipvs.supabase.co',
    );
    supabaseAnonKey = const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'sb_publishable_p0NuPgDrOUq8quIw1PFflg__T3UXHhz',
    );
    appName = 'Financier';
    appVersion = '1.0.0';
  }
}
