import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/models/post_model.dart'; // Importamos nuestro nuevo modelo
import 'package:timeago/timeago.dart' as timeago;

// El nombre ahora es público (sin el guion bajo)
class CommentTile extends StatelessWidget {
  final String postId;
  final Comment comment;
  final Map<String, dynamic>? authorData;
  final String? currentUserId;

  const CommentTile({
    super.key,
    required this.postId,
    required this.comment,
    this.authorData,
    this.currentUserId,
  });

  Future<void> _toggleCommentLike() async {
    if (currentUserId == null) return;
    final commentRef = FirebaseFirestore.instance.collection('post').doc(postId).collection('comentarios').doc(comment.id);
    
    if (comment.likes.contains(currentUserId)) {
      await commentRef.update({'likes': FieldValue.arrayRemove([currentUserId])});
    } else {
      await commentRef.update({'likes': FieldValue.arrayUnion([currentUserId])});
    }
  }

  @override
  Widget build(BuildContext context) {
    timeago.setLocaleMessages('es', timeago.EsMessages());
    final isLiked = currentUserId != null && comment.likes.contains(currentUserId);
    final authorName = authorData?['display_name'] ?? 'Usuario';
    final photoUrl = authorData?['photo_url'] as String?;

    return ListTile(
      leading: CircleAvatar(
        radius: 20,
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 20) : null,
      ),
      title: RichText(
        text: TextSpan(
          style: Theme.of(context).textTheme.bodyMedium,
          children: [
            TextSpan(text: authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
            const WidgetSpan(child: SizedBox(width: 8)),
            TextSpan(text: comment.text),
          ]
        ),
      ),
      subtitle: Row(
        children: [
          Text(timeago.format(comment.timestamp.toDate(), locale: 'es'), style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(width: 16),
          if (comment.likes.isNotEmpty) Text("${comment.likes.length} Me gusta", style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
      trailing: IconButton(
        icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, size: 18, color: isLiked ? Colors.redAccent : null),
        onPressed: _toggleCommentLike,
      ),
    );
  }
}