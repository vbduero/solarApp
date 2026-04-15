// ============================================================
// Solar-Grow - Provider de Autenticación
// ============================================================
import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../config/api_constants.dart';

/// Estado de autenticación
enum AuthStatus { initial, loading, authenticated, unauthenticated, error }

/// Provider que gestiona la autenticación del usuario
class AuthProvider extends ChangeNotifier {
  AuthStatus _status = AuthStatus.initial;
  UserModel? _user;
  String? _errorMessage;

  AuthStatus get status => _status;
  UserModel? get user => _user;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated;

  /// Intentar restaurar sesión al iniciar la app
  Future<void> tryAutoLogin() async {
    _status = AuthStatus.loading;
    notifyListeners();

    final token = await ApiService.loadToken();
    if (token != null) {
      try {
        final data = await ApiService.get(ApiConstants.me);
        _user = UserModel.fromJson(data);
        _status = AuthStatus.authenticated;
      } catch (e) {
        await ApiService.clearToken();
        _status = AuthStatus.unauthenticated;
      }
    } else {
      _status = AuthStatus.unauthenticated;
    }
    notifyListeners();
  }

  /// Registrar nuevo usuario
  Future<bool> register({
    required String email,
    required String password,
    String? fullName,
    String? city,
  }) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.post(
        ApiConstants.register,
        body: {
          'email': email,
          'password': password,
          'full_name': fullName,
          'city': city ?? 'Neiva',
        },
      );

      await ApiService.saveToken(data['access_token']);
      _user = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error de conexión. Verifica tu internet.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Iniciar sesión
  Future<bool> login({required String email, required String password}) async {
    _status = AuthStatus.loading;
    _errorMessage = null;
    notifyListeners();

    try {
      final data = await ApiService.post(
        ApiConstants.login,
        body: {'email': email, 'password': password},
      );

      await ApiService.saveToken(data['access_token']);
      _user = UserModel.fromJson(data['user']);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _errorMessage = e.message;
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    } catch (e) {
      _errorMessage = 'Error de conexión. Verifica tu internet.';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Cerrar sesión
  Future<void> logout() async {
    await ApiService.clearToken();
    _user = null;
    _status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Actualizar perfil
  Future<bool> updateProfile({
    String? fullName,
    String? city,
    String? avatarUrl,
  }) async {
    _status = AuthStatus.loading;
    notifyListeners();
    try {
      final body = <String, dynamic>{};
      if (fullName != null) body['full_name'] = fullName;
      if (city != null) body['city'] = city;
      if (avatarUrl != null) body['avatar_url'] = avatarUrl;

      final data = await ApiService.put('/api/auth/me', body: body);
      _user = UserModel.fromJson(data);
      _status = AuthStatus.authenticated;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Error al actualizar perfil';
      _status = AuthStatus.error;
      notifyListeners();
      return false;
    }
  }

  /// Subir imagen de perfil
  Future<String?> uploadAvatar(Uint8List imageBytes, String filename) async {
    try {
      final data = await ApiService.uploadImage(
        '/api/auth/upload-avatar',
        imageBytes,
        filename,
      );
      if (data != null && data['avatar_url'] != null) {
        return data['avatar_url'];
      }
      return null;
    } catch (e) {
      debugPrint('Error al subir avatar: $e');
      return null;
    }
  }

  /// Modo demo - Iniciar sin backend
  void enterDemoMode() {
    _user = UserModel(
      id: 1,
      email: 'demo@solargrow.com',
      fullName: 'Agricultor Solar',
      city: 'Neiva',
      isActive: true,
      createdAt: DateTime.now(),
    );
    _status = AuthStatus.authenticated;
    notifyListeners();
  }
}
