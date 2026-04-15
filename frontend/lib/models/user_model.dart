// ============================================================
// Solar-Grow - Modelo de Usuario
// ============================================================

import '../services/api_service.dart';

/// Modelo que representa un usuario de la aplicación
class UserModel {
  final int id;
  final String email;
  final String? fullName;
  final String? avatarUrl;
  final String? city;
  final bool isActive;
  final DateTime createdAt;

  UserModel({
    required this.id,
    required this.email,
    this.fullName,
    this.avatarUrl,
    this.city,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      fullName: json['full_name'],
      avatarUrl: json['avatar_url'] != null
          ? (json['avatar_url'].startsWith('http')
                ? json['avatar_url']
                : '${ApiService.baseUrl}${json['avatar_url']}')
          : null,
      city: json['city'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'full_name': fullName,
      'avatar_url': avatarUrl,
      'city': city,
      'is_active': isActive,
    };
  }
}
