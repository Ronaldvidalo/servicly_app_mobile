import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:cloud_functions/cloud_functions.dart';

// ----- IMPORTACIONES DE TU PROYECTO -----
import 'package:servicly_app/models/user_model.dart';
import 'package:servicly_app/pages/post_detalle/post_detalle_page.dart';
import 'package:servicly_app/pages/chat/chat_page.dart' hide ChatService;
import 'package:servicly_app/pages/pagos/verificacion_page.dart';
import 'package:servicly_app/pages/perfil_pagina/editar_perfil.dart';
import 'package:servicly_app/services/chat_service.dart';

class PerfilPaginaWidget extends StatefulWidget {
  final String user_id;
  const PerfilPaginaWidget({super.key, required this.user_id});

  @override
  State<PerfilPaginaWidget> createState() => _PerfilPaginaWidgetState();
}

class _PerfilPaginaWidgetState extends State<PerfilPaginaWidget>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isMyProfile = false;
  bool _isLoadingFollow = false;
  bool _isFollowing = false;
  bool _isChatLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _isMyProfile = widget.user_id == _currentUserId;
    if (!_isMyProfile) {
      _checkIfFollowing();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _checkIfFollowing() async {
    if (_currentUserId.isEmpty) return;
    final doc = await FirebaseFirestore.instance.collection('usuarios').doc(_currentUserId).get();
    if (doc.exists && doc.data()!.containsKey('following')) {
      final List<dynamic> following = doc.data()!['following'];
      if (mounted) {
        setState(() {
          _isFollowing = following.contains(widget.user_id);
        });
      }
    }
  }

  Future<void> _toggleFollow() async {
    if (_currentUserId.isEmpty) return;
    setState(() => _isLoadingFollow = true);
    
    final myDocRef = FirebaseFirestore.instance.collection('usuarios').doc(_currentUserId);
    final theirDocRef = FirebaseFirestore.instance.collection('usuarios').doc(widget.user_id);

    try {
      if (_isFollowing) {
        await myDocRef.update({'following': FieldValue.arrayRemove([widget.user_id])});
        await theirDocRef.update({'followers': FieldValue.arrayRemove([_currentUserId])});
      } else {
        await myDocRef.update({'following': FieldValue.arrayUnion([widget.user_id])});
        await theirDocRef.update({'followers': FieldValue.arrayUnion([_currentUserId])});
      }
      if (mounted) {
        setState(() => _isFollowing = !_isFollowing);
      }
    } catch (e) {
      debugPrint("Error al seguir/dejar de seguir: $e");
    } finally {
      if (mounted) setState(() => _isLoadingFollow = false);
    }
  }

  Future<void> _iniciarChat(UserModel user) async {
  setState(() => _isChatLoading = true);
  
  try {
   
    final chatService = ChatService(); 
    final String chatId = await chatService.getOrCreateChat(user.id);

    if (!mounted) return;
    
    // 2. Navega a la pantalla del chat, pasando el ID obtenido
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaginaChatDetalle(
          chatId: chatId, // <-- Aquí está la corrección clave
          nombreOtroUsuario: user.displayName,
          fotoUrlOtroUsuario: user.photoUrl,
        ),
      ),
    );

  } on FirebaseFunctionsException catch (e) {
    debugPrint("ERROR de Cloud Function: ${e.code} - ${e.message}");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al iniciar el chat: ${e.message}')),
      );
    }
  } catch (e) {
    debugPrint("ERROR GENÉRICO al iniciar chat: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ocurrió un error al iniciar el chat.')),
      );
    }
  } finally {
    if (mounted) setState(() => _isChatLoading = false);
  }
}

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(widget.user_id)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return Scaffold(
              appBar: AppBar(),
              body: const Center(child: Text('Usuario no encontrado.'))
            );
          }

          final user = UserModel.fromFirestore(snapshot.data!);
          final theme = Theme.of(context);

          return DefaultTabController(
            length: 2,
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) {
                return [
                  SliverAppBar(
                    title: Text(user.displayName),
                    pinned: true,
                    floating: true,
                    actions: [
                      IconButton(onPressed: () {}, icon: const Icon(Icons.more_vert))
                    ],
                  ),

                  SliverToBoxAdapter(
                    child: _buildProfileHeader(user, theme),
                  ),

                  SliverPersistentHeader(
                    delegate: _SliverTabBarDelegate(
                      TabBar(
                        controller: _tabController,
                        tabs: const [
                          Tab(icon: Icon(Icons.grid_on_outlined, size: 22), text: 'Publicaciones'),
                          Tab(icon: Icon(Icons.reviews_outlined, size: 22), text: 'Reseñas'),
                        ],
                      ),
                    ),
                    pinned: true,
                  ),
                ];
              },
              body: TabBarView(
                controller: _tabController,
                children: [
                  _buildPostsGrid(widget.user_id),
                  _buildReviewsList(context, widget.user_id),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildProfileHeader(UserModel user, ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: theme.colorScheme.surfaceContainerHighest,
                backgroundImage: (user.photoUrl != null && user.photoUrl!.isNotEmpty) ? NetworkImage(user.photoUrl!) : null,
                child: (user.photoUrl == null || user.photoUrl!.isEmpty) ? Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : 'U', style: theme.textTheme.headlineLarge) : null,
              ),
              const SizedBox(width: 16),
              Expanded(child: _buildStats(user, theme)),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  user.displayName,
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  softWrap: true,
                ),
              ),
              const SizedBox(width: 8),
              _buildVerificationBadge(user.esVerificado),
            ],
          ),
          const SizedBox(height: 8),

          // --- MEJORA: Calificación movida debajo del nombre ---
          _buildRatingRow(user, theme),

          if (user.userCategoria != null && user.userCategoria!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(user.userCategoria!,
                  style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.primary,
                      fontWeight: FontWeight.w500)),
            ),
          const SizedBox(height: 16),
          if (user.descripcion != null && user.descripcion!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Text(
                user.descripcion!,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
          _buildActionButtons(theme, user),
        ],
      ),
    );
  }

  // --- MEJORA: Sección de estadísticas simplificada ---
  Widget _buildStats(UserModel user, ThemeData theme) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _PerfilStat(label: 'Trabajos', value: NumberFormat.compact().format(user.trabajos)),
        _PerfilStat(label: 'Seguidores', value: NumberFormat.compact().format(user.followers.length)),
        _PerfilStat(label: 'Siguiendo', value: NumberFormat.compact().format(user.following.length)),
      ],
    );
  }

  // --- MEJORA: Nuevo widget para mostrar la calificación de forma prominente ---
  Widget _buildRatingRow(UserModel user, ThemeData theme) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 22),
        const SizedBox(width: 6),
        Text(
          user.rating.toStringAsFixed(1),
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(width: 6),
        Text(
          '(${NumberFormat.compact().format(user.ratingCount)} reseñas)',
          style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      ],
    );
  }
  
  Widget _buildActionButtons(ThemeData theme, UserModel user) {
    if (_isMyProfile) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (context) => const EditarPerfilPage())),
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Editar Perfil y Configuración'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 10),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      );
    } else {
      return Row(
        children: [
          Expanded(
            flex: 3,
            child: ElevatedButton.icon(
              onPressed: _isLoadingFollow ? null : _toggleFollow,
              icon: _isLoadingFollow
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Icon(
                      _isFollowing
                          ? Icons.check
                          : Icons.person_add_alt_1_outlined,
                      size: 16),
              label: Text(_isFollowing ? 'Siguiendo' : 'Seguir',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                backgroundColor: _isFollowing
                    ? Colors.grey.shade600
                    : theme.colorScheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: OutlinedButton.icon(
              onPressed: _isChatLoading ? null : () => _iniciarChat(user),
              icon: _isChatLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.chat_bubble_outline, size: 16),
              label: const Text('Mensaje', style: TextStyle(fontSize: 13)),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 10),
                side: BorderSide(color: theme.dividerColor),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      );
    }
  }

  Widget _buildPostsGrid(String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('post')
          .where('user_id', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, postSnapshot) {
        if (postSnapshot.hasError) return const Center(child: Text("Error al cargar publicaciones."));
        if (postSnapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (!postSnapshot.hasData || postSnapshot.data!.docs.isEmpty) return const Center(child: Text('Este usuario aún no tiene publicaciones.'));

        final posts = postSnapshot.data!.docs;
        return GridView.builder(
          padding: const EdgeInsets.all(2),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3, crossAxisSpacing: 2, mainAxisSpacing: 2,
          ),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            final postData = post.data() as Map<String, dynamic>;
            final media = postData['media'] as List<dynamic>? ?? [];
            String? thumbnailUrl;
            if (media.isNotEmpty) {
              final firstMedia = media.first;
              if (firstMedia is Map && firstMedia['type'] == 'image') {
                thumbnailUrl = firstMedia['url'];
              }
            }
            
            return GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PostDetallePage(postId: post.id))),
              child: Container(
                color: Colors.grey.shade200,
                child: thumbnailUrl != null
                  ? Image.network(thumbnailUrl, fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) => progress == null ? child : Container(color: Colors.grey.shade200),
                      errorBuilder: (context, error, stack) => const Icon(Icons.broken_image),
                    )
                  : const Icon(Icons.image_not_supported),
              )
            );
          },
        );
      },
    );
  }
  
    Widget _buildReviewsList(BuildContext context, String userId) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('usuarios')
          .doc(userId)
          .collection('resenas')
          .orderBy('timestamp', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
        if (snapshot.hasError) return const Center(child: Text('Error al cargar las reseñas.'));
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Este usuario aún no tiene reseñas.'));

        final reviews = snapshot.data!.docs;
        return ListView.separated(
          padding: const EdgeInsets.all(16.0),
          itemCount: reviews.length,
          separatorBuilder: (context, index) => const Divider(),
          itemBuilder: (context, index) {
            final reviewData = reviews[index].data() as Map<String, dynamic>;
            final comment = reviewData['comment'] as String? ?? '';
            final authorName = reviewData['authorName'] ?? 'Anónimo';
            final timestamp = reviewData['timestamp'] as Timestamp?;
            final date = timestamp != null ? DateFormat('dd/MM/yyyy').format(timestamp.toDate()) : '';

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(authorName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(date, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (comment.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(comment),
                  ]
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVerificationBadge(bool isVerified) {
    return GestureDetector(
      onTap: !isVerified && _isMyProfile ? () {
        Navigator.push(context, MaterialPageRoute(builder: (context) => const VerificacionPage()));
      } : null,
      child: Tooltip(
        message: isVerified ? 'Este proveedor ha sido verificado por Servicly.' : 'Este proveedor no está verificado. Toca para iniciar el proceso.',
        child: Chip(
          avatar: Icon(
            isVerified ? Icons.verified : Icons.gpp_bad_outlined,
            color: isVerified ? Colors.green.shade700 : Colors.orange.shade800,
            size: 18,
          ),
          label: Text(isVerified ? 'Verificado' : 'No Verificado'),
          backgroundColor: isVerified ? Colors.green.shade100 : Colors.orange.shade100,
          labelStyle: TextStyle(
            color: isVerified ? Colors.green.shade800 : Colors.orange.shade800,
            fontWeight: FontWeight.w500,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }
}

// --- WIDGETS AUXILIARES EXTERNOS ---

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate(this.tabBar);

  final TabBar tabBar;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return false;
  }
}


class _PerfilStat extends StatelessWidget {
  final String label;
  final String value;

  const _PerfilStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(value, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 2),
        Text(label, style: theme.textTheme.bodySmall),
      ],
    );
  }
}