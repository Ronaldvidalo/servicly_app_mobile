import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/pages/perfil_pagina/perfil_pagina_widget.dart';
import 'package:servicly_app/widgets/post_detail/comment_tile.dart';
import 'package:video_player/video_player.dart';
import 'dart:developer';
import 'package:servicly_app/models/post_model.dart';

// --- WIDGETS DE MEDIA (Sin cambios) ---
class DetailPageVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const DetailPageVideoPlayer({super.key, required this.videoUrl});
  @override
  State<DetailPageVideoPlayer> createState() => _DetailPageVideoPlayerState();
}

class _DetailPageVideoPlayerState extends State<DetailPageVideoPlayer> {
  late VideoPlayerController _controller;
  bool _isMuted = false;
  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      })
      ..setLooping(true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return _controller.value.isInitialized
        ? AspectRatio(
            aspectRatio: _controller.value.aspectRatio,
            child: Stack(
              alignment: Alignment.center,
              children: [
                VideoPlayer(_controller),
                GestureDetector(
                    onTap: () => setState(() {
                          _controller.value.isPlaying
                              ? _controller.pause()
                              : _controller.play();
                        }),
                    child: AnimatedOpacity(
                        opacity: _controller.value.isPlaying ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 300),
                        child: Container(
                            decoration: BoxDecoration(
                                color: Colors.black.withAlpha(102),
                                shape: BoxShape.circle),
                            child: const Icon(Icons.play_arrow,
                                color: Colors.white, size: 60)))),
                Positioned(
                    bottom: 12,
                    right: 12,
                    child: IconButton(
                        style: IconButton.styleFrom(
                            backgroundColor: Colors.black.withAlpha(128)),
                        icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up,
                            color: Colors.white),
                        onPressed: () => setState(() {
                              _isMuted = !_isMuted;
                              _controller.setVolume(_isMuted ? 0.0 : 1.0);
                            })))
              ],
            ))
        : const AspectRatio(
            aspectRatio: 16 / 9,
            child: Center(child: CircularProgressIndicator()));
  }
}

class MediaCarousel extends StatefulWidget {
  final List<dynamic> mediaItems;
  final String category;

  const MediaCarousel({super.key, required this.mediaItems, required this.category});

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _currentPage = 0;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (widget.mediaItems.isEmpty) {
      return AspectRatio(
          aspectRatio: 4 / 5,
          child: Container(
              color: Colors.grey.shade300,
              child: const Icon(Icons.image_not_supported)));
    }
    return AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(alignment: Alignment.bottomCenter, children: [
          PageView.builder(
              itemCount: widget.mediaItems.length,
              onPageChanged: (value) => setState(() => _currentPage = value),
              itemBuilder: (context, index) {
                final item = widget.mediaItems[index];
                String? url;
                String type = 'image';
                if (item is Map<String, dynamic>) {
                  url = item['url'] as String?;
                  type = item['type'] as String? ?? 'image';
                } else if (item is String) {
                  url = item;
                }
                if (url == null) {
                  return Container(
                      color: Colors.grey.shade200,
                      child: const Icon(Icons.error));
                }
                if (type == 'video') {
                  return DetailPageVideoPlayer(videoUrl: url);
                } else {
                  return Image.network(url,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) =>
                          progress == null
                              ? child
                              : const Center(child: CircularProgressIndicator()),
                      errorBuilder: (context, error, stackTrace) => Container(
                          color: Colors.grey.shade200,
                          child: const Icon(Icons.broken_image)));
                }
              }),
          if (widget.mediaItems.length > 1)
            Positioned(
                bottom: 12.0,
                child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(widget.mediaItems.length, (index) {
                      return AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          margin: const EdgeInsets.symmetric(horizontal: 4.0),
                          height: 8.0,
                          width: _currentPage == index ? 24.0 : 8.0,
                          decoration: BoxDecoration(
                              color: _currentPage == index
                                  ? Colors.white
                                  : Colors.white.withAlpha(153),
                              borderRadius: BorderRadius.circular(12)));
                    }))),
            Positioned(
              top: 16,
              left: 16,
              child: Chip(
                label: Text(widget.category),
                backgroundColor: theme.colorScheme.primary.withAlpha((255 * 0.8).round()),
                labelStyle: TextStyle(color: theme.colorScheme.onPrimary, fontWeight: FontWeight.bold),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              ),
            ),
        ]));
  }
}

