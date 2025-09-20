import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/pages/perfil_pagina/perfil_pagina_widget.dart'; // Verifica que la ruta a tu página de perfil sea correcta

/// Un widget que se muestra dentro de un ModalBottomSheet para buscar y listar usuarios.
class SearchResultsSheet extends StatefulWidget {
  final String searchQuery;

  const SearchResultsSheet({
    super.key,
    required this.searchQuery,
  });

  @override
  State<SearchResultsSheet> createState() => _SearchResultsSheetState();
}

class _SearchResultsSheetState extends State<SearchResultsSheet> {
  late Stream<QuerySnapshot> _resultsStream;

  @override
  void initState() {
    super.initState();
    _initiateSearch();
  }

  /// Configura la consulta a Firestore para buscar usuarios por nombre.
  void _initiateSearch() {
    // Esta lógica busca todos los nombres que COMIENCEN con el texto de búsqueda.
    // Es sensible a mayúsculas, por lo que podrías querer guardar una versión en minúsculas del nombre en Firestore.
    String query = widget.searchQuery;
    String endQuery = query.substring(0, query.length - 1) +
        String.fromCharCode(query.codeUnitAt(query.length - 1) + 1);

    _resultsStream = FirebaseFirestore.instance
        .collection('usuarios')
        .where('rol_user', whereIn: ['Proveedor', 'Ambos']) // Busca solo a quienes ofrecen servicios
        .where('display_name', isGreaterThanOrEqualTo: query)
        .where('display_name', isLessThan: endQuery)
        .limit(15) // Limita los resultados a 15 para un mejor rendimiento
        .snapshots(); // .snapshots() escucha cambios en tiempo real
  }

  @override
  Widget build(BuildContext context) {
    // Usamos DraggableScrollableSheet para un modal que se puede arrastrar y expandir.
    return DraggableScrollableSheet(
      initialChildSize: 0.5, // El modal empieza ocupando la mitad de la pantalla
      minChildSize: 0.3,   // Se puede encoger hasta un 30%
      maxChildSize: 0.9,   // Se puede expandir hasta un 90%
      builder: (_, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Indicador visual para que el usuario sepa que puede arrastrar el modal
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10.0),
                child: Text(
                  'Resultados de la Búsqueda',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),

              // Lista de resultados
              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _resultsStream,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (snapshot.hasError) {
                      return const Center(child: Text('Error al realizar la búsqueda.'));
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No se encontraron usuarios para "${widget.searchQuery}".'));
                    }

                    // Si hay resultados, se construye la lista
                    return ListView.builder(
                      controller: scrollController, // Esencial para que el scroll funcione al arrastrar
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        var userData = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                        var userId = snapshot.data!.docs[index].id;
                        
                        final photoUrl = userData['photo_url'] as String?;
                        final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;

                        return ListTile(
                          leading: CircleAvatar(
                            backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            child: !hasPhoto ? const Icon(Icons.person) : null,
                          ),
                          title: Text(userData['display_name'] ?? 'Usuario sin nombre'),
                          subtitle: Text(userData['category'] ?? 'Sin categoría registrada'), // Puedes cambiar 'category' por el campo que prefieras
                          onTap: () {
                            // Al tocar un usuario, se cierra el modal y se navega a su perfil
                            Navigator.pop(context); // Cierra el modal
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => PerfilPaginaWidget(user_id: userId),
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}