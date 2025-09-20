import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/Pages/agenda/agenda_visitas_page.dart';

/// Un widget para mostrar en un Drawer que navega a la agenda de visitas.
/// Muestra una insignia de notificación con el número de visitas confirmadas.
class AgendaDrawerTile extends StatelessWidget {
  final String currentUserId;

  const AgendaDrawerTile({super.key, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    // Usamos un StreamBuilder para escuchar los cambios en las visitas en tiempo real.
    return StreamBuilder<QuerySnapshot>(
      // La consulta es la misma que en la página de la agenda.
      stream: FirebaseFirestore.instance
          .collection('visitas_tecnicas')
          .where('participantIds', arrayContains: currentUserId)
          .where('estado', isEqualTo: 'confirmada')
          .snapshots(),
      builder: (context, snapshot) {
        
        // Mientras carga, muestra una versión deshabilitada del item.
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildDrawerItem(
            context: context,
            icon: Icons.calendar_month_outlined,
            title: 'Mi Agenda',
            subtitle: 'Cargando...',
            onTap: null, // Deshabilitado mientras carga
          );
        }

        // Obtenemos el número de visitas del snapshot.
        final visitCount = snapshot.data?.docs.length ?? 0;
        
        // Construimos el item final con la información del stream.
        return _buildDrawerItem(
          context: context,
          icon: Icons.calendar_month_outlined,
          title: 'Mi Agenda',
          badgeCount: visitCount,
          onTap: () {
            // Cierra el Drawer primero.
            Navigator.of(context).pop(); 
            // Luego navega a la página de la agenda.
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => AgendaVisitasPage(currentUserId: currentUserId),
              ),
            );
          },
        );
      },
    );
  }

  /// Función auxiliar que construye el ListTile, siguiendo un patrón similar
  /// al que mencionaste para mantener la consistencia en tu Drawer.
  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    String? subtitle,
    int badgeCount = 0,
    VoidCallback? onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: badgeCount > 0
          ? Badge(
              label: Text(
                '$badgeCount',
                style: const TextStyle(color: Colors.white),
              ),
              backgroundColor: Theme.of(context).colorScheme.primary,
            )
          : null, // Si no hay visitas, no se muestra nada.
      onTap: onTap,
    );
  }
}