class PostDetallePage extends StatefulWidget {
  final String postId;
  const PostDetallePage({super.key, required this.postId});

  @override
  State<PostDetallePage> createState() => _PostDetallePageState();
}

class _PostDetallePageState extends State<PostDetallePage> {
  final _commentController = TextEditingController();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  Map<String, dynamic>? _authorData;
  bool _isLoadingAuthor = true;
  int _commentCount = 0;
  bool _initialIsFollowingState = false;
  String? _fetchedAuthorId;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _loadAuthorData(String authorId) {
    Future.delayed(Duration.zero, () {
      if(mounted) {
        setState(() {
          _isLoadingAuthor = true;
        });
      }
    });

    FirebaseFirestore.instance
        .collection('usuarios')
        .doc(authorId)
        .get()
        .then((authorDoc) {
      if (authorDoc.exists && mounted) {
        final followers =
            List<String>.from(authorDoc.data()?['followers'] ?? []);
        setState(() {
          _authorData = authorDoc.data();
          _initialIsFollowingState = followers.contains(_currentUserId);
          _isLoadingAuthor = false; 
        });
      }
    }).catchError((e) {
      log("Error al cargar datos de autor: $e");
      if (mounted) setState(() => _isLoadingAuthor = false);
    });
  }

  Future<void> _postComment(String authorId) async {
    final text = _commentController.text.trim();
    if (text.isEmpty || _currentUserId == null) return;

    try {
      FocusScope.of(context).unfocus();
      await FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .collection('comentarios')
          .add({
        'userId': _currentUserId,
        'text': text,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
      });

      if (_currentUserId != authorId) {
        final currentUserDoc = await FirebaseFirestore.instance
            .collection('usuarios')
            .doc(_currentUserId)
            .get();
        final commenterName =
            currentUserDoc.data()?['display_name'] ?? 'Alguien';

        await FirebaseFirestore.instance.collection('notificaciones').add({
          'destinatarioId': authorId,
          'remitenteId': _currentUserId,
          'titulo': '$commenterName ha comentado tu publicación',
          'mensaje': text,
          'tipo': 'nuevo_comentario',
          'idReferencia': widget.postId,
          'leida': false,
          'fechaCreacion': FieldValue.serverTimestamp(),
        });
      }

      if (mounted) {
        _commentController.clear();
        setState(() {
          _commentCount++;
        });
      }
    } catch (e) {
      log("Error al publicar comentario: $e");
    }
  }

  Future<void> _toggleLike(Post post) async {
    if (_currentUserId == null) return;
    final postRef = FirebaseFirestore.instance.collection('post').doc(post.id);
    if (post.likes.contains(_currentUserId)) {
      await postRef.update({
        'likes': FieldValue.arrayRemove([_currentUserId])
      });
    } else {
      await postRef.update({
        'likes': FieldValue.arrayUnion([_currentUserId])
      });
    }
  }

