class SupabaseConfig {
  // Kredensial Supabase project. Bisa dioverride lewat --dart-define:
  //   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Anon/publishable key aman untuk client-side; jangan pernah taruh service_role key di sini.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://htwczamdwdhsjogqmpke.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imh0d2N6YW1kd2Roc2pvZ3FtcGtlIiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTU2OTEyODYsImV4cCI6MjExMTI2NzI4Nn0.Bk9svezNS0n3Wc5baVXTiIJqOLG8rDX9ULAIRLy_ba8',
  );

  /// Alias publishable key yang dipakai controller notifikasi.
  static String get publishableKey => anonKey;

  /// True bila URL dan kunci sudah diisi.
  static bool get isConfigured => url.isNotEmpty && anonKey.isNotEmpty;
}