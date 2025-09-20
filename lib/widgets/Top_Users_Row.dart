// home_widget.dart > Top_Users_Row.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/pages/perfil_pagina/perfil_pagina_widget.dart';

class TopUsersRow extends StatefulWidget {
  final String searchQuery;
  final String userCountry;

  const TopUsersRow({
    super.key,
    required this.searchQuery,
    required this.userCountry,
  });

  @override
  State<TopUsersRow> createState() => _TopUsersRowState();
}

class _TopUsersRowState extends State<TopUsersRow> {
  // AHORA: Reducimos el tamaño de cada tarjeta para que se vean más.
  final PageController _pageController = PageController(viewportFraction: 0.7);
  Timer? _scrollTimer;
  bool _isTimerInitialized = false;

  @override
  void dispose() {
    _scrollTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _startAutoScroll(int userCount) {
    _scrollTimer?.cancel(); 
    if (userCount > 1) {
      _scrollTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
        if (!mounted || !_pageController.hasClients) return;
        
        int nextPage = _pageController.page!.round() + 1;
        
        _pageController.animateToPage(
          nextPage % userCount,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeInOut,
        );
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    Query query = FirebaseFirestore.instance
        .collection('usuarios')
        .where('pais', isEqualTo: widget.userCountry)
        .where('rol_user', whereIn: ['Proveedor', 'Ambos'])
        .orderBy('rating', descending: true)
        .limit(10);

    // AHORA: Cambiamos la proporción a 16/5 para que sea más bajo y compacto.
    return AspectRatio(
      aspectRatio: 16 / 5,
      child: StreamBuilder<QuerySnapshot>(
        stream: query.snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Text('Error: Revisa la consola para crear un índice de Firestore.', textAlign: TextAlign.center, style: TextStyle(color: theme.colorScheme.error)),
            ));
          }
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text('No hay proveedores destacados en tu país.', style: TextStyle(color: Colors.grey)),
            );
          }

          final topUsers = snapshot.data!.docs;

          if (!_isTimerInitialized && topUsers.isNotEmpty) {
            _isTimerInitialized = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                _startAutoScroll(topUsers.length);
              }
            });
          }

          return PageView.builder(
            controller: _pageController,
            itemCount: topUsers.length,
            itemBuilder: (context, index) {
              final userDoc = topUsers[index];
              return _buildUserCard(userDoc, theme);
            },
          );
        },
      ),
    );
  }

  Widget _buildUserCard(DocumentSnapshot userDoc, ThemeData theme) {
    final user = userDoc.data() as Map<String, dynamic>;
    final userId = userDoc.id;
    final rating = (user['rating'] ?? 0.0).toDouble();
    final photoUrl = user['photo_url'] as String?;
    final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
    final displayName = user['display_name'] ?? 'Usuario';

    String finalCategory = 'Sin categoría';
    if (user.containsKey('userCategorias') && user['userCategorias'] is List) {
      final List<dynamic> categorias = user['userCategorias'];
      if (categorias.isNotEmpty) {
        finalCategory = categorias.first.toString();
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0, vertical: 8.0),
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PerfilPaginaWidget(user_id: userId),
            ),
          );
        },
        borderRadius: BorderRadius.circular(16.0),
        child: Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          elevation: 4,
          shadowColor: Colors.black.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 28, // <-- Un poco más pequeño para que entre mejor
                  backgroundColor: theme.colorScheme.surfaceContainerHighest,
                  backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                  child: !hasPhoto ? Icon(Icons.person, size: 28, color: theme.colorScheme.onSurfaceVariant) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        finalCategory,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, color: theme.colorScheme.primary),
                      ),
                      const Spacer(),
                      _buildCompactRating(rating, theme),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompactRating(double rating, ThemeData theme) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 16),
        const SizedBox(width: 4),
        Text(
          rating.toStringAsFixed(1),
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}