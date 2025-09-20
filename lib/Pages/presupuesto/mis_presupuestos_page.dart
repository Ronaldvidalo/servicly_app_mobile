import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/models/presupuesto_model.dart';
import 'package:servicly_app/models/solicitud_model.dart';
import 'package:servicly_app/pages/crear_presupuesto/crear_presupuesto_widget.dart';
import 'package:servicly_app/pages/presupuesto/pagina_detalle_presupuesto.dart';


class MisPresupuestosPage extends StatefulWidget {
  const MisPresupuestosPage({super.key});
  @override
  State<MisPresupuestosPage> createState() => _MisPresupuestosPageState();
}

class _MisPresupuestosPageState extends State<MisPresupuestosPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  String _tipoFiltro = 'Todos'; 
  String? _estadoFiltro;

  Future<List<Presupuesto>> _fetchPresupuestos() async {
    if (currentUserId.isEmpty) return [];

    final enviadosQuery = FirebaseFirestore.instance
        .collection('presupuestos')
        .where('realizadoPor', isEqualTo: currentUserId)
        .orderBy('fechaCreacion', descending: true);

    final recibidosQuery = FirebaseFirestore.instance
        .collection('presupuestos')
        .where('userServicio', isEqualTo: currentUserId)
        .where('status', isEqualTo: 'enviado') // Los clientes solo ven presupuestos enviados
        .orderBy('fechaCreacion', descending: true);
    
    List<QuerySnapshot<Map<String, dynamic>>> snapshots;

    if (_tipoFiltro == 'Enviados') {
      snapshots = await Future.wait([enviadosQuery.get()]);
    } else if (_tipoFiltro == 'Recibidos') {
      snapshots = await Future.wait([recibidosQuery.get()]);
    } else {
      snapshots = await Future.wait([enviadosQuery.get(), recibidosQuery.get()]);
    }

    final List<Presupuesto> presupuestos = [];
    for (var snapshot in snapshots) {
      presupuestos.addAll(snapshot.docs.map((doc) => Presupuesto.fromFirestore(doc)));
    }
    
    final ids = <String>{};
    presupuestos.retainWhere((p) => ids.add(p.id));

    presupuestos.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
    
    return presupuestos;
  }


  void _showFilterBottomSheet() {
    String tempTipoFiltro = _tipoFiltro;
    String? tempEstadoFiltro = _estadoFiltro;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Wrap(
                runSpacing: 24.0,
                children: [
                  Text('Filtros', style: Theme.of(context).textTheme.headlineSmall),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Mostrar Presupuestos', style: Theme.of(context).textTheme.titleMedium),
                      RadioListTile<String>(
                        title: const Text('Todos'),
                        value: 'Todos',
                        groupValue: tempTipoFiltro,
                        onChanged: (value) => setModalState(() => tempTipoFiltro = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Enviados'),
                        value: 'Enviados',
                        groupValue: tempTipoFiltro,
                        onChanged: (value) => setModalState(() => tempTipoFiltro = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Recibidos'),
                        value: 'Recibidos',
                        groupValue: tempTipoFiltro,
                        onChanged: (value) => setModalState(() => tempTipoFiltro = value!),
                      ),
                    ],
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtrar por Estado', style: Theme.of(context).textTheme.titleMedium),
                      if (tempTipoFiltro != 'Recibidos')
                        CheckboxListTile(
                          title: const Text('Borradores'),
                          value: tempEstadoFiltro == 'borrador',
                          onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'borrador' : null),
                        ),
                      CheckboxListTile(
                        title: const Text('Pendientes'),
                        value: tempEstadoFiltro == 'PENDIENTE',
                        onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'PENDIENTE' : null),
                      ),
                      CheckboxListTile(
                        title: const Text('Aceptados'),
                        value: tempEstadoFiltro == 'ACEPTADO_POR_CLIENTE',
                        onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'ACEPTADO_POR_CLIENTE' : null),
                      ),
                      CheckboxListTile(
                        title: const Text('Rechazados'),
                        value: tempEstadoFiltro == 'RECHAZADO_POR_CLIENTE',
                        onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'RECHAZADO_POR_CLIENTE' : null),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempTipoFiltro = 'Todos';
                            tempEstadoFiltro = null;
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _tipoFiltro = tempTipoFiltro;
                            _estadoFiltro = tempEstadoFiltro;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Aplicar Filtros'),
                      ),
                    ],
                  )
                ],
              ),
            );
          },
        );
      },
    );
  }

 @override
  Widget build(BuildContext context) {
    String filterText = _tipoFiltro;
    if (_estadoFiltro != null) {
      filterText += ' / ${_estadoFiltro!.toLowerCase().capitalize()}';
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Presupuestos'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _showFilterBottomSheet,
              icon: const Icon(Icons.filter_list),
              label: Text(filterText),
            ),
          ),
        ],
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text('Debes iniciar sesión.'))
          : FutureBuilder<List<Presupuesto>>(
              future: _fetchPresupuestos(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState('No tienes presupuestos.');
                }

                var presupuestos = snapshot.data!;
                
                if (_estadoFiltro != null) {
                  // CAMBIO: Ahora el filtro puede ser para 'status' o 'estado'
                  if (_estadoFiltro == 'borrador') {
                    presupuestos = presupuestos.where((p) => p.status == _estadoFiltro).toList();
                  } else {
                    presupuestos = presupuestos.where((p) => p.estado == _estadoFiltro).toList();
                  }
                }

                if (presupuestos.isEmpty) {
                  return _buildEmptyState('No se encontraron presupuestos con los filtros aplicados.');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: presupuestos.length,
                  itemBuilder: (context, index) {
                    final presupuesto = presupuestos[index];
                    final type = presupuesto.realizadoPor == currentUserId
                        ? PresupuestoCardType.enviado
                        : PresupuestoCardType.recibido;
                    return PresupuestoCard(
                      presupuesto: presupuesto,
                      currentUserId: currentUserId,
                      type: type,
                      tipoFiltroActual: _tipoFiltro,
                    );
                  },
                );
              },
            ),
    );
  }

  Widget _buildEmptyState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_off_outlined, size: 60, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey.shade700),
            ),
          ),
        ],
      ),
    );
  }
}