  Future<void> _toggleSave(Post post) async {
    if (_currentUserId == null) return;
    final postRef = FirebaseFirestore.instance.collection('post').doc(post.id);
    if (post.bookmarks.contains(_currentUserId)) {
      await postRef.update({
        'savedBy': FieldValue.arrayRemove([_currentUserId])
      });
    } else {
      await postRef.update({
        'savedBy': FieldValue.arrayUnion([_currentUserId])
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('post')
          .doc(widget.postId)
          .snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.connectionState == ConnectionState.waiting && _authorData == null) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        if (!postSnapshot.hasData || !postSnapshot.data!.exists) {
          return Scaffold(
              appBar: AppBar(title: const Text("Error")),
              body: const Center(child: Text('Publicación no encontrada.')));
        }

        final post = Post.fromFirestore(postSnapshot.data!);
        
        if (_fetchedAuthorId != post.authorId) {
          _loadAuthorData(post.authorId);
          _fetchedAuthorId = post.authorId;
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Publicación'),
            actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))],
          ),
          body: _isLoadingAuthor 
            ? const Center(child: CircularProgressIndicator()) 
            : _buildPostContent(context, post),
          bottomNavigationBar: _buildCommentInputField(post.authorId),
        );
      },
    );
  }

  Widget _buildPostContent(BuildContext context, Post post) {
    final theme = Theme.of(context);
    return CustomScrollView(
      slivers: [
          SliverToBoxAdapter(child: MediaCarousel(mediaItems: post.media, category: post.category)),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAuthorHeader(context, post),
                  const SizedBox(height: 16),
                  Text(post.title,
                      style: theme.textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(post.description,
                      style: theme.textTheme.bodyLarge?.copyWith(height: 1.5)),
                  const SizedBox(height: 16),
                  _buildActionBar(post),
                  const Divider(height: 32),
                  Text("Comentarios",
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
          _buildCommentSection(post.id),
      ],
    );
  }

  Widget _buildAuthorHeader(BuildContext context, Post post) {
    final authorName = _authorData?['display_name'] ?? 'Usuario Anónimo';
    final authorProfilePicUrl = _authorData?['photo_url'] as String? ?? '';
    
    return GestureDetector(
      onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => PerfilPaginaWidget(user_id: post.authorId))),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          radius: 24,
          backgroundImage:
              authorProfilePicUrl.isNotEmpty ? NetworkImage(authorProfilePicUrl) : null,
          child: authorProfilePicUrl.isEmpty ? const Icon(Icons.person) : null,
        ),
        title: Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text("Proveedor Verificado"),
        trailing: _FollowButton(
          authorId: post.authorId,
          currentUserId: _currentUserId,
          initialIsFollowing: _initialIsFollowingState,
        ),
      ),
    );
  }

  Widget _buildActionBar(Post post) {
    final theme = Theme.of(context);
    final isLiked = _currentUserId != null && post.likes.contains(_currentUserId);
    final isSaved = _currentUserId != null && post.bookmarks.contains(_currentUserId);
    
    final displayCommentCount = _commentCount > post.commentCount ? _commentCount : post.commentCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(
                isLiked ? Icons.favorite : Icons.favorite_border,
                color: isLiked ? Colors.redAccent : theme.iconTheme.color,
                size: 28,
              ),
              onPressed: () => _toggleLike(post),
            ),
            if (post.likes.isNotEmpty) Text("${post.likes.length}", style: theme.textTheme.bodyLarge),
            const SizedBox(width: 16),
            
            IconButton(
              icon: Icon(Icons.chat_bubble_outline, size: 28, color: theme.iconTheme.color),
              onPressed: () { },
            ),
            if (displayCommentCount > 0) Text("$displayCommentCount", style: theme.textTheme.bodyLarge),
          ],
        ),
        
        IconButton(
          onPressed: () => _toggleSave(post),
          icon: Icon(
            isSaved ? Icons.bookmark : Icons.bookmark_border,
            size: 28,
            color: isSaved ? theme.colorScheme.primary : theme.iconTheme.color,
          ),
        ),
      ],
    );
  }

  Widget _buildCommentInputField(String authorId) {
    return Material(
      elevation: 8,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: 8,
              right: 8,
              top: 8),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                      hintText: "Añadir un comentario...",
                      filled: true,
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(30),
                          borderSide: BorderSide.none)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => _postComment(authorId),
                icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCommentSection(String postId) {
    final commentsQuery = FirebaseFirestore.instance
        .collection('post')
        .doc(postId)
        .collection('comentarios')
        .orderBy('timestamp', descending: true);
    return StreamBuilder<QuerySnapshot>(
      stream: commentsQuery.snapshots(),
      builder: (context, commentsSnapshot) {
        if (commentsSnapshot.hasError) {
          return const SliverToBoxAdapter(
              child: Center(child: Text("Error al cargar comentarios.")));
        }
        if (commentsSnapshot.connectionState == ConnectionState.waiting) {
          return const SliverToBoxAdapter(child: SizedBox.shrink());
        }
        final commentDocs = commentsSnapshot.data?.docs;
        
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && commentDocs != null && _commentCount != commentDocs.length) {
            setState(() {
              _commentCount = commentDocs.length;
            });
          }
        });

        if (commentDocs == null || commentDocs.isEmpty) {
          return const SliverToBoxAdapter(
              child: Center(
                  child: Padding(
                      padding: EdgeInsets.all(24.0),
                      child: Text("Sé el primero en comentar."))));
        }

        final userIds =
            commentDocs.map((doc) => doc['userId'] as String).toSet().toList();
        return FutureBuilder<List<DocumentSnapshot>>(
          future: _getUsersFromIds(userIds),
          builder: (context, usersSnapshot) {
            if (usersSnapshot.connectionState == ConnectionState.waiting) {
              return const SliverToBoxAdapter(
                  child: Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )));
            }
            final usersMap = {
              for (var doc in usersSnapshot.data ?? [])
                doc.id: doc.data() as Map<String, dynamic>
            };
            return SliverList.builder(
              itemCount: commentDocs.length,
              itemBuilder: (context, index) {
                final comment = Comment.fromFirestore(
                    commentDocs[index] as DocumentSnapshot<Map<String, dynamic>>);
                final userData = usersMap[comment.userId];
                return CommentTile(
                    postId: postId,
                    comment: comment,
                    authorData: userData,
                    currentUserId: _currentUserId);
              },
            );
          },
        );
      },
    );
  }

  Future<List<DocumentSnapshot>> _getUsersFromIds(List<String> userIds) async {
    if (userIds.isEmpty) return [];
    final userDocs = await FirebaseFirestore.instance
        .collection('usuarios')
        .where(FieldPath.documentId, whereIn: userIds)
        .get();
    return userDocs.docs;
  }
}

