import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/Pages/post_detalle/post_detalle_page.dart'; // Asegúrate que esta ruta es correcta
import 'package:servicly_app/widgets/app_background.dart';

class SavedPostsPage extends StatefulWidget {
  const SavedPostsPage({super.key});

  @override
  State<SavedPostsPage> createState() => _SavedPostsPageState();
}

class _SavedPostsPageState extends State<SavedPostsPage> {
  late final Stream<QuerySnapshot> _savedPostsStream;
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;

  @override
  void initState() {
    super.initState();
    if (_currentUserId != null) {
      _savedPostsStream = FirebaseFirestore.instance
          .collection('post')
          .where('bookmark_user', arrayContains: _currentUserId)
          .orderBy('timestamp', descending: true)
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Mis Elementos Guardados'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: colorScheme.onSurface,
        ),
        body: SafeArea(
          child: _currentUserId == null
              ? _buildErrorState('Debes iniciar sesión para ver tus elementos guardados.')
              : StreamBuilder<QuerySnapshot>(
                  stream: _savedPostsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return _buildErrorState('Ocurrió un error al cargar tus posts.');
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return _buildErrorState('Aún no has guardado ninguna publicación.');
                    }

                    final savedDocs = snapshot.data!.docs;

                    // *** Usamos GridView para un diseño más visual ***
                    return GridView.builder(
                      padding: const EdgeInsets.all(12.0),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 200.0, // Ancho máximo de cada elemento
                        mainAxisSpacing: 12.0,
                        crossAxisSpacing: 12.0,
                        childAspectRatio: 1.0, // Proporción 1:1 (cuadrado)
                      ),
                      itemCount: savedDocs.length,
                      itemBuilder: (context, index) {
                        final doc = savedDocs[index];
                        final postData = doc.data() as Map<String, dynamic>;
                        return _buildPostGridItem(context, doc.id, postData);
                      },
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildPostGridItem(BuildContext context, String postId, Map<String, dynamic> postData) {
    final List<dynamic> media = postData['media'] ?? [];
    String? firstImageUrl;
    IconData mediaIcon = Icons.photo_library_outlined; // Icono por defecto

    if (media.isNotEmpty) {
      final firstItem = media.first;
      if (firstItem is Map<String, dynamic> && firstItem['type'] == 'image') {
        firstImageUrl = firstItem['url'];
      }
      
      if (media.length > 1) {
        mediaIcon = Icons.collections_outlined;
      } else if (firstItem is Map<String, dynamic> && firstItem['type'] == 'video') {
        mediaIcon = Icons.play_circle_outline;
      }
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PostDetallePage(postId: postId),
          ),
        );
      },
      child: Card(
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 2,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Imagen de fondo
            if (firstImageUrl != null)
              Image.network(
                firstImageUrl,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, progress) => 
                    progress == null ? child : const Center(child: CircularProgressIndicator()),
                errorBuilder: (context, error, stack) => 
                    const Icon(Icons.broken_image, color: Colors.grey),
              )
            else
              Container(color: Theme.of(context).colorScheme.surfaceContainer, child: const Icon(Icons.image_not_supported, color: Colors.grey)),

            // Gradiente oscuro para legibilidad del ícono
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.black.withAlpha(100), Colors.transparent],
                  begin: Alignment.topRight,
                  end: Alignment.center,
                ),
              ),
            ),

            // Ícono de tipo de media
            Positioned(
              top: 8,
              right: 8,
              child: Icon(mediaIcon, color: Colors.white, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bookmark_border_rounded, size: 60, color: Theme.of(context).colorScheme.onSurface.withAlpha(100)),
          const SizedBox(height: 16),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
      ),
    );
  }
}