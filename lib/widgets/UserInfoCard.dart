import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Importamos la página de perfil a la que vamos a navegar
import 'package:servicly_app/Pages/perfil_pagina/perfil_pagina_widget.dart';

class UserInfoCard extends StatelessWidget {
  final DocumentReference userRef;

  const UserInfoCard({super.key, required this.userRef});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // FutureBuilder es perfecto para cargar datos de un documento una sola vez
    return FutureBuilder<DocumentSnapshot>(
      future: userRef.get(),
      builder: (context, snapshot) {
        // Mientras carga, muestra una tarjeta de esqueleto
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: theme.dividerColor),
            ),
            child: const ListTile(
              leading: CircleAvatar(radius: 30),
              title: Text("Cargando usuario..."),
            ),
          );
        }
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Card(
            child: ListTile(
              leading: Icon(Icons.error),
              title: Text('No se encontró al usuario.')
            ),
          );
        }

        // Una vez que tenemos los datos, los casteamos a un Mapa
        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final userName = userData['display_name'] ?? 'Usuario Anónimo';
        final userAvatarUrl = userData['photo_url'];

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: theme.dividerColor),
          ),
          clipBehavior: Clip.antiAlias, // Para que el InkWell respete los bordes
          child: InkWell(
            // --- INICIO DE LA MEJORA: NAVEGACIÓN ---
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  // Navegamos a la página de perfil pasándole el ID de este usuario
                  builder: (context) => PerfilPaginaWidget(user_id: userRef.id),
                ),
              );
            },
            // --- FIN DE LA MEJORA ---
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    backgroundImage: userAvatarUrl != null ? NetworkImage(userAvatarUrl) : null,
                    child: userAvatarUrl == null
                        ? const Icon(Icons.person, size: 30)
                        : null,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Solicitado por", style: theme.textTheme.bodySmall),
                        Text(
                          userName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        // Ranking de ejemplo
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              "4.8 (12 reseñas)", // Este dato debería venir de la BD en el futuro
                              style: theme.textTheme.bodySmall,
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: theme.colorScheme.onSurface.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
