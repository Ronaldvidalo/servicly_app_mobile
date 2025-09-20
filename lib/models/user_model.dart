import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String displayName;
  final String? photoUrl;
  final String? userCategoria;
  final String? descripcion;
  final bool esVerificado;
  // --- MEJORA: Se especifica el tipo de dato de la lista ---
  final List<String> followers;
  final List<String> following;
  final int trabajos;
  final double rating;
  final int ratingCount;

  UserModel({
    required this.id,
    required this.displayName,
    this.photoUrl,
    this.userCategoria,
    this.descripcion,
    required this.esVerificado,
    required this.followers,
    required this.following,
    required this.trabajos,
    required this.rating,
    required this.ratingCount,
  });

  // Factory constructor para crear un UserModel desde un DocumentSnapshot de Firestore
  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      displayName: data['display_name'] ?? 'Usuario Anónimo',
      photoUrl: data['photo_url'],
      userCategoria: data['userCategoria'],
      descripcion: data['descripcion'],
      esVerificado: data['esVerificado'] ?? false,
      // --- MEJORA: Se convierte la lista de forma segura a List<String> ---
      followers: List<String>.from(data['followers'] ?? []),
      following: List<String>.from(data['following'] ?? []),
      trabajos: data['trabajos'] as int? ?? 0,
      rating: (data['rating'] ?? 0.0).toDouble(),
      ratingCount: data['ratingCount'] as int? ?? 0,
    );
  }
}