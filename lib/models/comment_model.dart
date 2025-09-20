// lib/models/comment_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String id;
  final String text;
  final String userId;
  final Timestamp timestamp;
  final List<String> likes;

  Comment({
    required this.id,
    required this.text,
    required this.userId,
    required this.timestamp,
    required this.likes,
  });

  factory Comment.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return Comment(
      id: doc.id,
      text: data['text'] as String? ?? '',
      // ... el resto de tus campos de Comment
      userId: data['userId'] as String? ?? '',
      timestamp: data['timestamp'] as Timestamp? ?? Timestamp.now(),
      likes: (data['likes'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}