enum PresupuestoCardType { enviado, recibido }

class PresupuestoCard extends StatelessWidget {
  final Presupuesto presupuesto;
  final String currentUserId;
  final PresupuestoCardType type;
  final String tipoFiltroActual;

  const PresupuestoCard({
    super.key,
    required this.presupuesto,
    required this.currentUserId,
    required this.type,
    required this.tipoFiltroActual,
  });

  Future<DocumentSnapshot<Map<String, dynamic>>> _getOtherUserData() {
    final otherUserId = type == PresupuestoCardType.enviado
        ? presupuesto.userServicio
        : presupuesto.realizadoPor;
    return FirebaseFirestore.instance.collection('usuarios').doc(otherUserId).get();
  }
  
  Color _getStatusColor() {
    if (presupuesto.status == 'borrador') return Colors.grey.shade600;
    
    switch (presupuesto.estado) {
      case 'PENDIENTE': return Colors.orange;
      case 'ACEPTADO_POR_CLIENTE': return Colors.green;
      case 'RECHAZADO_POR_CLIENTE': return Colors.red.shade400;
      case 'CONTRATO_GENERADO': return Colors.purple.shade300;
      default: return Colors.grey;
    }
  }

  Widget _buildStatusChip(ThemeData theme) {
    final color = _getStatusColor();
    String text;
    IconData icon;

    if (presupuesto.status == 'borrador') {
      text = 'Borrador'; 
      icon = Icons.edit_note_outlined;
    } else {
      switch (presupuesto.estado) {
        case 'PENDIENTE': text = 'Pendiente'; icon = Icons.hourglass_empty; break;
        case 'ACEPTADO_POR_CLIENTE': text = 'Aceptado'; icon = Icons.check_circle_outline; break;
        case 'RECHAZADO_POR_CLIENTE': text = 'Rechazado'; icon = Icons.cancel_outlined; break;
        case 'CONTRATO_GENERADO': text = 'Confirmado'; icon = Icons.handshake_outlined; break;
        default: text = presupuesto.estado.toLowerCase().capitalize(); icon = Icons.info_outline;
      }
    }

    return Chip(
      avatar: Icon(icon, color: color, size: 16),
      label: Text(text, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
      backgroundColor: color.withAlpha(40),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
    );
  }

  Future<void> _handleTap(BuildContext context) async {
    // CAMBIO: La lógica ahora se basa en el campo 'status'
    if (presupuesto.status == 'borrador' && presupuesto.realizadoPor == currentUserId) {
      final solicitudDoc = await FirebaseFirestore.instance
          .collection('solicitudes')
          .doc(presupuesto.idSolicitud)
          .get();
      
      if (solicitudDoc.exists && context.mounted) {
        final solicitud = Solicitud.fromFirestore(solicitudDoc);
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => CrearPresupuestoPage(
            solicitud: solicitud,
            presupuestoId: presupuesto.id,
          ),
        ));
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error: No se encontró la solicitud original de este borrador.')),
        );
      }
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (context) => PaginaDetallePresupuesto(
          presupuestoId: presupuesto.id,
          currentUserId: currentUserId,
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final String tituloLimpio = presupuesto.tituloPresupuesto.replaceFirst('Presupuesto para: ', '');
    final statusColor = _getStatusColor();
    final bool esEnviado = type == PresupuestoCardType.enviado;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: statusColor.withAlpha(100)),
      ),
      child: InkWell(
        onTap: () => _handleTap(context),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      tituloLimpio,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (tipoFiltroActual == 'Todos') ...[
                    const SizedBox(width: 8),
                    Icon(esEnviado ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 14, color: theme.textTheme.bodySmall?.color),
                    const SizedBox(width: 4),
                    Text(esEnviado ? 'Enviado' : 'Recibido', style: theme.textTheme.bodySmall),
                  ]
                ],
              ),
              const SizedBox(height: 12),
              FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                future: _getOtherUserData(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const SizedBox(height: 56, child: Center(child: LinearProgressIndicator(minHeight: 2)));
                  }
                  final userData = snapshot.data!.data();
                  final name = userData?['display_name'] ?? 'Usuario';
                  final photoUrl = userData?['photo_url'] ?? '';
                  
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                        child: photoUrl.isEmpty ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(esEnviado ? 'Para:' : 'De:', style: theme.textTheme.labelMedium),
                            Text(name, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        formatter.format(presupuesto.totalFinal),
                        style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ],
                  );
                },
              ),
              Divider(height: 20, color: theme.dividerColor),
              Row(
                children: [
                  _buildStatusChip(theme),
                  const Spacer(),
                  Text(
                    presupuesto.status == 'borrador' ? 'Continuar editando' : 'Ver detalle',
                    style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 4),
                  Icon(Icons.arrow_forward_ios, size: 12, color: theme.colorScheme.primary),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}