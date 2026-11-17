/// Membuat URL sementara untuk memutar berkas video di web.
///
/// Versi stub untuk platform non-web: tidak ada dukungan blob URL,
/// sehingga pemutaran video lokal web tidak tersedia di sini.
String? createLocalMediaUrl(Object file) => null;

/// Mencabut URL sementara agar memori browser dibebaskan.
void revokeLocalMediaUrl(String? url) {}
