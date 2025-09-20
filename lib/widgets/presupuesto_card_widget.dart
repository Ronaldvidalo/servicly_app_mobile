import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/models/presupuesto_model.dart';
import 'package:servicly_app/pages/presupuesto/pagina_detalle_presupuesto.dart';
import 'package:servicly_app/widgets/rating_stars_widget.dart';

class PresupuestoCard extends StatelessWidget {
  final Presupuesto presupuesto;
  final String currentUserId;

  const PresupuestoCard({
    super.key,
    required this.presupuesto,
    required this.currentUserId,
  });

  // --- NAVEGACIÓN A LA PÁGINA DE DETALLE ---
  void _navegarADetalle(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaginaDetallePresupuesto(
          presupuestoId: presupuesto.id,
          currentUserId: currentUserId,
        ),
      ),
    );
  }

  // --- MODAL PARA MOSTRAR RESEÑAS ---
  void _mostrarResenas(BuildContext context, String providerId) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _ResenasModal(providerId: providerId),
    );
  }
  
  // --- FUNCIÓN CENTRALIZADA PARA LA INFO DE LOS ESTADOS ---
  (String, String, Color, IconData) _getStatusInfo(BuildContext context) {
    final bool esCliente = currentUserId == presupuesto.userServicio;
    
    switch (presupuesto.estado) {
      case 'PENDIENTE':
        return esCliente
            ? ("Esperando tu respuesta", "Revisá y aceptá la oferta.", Colors.blue, Icons.hourglass_top_rounded)
            : ("Presupuesto enviado", "Esperando respuesta del cliente.", Colors.blue, Icons.hourglass_top_rounded);
      case 'ACEPTADO_POR_CLIENTE':
        return esCliente
            ? ("Aceptado", "El proveedor debe confirmar para iniciar.", Colors.orange, Icons.check_circle_outline_rounded)
            : ("¡Aceptado por el cliente!", "Confirmá el trabajo para comenzar.", Colors.orange, Icons.check_circle_outline_rounded);
      case 'RECHAZADO_POR_CLIENTE':
        return ("Rechazado", "El cliente ha rechazado esta oferta.", Colors.red, Icons.cancel_rounded);
      case 'CANCELADO_POR_PROVEEDOR':
        return ("Cancelado", "El proveedor no puede realizar el trabajo.", Colors.grey, Icons.do_not_disturb_on_rounded);
      case 'CONTRATO_GENERADO':
        return ("Trabajo Confirmado", "El servicio está listo para comenzar.", Colors.green, Icons.handshake_rounded);
      default:
        return ("Estado desconocido", "Consultá los detalles.", Colors.grey, Icons.help_outline_rounded);
    }
  }

  @override
  Widget build(BuildContext context) {
    final esMiPresupuestoEnviado = presupuesto.realizadoPor == currentUserId;
    final otherUserId = esMiPresupuestoEnviado ? presupuesto.userServicio : presupuesto.realizadoPor;
    final (statusTitle, _, statusColor, _) = _getStatusInfo(context);

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(otherUserId).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Card(child: ListTile(title: Text('Cargando...')));
        }
        
        final userData = snapshot.data!.data() as Map<String, dynamic>? ?? {};
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12.0),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: statusColor, width: 1.5),
            borderRadius: BorderRadius.circular(16.0),
          ),
          child: InkWell(
            onTap: () => _navegarADetalle(context),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildStatusChip(statusTitle, statusColor),
                  const SizedBox(height: 12),
                  _buildUserHeader(context, esMiPresupuestoEnviado, userData),
                  const Divider(height: 24),
                  _buildCardBody(context),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String title, Color color) {
    return Chip(
      label: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      backgroundColor: color,
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildCardBody(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final (title, subtitle, color, icon) = _getStatusInfo(context);

    if (presupuesto.estado == 'PENDIENTE' && currentUserId == presupuesto.userServicio) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Monto Total:', style: TextStyle(fontSize: 16)),
            Text(
              formatter.format(presupuesto.totalFinal),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
          ],
        );
    }

    return Row(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: color),
              ),
              if (subtitle.isNotEmpty)
                Text(
                  subtitle,
                  // CORRECCIÓN 2: Se reemplaza .withOpacity() por .withAlpha()
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color.withAlpha(204)), // 204 es ~80% de opacidad
                )
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Colors.grey),
      ],
    );
  }

  Widget _buildUserHeader(BuildContext context, bool esMiPresupuestoEnviado, Map<String, dynamic> userData) {
    final photoUrl = userData['photo_url'] as String? ?? '';
    final displayName = userData['display_name'] ?? (esMiPresupuestoEnviado ? 'Cliente' : 'Proveedor');
    final label = esMiPresupuestoEnviado ? 'Para:' : 'De:';

    return Row(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
          child: photoUrl.isEmpty ? const Icon(Icons.person, size: 24) : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.bodySmall),
              Text(displayName, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              if (!esMiPresupuestoEnviado) ...[
                const SizedBox(height: 4),
                InkWell(
                  onTap: () => _mostrarResenas(context, presupuesto.realizadoPor),
                  child: Text('Ver Comentarios', style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                )
              ]
            ],
          ),
        ),
        if (!esMiPresupuestoEnviado)
          RatingStars(
            rating: (userData['rating'] ?? 0.0).toDouble(),
            ratingCount: userData['ratingCount'] ?? 0,
            starSize: 18,
          ),
      ],
    );
  }
}

class _ResenasModal extends StatelessWidget {
  final String providerId;
  const _ResenasModal({required this.providerId});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text("Reseñas del Proveedor", style: Theme.of(context).textTheme.titleLarge),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('usuarios')
                  .doc(providerId)
                  .collection('resenas')
                  .orderBy('fecha', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Este proveedor aún no tiene reseñas.'));
                }
                final resenas = snapshot.data!.docs;
                return ListView.builder(
                  itemCount: resenas.length,
                  itemBuilder: (context, index) {
                    final resenaData = resenas[index].data() as Map<String, dynamic>;
                    final rating = (resenaData['calificacion'] ?? 0.0).toDouble();
                    
                    return ListTile(
                      title: Text(resenaData['comentario'] ?? ''),
                      subtitle: RatingStars(
                        rating: rating,
                        ratingCount: 0,
                        // CORRECCIÓN 1: Se elimina el parámetro 'showRatingCount' que no existe.
                        starSize: 16,
                      ),
                      leading: CircleAvatar(
                        child: Text(rating.toStringAsFixed(0)),
                      ),
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