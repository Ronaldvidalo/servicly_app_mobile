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
  // Stream para manejar los resultados de la búsqueda en tiempo real
  Stream<QuerySnapshot<Map<String, dynamic>>> _searchResultsStream = Stream.empty();
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  void initState() {
    super.initState();
    // El listener ahora actualiza el stream directamente
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// ✅ Lógica de Búsqueda Optimizada
  /// Se activa cada vez que el texto en el buscador cambia.
  void _onSearchChanged() {
    // Convierte el término de búsqueda a minúsculas para coincidir con `search_keywords`
    final searchTerm = _searchController.text.trim().toLowerCase();
    
    setState(() {
      if (searchTerm.isEmpty) {
        // Si no hay texto, el stream se vacía para no mostrar resultados
        _searchResultsStream = Stream.empty();
      } else {
        // Crea un nuevo stream con la consulta optimizada usando 'arrayContains'
        _searchResultsStream = FirebaseFirestore.instance
            .collection('usuarios')
            .where('search_keywords', arrayContains: searchTerm)
            .limit(15) // Limita los resultados para eficiencia
            .snapshots();
      }
    });
  }

  /// ✅ Lógica para obtener la lista de contactos seguidos.
  /// Devuelve un Future, ideal para usar con un FutureBuilder.
  Future<List<DocumentSnapshot>> _getFollowedContacts() async {
    if (_currentUserId.isEmpty) return [];

    // 1. Obtiene el documento del usuario actual
    final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(_currentUserId).get();
    
    // 2. Extrae la lista de IDs.
    // ⚠️ ¡IMPORTANTE! Asegúrate que tu campo en Firestore se llame 'following_ids'
    final List<dynamic> followedIds = userDoc.data()?['following_ids'] ?? [];

    if (followedIds.isEmpty) return [];

    // 3. Busca los perfiles completos de los usuarios seguidos
    final followedUsersQuery = await FirebaseFirestore.instance
        .collection('usuarios')
        .where(FieldPath.documentId, whereIn: followedIds)
        .get();
        
    return followedUsersQuery.docs;
  }

  /// Función para iniciar el chat (sin cambios, ya estaba bien)
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
      // Se ajusta la altura para dar más espacio
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.only(top: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- SECCIÓN 1: BARRA DE BÚSQUEDA ---
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: TextField(
              controller: _searchController,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre o categoría...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                filled: true,
                fillColor: Theme.of(context).colorScheme.surfaceVariant,
              ),
            ),
          ),
          
          // --- SECCIÓN 2: RESULTADOS DE BÚSQUEDA ---
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: _searchResultsStream,
              builder: (context, snapshot) {
                if (_searchController.text.trim().isEmpty) {
                  return const Center(child: Text('Busca profesionales por su nombre o servicio.'));
                }
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No se encontraron resultados.'));
                }

                final userDocs = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: userDocs.length,
                  itemBuilder: (context, index) {
                    final userData = userDocs[index].data();
                    final userId = userDocs[index].id;
                    if (userId == _currentUserId) return const SizedBox.shrink();
                    return _buildUserListItem(userId, userData);
                  },
                );
              },
            ),
          ),
          
          // --- SECCIÓN 3: CONTACTOS SEGUIDOS ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text('Mis Contactos', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          ),
          SizedBox(
            height: 120, // Altura fija para la lista horizontal
            child: FutureBuilder<List<DocumentSnapshot>>(
              future: _getFollowedContacts(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(child: Text('Aún no sigues a nadie.'));
                }
                final followedDocs = snapshot.data!;
                return ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: followedDocs.length,
                  itemBuilder: (context, index) {
                    final userData = followedDocs[index].data() as Map<String, dynamic>;
                    final userId = followedDocs[index].id;
                    return _buildFollowedContactItem(userId, userData);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Widget para mostrar un item en la lista de resultados de búsqueda
  Widget _buildUserListItem(String userId, Map<String, dynamic> userData) {
    final photoUrl = userData['photo_url'] as String?;
    final displayName = userData['display_name'] ?? 'Usuario';
    String subtitle = 'Cliente';
    if (userData.containsKey('userCategorias') && (userData['userCategorias'] as List).isNotEmpty) {
      subtitle = (userData['userCategorias'] as List).first.toString();
    }

    return ListTile(
      leading: CircleAvatar(
        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person) : null,
      ),
      title: Text(displayName),
      subtitle: Text(
        subtitle,
        style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
      ),
      onTap: () => _iniciarChat(userId, userData),
    );
  }

  /// Widget para mostrar un item en la lista horizontal de contactos seguidos
  Widget _buildFollowedContactItem(String userId, Map<String, dynamic> userData) {
    final photoUrl = userData['photo_url'] as String?;
    final displayName = userData['display_name'] ?? 'Usuario';
    return GestureDetector(
      onTap: () => _iniciarChat(userId, userData),
      child: Container(
        width: 80,
        margin: const EdgeInsets.symmetric(horizontal: 4),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
              child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 30) : null,
            ),
            const SizedBox(height: 8),
            Text(
              displayName,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