// --- WIDGET Stateful para el botón "Seguir" ---

class _FollowButton extends StatefulWidget {
  final String authorId;
  final String? currentUserId;
  final bool initialIsFollowing;

  const _FollowButton({
    required this.authorId,
    required this.currentUserId,
    required this.initialIsFollowing,
  });

  @override
  State<_FollowButton> createState() => _FollowButtonState();
}

class _FollowButtonState extends State<_FollowButton> {
  late bool _isFollowing;

  @override
  void initState() {
    super.initState();
    _isFollowing = widget.initialIsFollowing;
  }

  @override
  void didUpdateWidget(covariant _FollowButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialIsFollowing != oldWidget.initialIsFollowing) {
      setState(() {
        _isFollowing = widget.initialIsFollowing;
      });
    }
  }

  Future<void> _toggleFollow() async {
    if (widget.currentUserId == null || widget.currentUserId!.isEmpty) return;

    setState(() {
      _isFollowing = !_isFollowing;
    });

    final authorRef = FirebaseFirestore.instance.collection('usuarios').doc(widget.authorId);
    final myRef = FirebaseFirestore.instance.collection('usuarios').doc(widget.currentUserId);

    try {
      if (_isFollowing) {
        await authorRef.update({
          'followers': FieldValue.arrayUnion([widget.currentUserId])
        });
        await myRef.update({
          'following': FieldValue.arrayUnion([widget.authorId])
        });
      } else {
        await authorRef.update({
          'followers': FieldValue.arrayRemove([widget.currentUserId])
        });
         await myRef.update({
          'following': FieldValue.arrayRemove([widget.authorId])
        });
      }
    } catch (e) {
      log("Error al actualizar seguimiento: $e");
      if(mounted) {
        setState(() {
          _isFollowing = !_isFollowing; 
        });
      }
    }
  }

  // --- SOLUCIÓN: Se añade el método build que faltaba ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    if (_isFollowing) {
      return OutlinedButton(
        onPressed: _toggleFollow,
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: theme.colorScheme.primary),
          foregroundColor: theme.colorScheme.primary,
        ),
        child: const Text("Siguiendo"),
      );
    } else {
      return FilledButton(
        onPressed: _toggleFollow,
        child: const Text("Seguir"),
      );
    }
  }
}