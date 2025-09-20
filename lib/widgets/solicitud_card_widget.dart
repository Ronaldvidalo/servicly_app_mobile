// lib/widgets/solicitud_card_widget.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/models/solicitud_model.dart';
import 'package:servicly_app/Pages/detalle_solicitud/detalle_solicitud_servicio_widget.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:share_plus/share_plus.dart'; // <-- IMPORT AÑADIDO

class SolicitudCardWidget extends StatelessWidget {
  final Solicitud solicitud;
  final String currentUserId;

  const SolicitudCardWidget({
    super.key,
    required this.solicitud,
    required this.currentUserId,
  });

  // --- NUEVA FUNCIÓN PARA COMPARTIR ---
  void _compartirSolicitud() {
    final solicitudId = solicitud.id; 
    final titulo = solicitud.titulo;

    final String url = "https://serviclyapp-44213.web.app/service?id=$solicitudId";
    final String texto = "¡Mirá esta solicitud de servicio en Servicly!\n\n\"$titulo\"\n\n$url";

    Share.share(texto);
  }

  @override
  Widget build(BuildContext context) {
    // Aquí se ha corregido para usar 'userId' según el modelo que ajustamos
    if (solicitud.user_id.isEmpty) { 
      return _buildCard(context, autorNombre: 'Usuario Anónimo', autorFotoUrl: '');
    }

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(solicitud.user_id).get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingCardSkeleton();
        }

        final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
        final autorNombre = userData['display_name'] ?? 'Usuario Anónimo';
        final autorFotoUrl = userData['photo_url'] ?? '';

        return _buildCard(context, autorNombre: autorNombre, autorFotoUrl: autorFotoUrl);
      },
    );
  }

  Widget _buildCard(BuildContext context, {required String autorNombre, required String autorFotoUrl}) {
    final theme = Theme.of(context);
    timeago.setLocaleMessages('es', timeago.EsMessages());
    final timeAgo = timeago.format(solicitud.fechaCreacion.toDate(), locale: 'es');
    
    final bool estaDisponible = solicitud.status == 'Activa';
    final String categoria = solicitud.categoria;
    final String ubicacion = [solicitud.municipio, solicitud.provincia]
        .where((s) => s != null && s.isNotEmpty)
        .join(', ');

    return Card(
      elevation: 2,
      shadowColor: theme.colorScheme.shadow.withAlpha(20),
      color: theme.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          InkWell(
            onTap: () {
              if (estaDisponible) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DetalleSolicitudWidget(solicitud: solicitud),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Esta solicitud ya no está disponible.'),
                    backgroundColor: Colors.orange.shade800,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    margin: const EdgeInsets.all(10),
                  ),
                );
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: theme.colorScheme.surfaceContainerHighest,
                        backgroundImage: autorFotoUrl.isNotEmpty ? NetworkImage(autorFotoUrl) : null,
                        child: autorFotoUrl.isEmpty ? Icon(Icons.person, size: 24, color: theme.colorScheme.onSurfaceVariant) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              autorNombre,
                              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (ubicacion.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14, color: Colors.grey.shade600),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      ubicacion,
                                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      _buildStatusBadge(theme, solicitud.status),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    solicitud.titulo,
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (solicitud.descripcion.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      solicitud.descripcion,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withAlpha(179)),
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withAlpha(128),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sell_outlined, size: 14, color: theme.colorScheme.onPrimaryContainer),
                            const SizedBox(width: 6),
                            Text(
                              categoria,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onPrimaryContainer,
                                fontWeight: FontWeight.bold
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      
                      // --- BOTÓN DE COMPARTIR AÑADIDO ---
                      IconButton(
                        icon: const Icon(Icons.share_outlined),
                        onPressed: _compartirSolicitud,
                        tooltip: 'Compartir Solicitud',
                        color: Colors.grey.shade600,
                      ),

                      Text(
                        timeAgo,
                        style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          if (!estaDisponible)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.lock_outline, color: Colors.white, size: 40),
                      SizedBox(height: 8),
                      Text(
                        'NO DISPONIBLE',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(ThemeData theme, String estado) {
    final String texto;
    final Color color;
    switch (estado) {
      case 'Activa':
        texto = 'Disponible';
        color = Colors.green;
        break;
      case 'contratada':
        texto = 'Contratado';
        color = Colors.orange.shade700;
        break;
      case 'finalizada':
        texto = 'Finalizado';
        color = Colors.grey.shade600;
        break;
      default:
        texto = estado.toUpperCase();
        color = Colors.blueGrey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(40),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        texto,
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _LoadingCardSkeleton extends StatelessWidget {
  const _LoadingCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(radius: 20, backgroundColor: Colors.grey.shade200),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(width: 120, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                    const SizedBox(height: 6),
                    Container(width: 80, height: 12, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
                  ],
                )
              ],
            ),
            const SizedBox(height: 16),
            Container(height: 20, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 8),
            Container(width: 250, height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 6),
            Container(width: 200, height: 16, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
            const SizedBox(height: 16),
              Row(
              children: [
                Container(width: 100, height: 24, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(20))),
                const Spacer(),
                Container(width: 60, height: 14, decoration: BoxDecoration(color: Colors.grey.shade200, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}