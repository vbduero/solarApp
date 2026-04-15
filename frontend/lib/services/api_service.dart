// ============================================================
// Solar-Grow - Servicio de API HTTP
// ============================================================
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_constants.dart';

/// Servicio centralizado para todas las llamadas HTTP al backend
class ApiService {
  static String get baseUrl {
    // Usar URL web si estamos en web, o la del emulador Android
    if (kIsWeb) return ApiConstants.webBaseUrl;
    return ApiConstants.baseUrl;
  }

  /// Token JWT almacenado
  static String? _token;

  /// Obtener headers con autenticación
  static Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (_token != null) 'Authorization': 'Bearer $_token',
  };

  /// Guardar token en memoria y storage persistente
  static Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('auth_token', token);
  }

  /// Cargar token desde storage persistente
  static Future<String?> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('auth_token');
    return _token;
  }

  /// Eliminar token (cerrar sesión)
  static Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('auth_token');
  }

  /// Verificar si hay token almacenado
  static bool get hasToken => _token != null;

  // ============================================================
  // MÉTODOS HTTP GENÉRICOS
  // ============================================================

  /// Solicitud GET
  static Future<dynamic> get(
    String endpoint, {
    Map<String, String>? queryParams,
  }) async {
    try {
      final uri = Uri.parse(
        '$baseUrl$endpoint',
      ).replace(queryParameters: queryParams);
      final response = await http.get(uri, headers: _headers);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error GET $endpoint: $e');
      rethrow;
    }
  }

  /// Solicitud POST
  static Future<dynamic> post(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.post(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error POST $endpoint: $e');
      rethrow;
    }
  }

  /// Solicitud PUT
  static Future<dynamic> put(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.put(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error PUT $endpoint: $e');
      rethrow;
    }
  }

  /// Solicitud PATCH
  static Future<dynamic> patch(
    String endpoint, {
    Map<String, dynamic>? body,
  }) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.patch(
        uri,
        headers: _headers,
        body: body != null ? jsonEncode(body) : null,
      );
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error PATCH $endpoint: $e');
      rethrow;
    }
  }

  /// Solicitud DELETE
  static Future<dynamic> delete(String endpoint) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final response = await http.delete(uri, headers: _headers);
      if (response.statusCode == 204) return null;
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error DELETE $endpoint: $e');
      rethrow;
    }
  }

  /// Subir un archivo (Multipart POST)
  static Future<dynamic> uploadImage(
    String endpoint,
    Uint8List imageBytes,
    String filename,
  ) async {
    try {
      final uri = Uri.parse('$baseUrl$endpoint');
      final request = http.MultipartRequest('POST', uri);

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      request.files.add(
        http.MultipartFile.fromBytes('file', imageBytes, filename: filename),
      );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } catch (e) {
      debugPrint('Error UPLOAD $endpoint: $e');
      rethrow;
    }
  }

  /// Procesar respuesta HTTP
  static dynamic _handleResponse(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.body.isEmpty) return null;
      return jsonDecode(response.body);
    } else {
      final error = response.body.isNotEmpty
          ? jsonDecode(response.body)['detail'] ?? 'Error desconocido'
          : 'Error ${response.statusCode}';
      throw ApiException(response.statusCode, error.toString());
    }
  }
}

/// Excepción personalizada para errores de API
class ApiException implements Exception {
  final int statusCode;
  final String message;

  ApiException(this.statusCode, this.message);

  @override
  String toString() => 'ApiException($statusCode): $message';
}
