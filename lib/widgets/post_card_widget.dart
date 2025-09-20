// lib/widgets/post_card_widget.dart

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/pages/perfil_pagina/perfil_pagina_widget.dart';
import 'package:servicly_app/pages/post_detalle/post_detalle_page.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:share_plus/share_plus.dart';

/// --- WIDGET DE VIDEO CON AUTOPLAY Y CONTROL DE SONIDO ---
class AutoPlayVideoPlayer extends StatefulWidget {
  final String videoUrl;
  const AutoPlayVideoPlayer({super.key, required this.videoUrl});

  @override
  State<AutoPlayVideoPlayer> createState() => _AutoPlayVideoPlayerState();
}

class _AutoPlayVideoPlayerState extends State<AutoPlayVideoPlayer> {
  VideoPlayerController? _controller;
  bool _isMuted = true;

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _initializePlayer() {
    if (!mounted) return;
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl))
      ..initialize().then((_) {
        if (mounted) {
          _controller!.setLooping(true);
          _controller!.setVolume(_isMuted ? 0.0 : 1.0);
          _controller!.play();
          setState(() {});
        }
      });
  }

  void _disposePlayer() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
  }

  @override
  Widget build(BuildContext context) {
    return VisibilityDetector(
      key: Key(widget.videoUrl),
      onVisibilityChanged: (visibilityInfo) {
        if (!mounted) return;
        var visiblePercentage = visibilityInfo.visibleFraction * 100;
        if (visiblePercentage > 50 && _controller == null) {
          _initializePlayer();
        } else if (visiblePercentage < 50 && _controller != null) {
          _disposePlayer();
        }
      },
      child: AspectRatio(
        aspectRatio: 4 / 5,
        child: Stack(
          alignment: Alignment.bottomRight,
          children: [
            if (_controller != null && _controller!.value.isInitialized)
              SizedBox.expand(child: VideoPlayer(_controller!))
            else
              Container(
                color: Colors.black,
                child: const Center(child: CircularProgressIndicator(color: Colors.white)),
              ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.black.withAlpha(128)),
                icon: Icon(_isMuted ? Icons.volume_off : Icons.volume_up, color: Colors.white),
                onPressed: () {
                  setState(() {
                    _isMuted = !_isMuted;
                    _controller?.setVolume(_isMuted ? 0.0 : 1.0);
                  });
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- CARRUSEL DE MEDIOS UNIFICADO ---
class MediaCarousel extends StatefulWidget {
  final List<dynamic> mediaItems;
  const MediaCarousel({super.key, required this.mediaItems});

  @override
  State<MediaCarousel> createState() => _MediaCarouselState();
}

class _MediaCarouselState extends State<MediaCarousel> {
  int _currentPage = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.mediaItems.isEmpty) {
      return AspectRatio(
        aspectRatio: 4 / 5,
        child: Container(color: Colors.grey.shade300, child: const Icon(Icons.image_not_supported)),
      );
    }
    return AspectRatio(
      aspectRatio: 4 / 5,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
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
                return Container(color: Colors.grey.shade200, child: const Icon(Icons.error));
              }
              if (type == 'video') {
                return AutoPlayVideoPlayer(videoUrl: url);
              } else {
                return Image.network(url, fit: BoxFit.cover);
              }
            },
          ),
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
                      color: _currentPage == index ? Colors.white : Colors.white.withAlpha(153),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

// --- WIDGET POSTCARD ---
class PostCard extends StatefulWidget {
  final String postId;
  final Map<String, dynamic> postData;
  final Map<String, dynamic> authorData;
  const PostCard({
    super.key,
    required this.postId,
    required this.postData,
    required this.authorData,
  });
  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  late bool isLiked;
  late bool isSaved;
  late int likeCount;

  @override
  void initState() {
    super.initState();
    final List<dynamic> likes = widget.postData['likes'] ?? [];
    isLiked = likes.contains(currentUserId);
    likeCount = likes.length;
    final List<dynamic> bookmarks = widget.postData['bookmark_user'] ?? [];
    isSaved = bookmarks.contains(currentUserId);
  }

  Future<void> _compartirPost() async {
    final postId = widget.postId;
    final titulo = widget.postData['title'] ?? 'un post increíble';
    
    final String url = "https://serviclyapp-44213.web.app/post?id=$postId";
    final String texto = "¡Mirá este post en Servicly!\n\n\"$titulo\"\n\n$url";
    await Share.share(texto);
  }

  void _reportPost(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Denunciar Publicación'),
          content: const Text('¿Estás seguro de que deseas denunciar esta publicación?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
              child: const Text('Denunciar', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                Navigator.of(dialogContext).pop();
                if (currentUserId.isEmpty) return;
                try {
                  await FirebaseFirestore.instance.collection('reports').add({
                    'postId': widget.postId,
                    'reporterId': currentUserId,
                    'reportedUserId': widget.postData['userID'],
                    'timestamp': FieldValue.serverTimestamp(),
                    'reason': 'Reportado desde el menú del post',
                  });
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Publicación denunciada. Gracias.')),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Error al procesar la denuncia.')),
                    );
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _toggleLike() async {
    if (currentUserId.isEmpty) return;
    final postRef = FirebaseFirestore.instance.collection('post').doc(widget.postId);
    final bool currentlyLiked = isLiked;
    setState(() {
      isLiked = !currentlyLiked;
      likeCount += isLiked ? 1 : -1;
    });

    try {
      if (currentlyLiked) {
        await postRef.update({
          'likes': FieldValue.arrayRemove([currentUserId])
        });
      } else {
        await postRef.update({
          'likes': FieldValue.arrayUnion([currentUserId])
        });
      }
      debugPrint("✅ FLUTTER: Update a Firestore para LIKE fue EXITOSO.");
    } catch (e) {
      debugPrint("❌ FLUTTER ERROR: El update a Firestore para LIKE falló: $e");
      setState(() {
        isLiked = currentlyLiked;
        likeCount += currentlyLiked ? -1 : 1;
      });
    }
  }

  Future<void> _toggleSave() async {
    if (currentUserId.isEmpty) return;
    final postRef = FirebaseFirestore.instance.collection('post').doc(widget.postId);
    setState(() => isSaved = !isSaved);
    try {
      if (isSaved) {
        await postRef.update({'bookmark_user': FieldValue.arrayUnion([currentUserId])});
      } else {
        await postRef.update({'bookmark_user': FieldValue.arrayRemove([currentUserId])});
      }
    } catch (e) {
      setState(() => isSaved = !isSaved);
    }
  }

  void _navigateToProfile(String userId) {
    if (userId.isNotEmpty) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => PerfilPaginaWidget(user_id: userId)));
    }
  }

  void _navigateToPostDetail() {
    Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetallePage(postId: widget.postId)));
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> media = widget.postData['media'] ?? widget.postData['photos'] ?? [];
    return Card(
      elevation: 4,
      shadowColor: Colors.black.withAlpha(25),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.only(bottom: 24),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(context),
          GestureDetector(
            onTap: _navigateToPostDetail,
            child: MediaCarousel(mediaItems: media),
          ),
          _buildActionButtons(context),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: _buildDescriptionAndTitle(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final authorId = widget.postData['userID'] ?? '';
    final photoUrl = widget.authorData['photo_url'] as String?;
    final displayName = widget.authorData['display_name'] ?? 'Anónimo';
    
    String categoriaToShow = ''; 
    
    if (widget.postData.containsKey('userCategorias') && widget.postData['userCategorias'] is List) {
      final List<dynamic> categorias = widget.postData['userCategorias'];
      if (categorias.length == 1) {
          categoriaToShow = categorias.first.toString();
      } else if (categorias.length > 1) {
          categoriaToShow = 'Multicategoría';
      }
    }

    return ListTile(
      onTap: () => _navigateToProfile(authorId),
      leading: CircleAvatar(
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person) : null,
      ),
      title: Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: categoriaToShow.isNotEmpty ? Text(categoriaToShow) : null,
      trailing: PopupMenuButton<String>(
        onSelected: (value) {
          if (value == 'report') {
            _reportPost(context);
          }
        },
        itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
          const PopupMenuItem<String>(
            value: 'report',
            child: ListTile(
              leading: Icon(Icons.flag_outlined),
              title: Text('Denunciar'),
            ),
          ),
        ],
        icon: const Icon(Icons.more_vert),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              TextButton.icon(
                onPressed: _toggleLike,
                icon: Icon(isLiked ? Icons.favorite : Icons.favorite_border, color: isLiked ? Colors.redAccent : null),
                label: Text(likeCount.toString()),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).textTheme.bodyLarge?.color),
              ),
              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('post').doc(widget.postId).collection('comentarios').snapshots(),
                builder: (context, snapshot) {
                  final commentCount = snapshot.hasData ? snapshot.data!.docs.length : 0;
                  return TextButton.icon(
                    onPressed: _navigateToPostDetail,
                    icon: const Icon(Icons.chat_bubble_outline),
                    label: Text(commentCount.toString()),
                    style: TextButton.styleFrom(foregroundColor: Theme.of(context).textTheme.bodyLarge?.color),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.share_outlined),
                onPressed: _compartirPost,
              ),
            ],
          ),
          IconButton(
            icon: Icon(isSaved ? Icons.bookmark : Icons.bookmark_border),
            onPressed: _toggleSave,
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionAndTitle(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final description = widget.postData['description'] ?? '';
    final title = widget.postData['title'] ?? 'Sin Título';

    final fullText = TextSpan(
      style: textTheme.bodyMedium,
      children: <TextSpan>[
        TextSpan(text: '$title ', style: const TextStyle(fontWeight: FontWeight.bold)),
        TextSpan(text: description),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: fullText,
          maxLines: 2,
          textDirection: TextDirection.ltr,
        )..layout(maxWidth: constraints.maxWidth);

        if (painter.didExceedMaxLines) {
          return RichText(
            text: TextSpan(
              children: [
                fullText,
                const TextSpan(text: ' '),
                TextSpan(
                  text: '... ver más',
                  style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                  recognizer: TapGestureRecognizer()..onTap = _navigateToPostDetail,
                ),
              ],
            ),
          );
        } else {
          return RichText(text: fullText);
        }
      },
    );
  }
}