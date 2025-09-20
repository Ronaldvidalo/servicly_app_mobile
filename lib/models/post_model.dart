// En lib/models/post_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId; // Nombre consistente 'user_id' en Firestore
  final String title;
  final String description;
  final List<dynamic> media;
  final List<String> likes;
  final List<String> bookmarks; // Campo 'savedBy' en Firestore
  final Timestamp timestamp;
  
  // --- MEJORA: Campos añadidos para la nueva UI ---
  final String category;
  final int commentCount;

  Post({
    required this.id,
    required this.authorId,
    required this.title,
    required this.description,
    required this.media,
    required this.likes,
    required this.bookmarks,
    required this.timestamp,
    // --- MEJORA: Se añaden al constructor ---
    required this.category,
    required this.commentCount,
  });

  factory Post.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Post(
      id: doc.id,
      authorId: data['user_id'] as String? ?? '', // Se lee 'user_id' de Firestore
      title: data['title'] as String? ?? '',
      description: data['post_description'] as String? ?? '',
      media: data['media'] as List<dynamic>? ?? [],
      likes: List<String>.from(data['likes'] ?? []),
      bookmarks: List<String>.from(data['savedBy'] ?? []), // Mapea 'savedBy'
      timestamp: data['timestamp'] ?? Timestamp.now(),
      
      // --- MEJORA: Se leen los nuevos campos de Firestore ---
      // Si el campo no existe en el documento, se usa un valor por defecto para evitar errores.
      category: data['category'] as String? ?? 'General',
      commentCount: data['commentCount'] as int? ?? 0,
    );
  }
}

// La clase Comment no necesita cambios.
class Comment {
  final String id;
  final String text;
  final String userId;
  final Timestamp timestamp;
  final List<dynamic> likes;

  Comment({
    required this.id, required this.text, required this.userId,
    required this.timestamp, required this.likes,
  });

  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Comment(
      id: doc.id,
      text: data['text'] ?? '',
      userId: data['userId'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      likes: List<dynamic>.from(data['likes'] ?? []),
    );
  }
}