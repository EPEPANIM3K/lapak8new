class SupabaseConfig {
  // Kredensial Supabase project. Bisa dioverride lewat --dart-define:
  //   --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
  // Anon/publishable key aman untuk client-side; jangan pernah taruh service_role key di sini.
  static const url = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://htsimcyxytghrifuogkf.supabase.co',
  );
  static const anonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_hGNSMJ-o-ksv12vqr4EMvA_SYqrLRv4',
  );
}