import '../../../core/network/lapak8_api_client.dart';
import '../models/app_user.dart';

class AuthSession {
  const AuthSession({required this.token, required this.user});

  final String token;
  final AppUser user;
}

class AuthService {
  AuthService(this._client);

  final Lapak8ApiClient _client;

  Future<AuthSession> login(String identifier, String password) async {
    final response = await _client.post(
      '/api/v1/auth/login',
      authenticated: false,
      body: {'identifier': identifier, 'password': password},
    );
    final data = response['data'];
    if (data is! Map<String, dynamic> ||
        data['token'] is! String ||
        data['user'] is! Map<String, dynamic>) {
      throw const Lapak8ApiException('Data login dari server tidak valid.');
    }
    return AuthSession(
      token: data['token'] as String,
      user: AppUser.fromJson(data['user']),
    );
  }
}