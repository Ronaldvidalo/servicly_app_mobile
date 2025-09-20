import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:servicly_app/pages/chat/chat_page.dart';

class PaginaBusquedaContactos extends StatefulWidget {
  const PaginaBusquedaContactos({super.key});

  @override
  State<PaginaBusquedaContactos> createState() => _PaginaBusquedaContactosState();
}

class _PaginaBusquedaContactosState extends State<PaginaBusquedaContactos> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  List<String> _followingIds = [];
  bool _isLoadingFollowing = true;

  @override
  void initState() {
    super.initState();
    _getFollowingList();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim();
      });
    });
  }
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _getFollowingList() async {
    if (_currentUserId.isEmpty) {
      setState(() => _isLoadingFollowing = false);
      return;
    }
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(_currentUserId).get();
    if (userDoc.exists && userDoc.data()!.containsKey('following')) {
      setState(() {
        _followingIds = List<String>.from(userDoc.data()!['following']);
        _isLoadingFollowing = false;
      });
    } else {
      setState(() => _isLoadingFollowing = false);
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _getStream() {
    if (_searchQuery.isEmpty) {
      // Si no hay búsqueda, muestra los usuarios que seguimos
      if (_followingIds.isEmpty) {
        return const Stream.empty();
      }
      return FirebaseFirestore.instance
          .collection('usuarios')
          .where(FieldPath.documentId, whereIn: _followingIds)
          .snapshots();
    } else {
      // Si hay búsqueda, busca por nombre
      return FirebaseFirestore.instance
          .collection('usuarios')
          .where('display_name', isGreaterThanOrEqualTo: _searchQuery)
          .where('display_name', isLessThanOrEqualTo: '$_searchQuery\uf8ff')
          .limit(10) // Limitamos para no traer demasiados resultados
          .snapshots();
    }
  }
  
  Future<void> _iniciarChat(String otroUsuarioId, Map<String, dynamic> otroUsuarioData) async {
    try {
      final functions = FirebaseFunctions.instanceFor(region: 'southamerica-east1');
      final callable = functions.httpsCallable('getOrCreateChat');
      final response = await callable.call({'otherUserId': otroUsuarioId});
      final chatId = response.data['chatId'];

      if (!mounted) return;
      
      Navigator.of(context).pop(); 
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => PaginaChatDetalle(
          chatId: chatId,
          nombreOtroUsuario: otroUsuarioData['display_name'] ?? 'Usuario',
          fotoUrlOtroUsuario: otroUsuarioData['photo_url'],
        ),
      ));
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al iniciar el chat: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      // Usamos el 0% de la altura de la pantalla para dar espacio y evitar el teclado
      height: MediaQuery.of(context).size.height * 0.6,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          // Barra de Búsqueda
          TextField(
            controller: _searchController,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Buscar profesional por nombre...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
            ),
          ),
          const SizedBox(height: 16),

          // Título dinámico
          Text(
            _searchQuery.isEmpty ? 'Contactos que sigues' : 'Resultados de la búsqueda',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const Divider(),

          // Lista de Usuarios
          Expanded(
            child: _isLoadingFollowing
                ? const Center(child: CircularProgressIndicator())
                : StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream: _getStream(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                        return Center(child: Text(_searchQuery.isEmpty ? 'Aún no sigues a nadie.' : 'No se encontraron usuarios.'));
                      }

                      final userDocs = snapshot.data!.docs;

                      return ListView.builder(
                        itemCount: userDocs.length,
                        itemBuilder: (context, index) {
                          final userData = userDocs[index].data();
                          final userId = userDocs[index].id;
                          
                          if (userId == _currentUserId) return const SizedBox.shrink();

                          final photoUrl = userData['photo_url'] as String?;
                          final displayName = userData['display_name'] ?? 'Usuario';
                          
                          String categoriaToShow = 'Cliente';
                          if (userData.containsKey('userCategorias') && (userData['userCategorias'] as List).isNotEmpty) {
                             final List<dynamic> categorias = userData['userCategorias'];
                             categoriaToShow = categorias.first.toString();
                          }

                          return ListTile(
                            leading: CircleAvatar(
                              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                              child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person) : null,
                            ),
                            title: Text(displayName),
                            subtitle: Text(
                              categoriaToShow,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                            ),
                            onTap: () => _iniciarChat(userId, userData),
                          );
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}