import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String id;
  final String authorId;
  final String authorName;
  final String? authorProfilePicUrl;
    final List<String>? userCategorias; // <--- ¡ASEGÚRATE DE QUE ESTA LÍNEA ESTÉ ASÍ!
  final String title;
  final String description;
  final List<dynamic> media;
  final List<String> likes;
  final List<String> bookmarks;
  final Timestamp timestamp;

  Post({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorProfilePicUrl,
    this.userCategorias, 
    required this.title,
    required this.description,
    required this.media,
    required this.likes,
    required this.bookmarks,
    required this.timestamp,
  });

  factory Post.fromFirestore(DocumentSnapshot doc, Map<String, dynamic> authorData) {
    final data = doc.data() as Map<String, dynamic>;
    return Post(
      id: doc.id,
      authorId: data['authorId'] as String? ?? '',
      authorName: authorData['nombreUsuario'] as String? ?? 'Usuario Desconocido',
      authorProfilePicUrl: authorData['profilePicUrl'] as String?,
      // FIX FINAL: Leer de 'userCategorias' de authorData
      userCategorias: (authorData['userCategorias'] as List<dynamic>?)?.map((e) => e.toString()).toList(), // <--- ¡Y LA LECTURA AQUÍ!
      title: data['title'] as String? ?? 'Sin Título',
      description: data['description'] as String? ?? 'Sin descripción',
      media: data['media'] as List<dynamic>? ?? [],
      likes: (data['likes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      bookmarks: (data['bookmark_user'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
    );
  }
}