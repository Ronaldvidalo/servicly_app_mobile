import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/models/solicitud_model.dart';
import 'package:servicly_app/pages/detalle_solicitud/detalle_solicitud_servicio_widget.dart';

class MisSolicitudesPage extends StatefulWidget {
  const MisSolicitudesPage({super.key});

  @override
  State<MisSolicitudesPage> createState() => _MisSolicitudesPageState();
}

class _MisSolicitudesPageState extends State<MisSolicitudesPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  // AHORA: Los filtros se manejan con estas dos variables de estado.
  String _tipoFiltro = 'Todas'; // 'Todas', 'Creadas', 'Participando'
  String? _estadoFiltro;

Future<List<Solicitud>> _fetchSolicitudes() async {
  if (currentUserId.isEmpty) return [];

  // 1. Añadimos .orderBy() para que Firestore ordene los resultados por fecha de creación.
  final creadasQuery = FirebaseFirestore.instance
      .collection('solicitudes')
      .where('user_id', isEqualTo: currentUserId)
      .orderBy('fechaCreacion', descending: true); // <-- AÑADIDO

  final participoQuery = FirebaseFirestore.instance
      .collection('solicitudes')
      .where('proveedoresParticipantes', arrayContains: currentUserId)
      .orderBy('fechaCreacion', descending: true); // <-- AÑADIDO
  
  List<QuerySnapshot<Map<String, dynamic>>> snapshots = [];

  // El resto de la lógica para obtener los datos no cambia.
  if (_tipoFiltro == 'Creadas') {
    snapshots.add(await creadasQuery.get());
  } else if (_tipoFiltro == 'Participando') {
    snapshots.add(await participoQuery.get());
  } else { // 'Todas'
    snapshots = await Future.wait([creadasQuery.get(), participoQuery.get()]);
  }

  // Usamos un Map para combinar y eliminar duplicados automáticamente.
  final Map<String, Solicitud> combinedSolicitudes = {};
  for (var snapshot in snapshots) {
    for (var doc in snapshot.docs) {
      combinedSolicitudes[doc.id] = Solicitud.fromFirestore(doc);
    }
  }

  var sortedList = combinedSolicitudes.values.toList();
  
  // 2. La ordenación en el cliente ahora es solo un paso final de unificación.
  // La mayor parte del trabajo ya la hizo Firestore.
  sortedList.sort((a, b) => b.fechaCreacion.compareTo(a.fechaCreacion));
  
  return sortedList;
}
  
  // AHORA: Nueva función que muestra el panel de filtros vertical.
  void _showFilterBottomSheet() {
    String tempTipoFiltro = _tipoFiltro;
    String? tempEstadoFiltro = _estadoFiltro;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24.0)),
      ),
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
                      Text('Mostrar Solicitudes', style: Theme.of(context).textTheme.titleMedium),
                      RadioListTile<String>(
                        title: const Text('Todas'),
                        value: 'Todas',
                        groupValue: tempTipoFiltro,
                        onChanged: (value) => setModalState(() => tempTipoFiltro = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Creadas por mí'),
                        value: 'Creadas',
                        groupValue: tempTipoFiltro,
                        onChanged: (value) => setModalState(() => tempTipoFiltro = value!),
                      ),
                      RadioListTile<String>(
                        title: const Text('Donde participo'),
                        value: 'Participando',
                        groupValue: tempTipoFiltro,
                        onChanged: (value) => setModalState(() => tempTipoFiltro = value!),
                      ),
                    ],
                  ),
                  
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtrar por Estado', style: Theme.of(context).textTheme.titleMedium),
                      CheckboxListTile(
                        title: const Text('Activas'),
                        value: tempEstadoFiltro == 'Activa',
                        onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'Activa' : null),
                      ),
                      CheckboxListTile(
                        title: const Text('En Proceso'),
                        value: tempEstadoFiltro == 'En Proceso',
                        onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'En Proceso' : null),
                      ),
                      CheckboxListTile(
                        title: const Text('Finalizadas'),
                        value: tempEstadoFiltro == 'Finalizada',
                        onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'Finalizada' : null),
                      ),
                      CheckboxListTile(
                        title: const Text('Canceladas'),
                        value: tempEstadoFiltro == 'Cancelada',
                        onChanged: (selected) => setModalState(() => tempEstadoFiltro = selected! ? 'Cancelada' : null),
                      ),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempTipoFiltro = 'Todas';
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
        title: const Text("Mis Solicitudes"),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _showFilterBottomSheet,
              icon: const Icon(Icons.filter_list),
              label: Text(filterText),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text("Debes iniciar sesión."))
          : FutureBuilder<List<Solicitud>>(
              future: _fetchSolicitudes(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text("Error: ${snapshot.error}"));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState('No tienes solicitudes.');
                }

                var solicitudes = snapshot.data!;
                
                if (_estadoFiltro != null) {
                  solicitudes = solicitudes.where((s) => s.status == _estadoFiltro).toList();
                }

                if (solicitudes.isEmpty) {
                  return _buildEmptyState('No se encontraron solicitudes con los filtros aplicados.');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: solicitudes.length,
                  itemBuilder: (context, index) {
                    final solicitud = solicitudes[index];
                    return SolicitudCard(
                      solicitud: solicitud,
                      currentUserId: currentUserId,
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
          Icon(Icons.file_copy_outlined, size: 60, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }
}

// El widget de la tarjeta de solicitud no necesita cambios.
class SolicitudCard extends StatelessWidget {
  final Solicitud solicitud;
  final String currentUserId;

  const SolicitudCard({super.key, required this.solicitud, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool esMiSolicitud = solicitud.user_id == currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.0),
        side: BorderSide(color: theme.dividerColor, width: 0.8),
      ),
      elevation: 1,
      child: InkWell(
        onTap: () {
          Navigator.push(context, MaterialPageRoute(
            builder: (context) => DetalleSolicitudWidget(solicitud: solicitud),
          ));
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      solicitud.titulo,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildStatusChip(solicitud.status, theme),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                solicitud.categoria,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary),
              ),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTypeIndicator(esMiSolicitud, theme),
                  _buildBudgetCount(solicitud.presupuestosCount, theme),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String status, ThemeData theme) {
    Color color;
    switch (status) {
      case 'Activa': color = Colors.orange; break;
      case 'En Proceso': color = Colors.blue; break;
      case 'Finalizada': color = Colors.green; break;
      case 'Cancelada': color = Colors.red.shade400; break;
      default: color = Colors.grey;
    }
    return Chip(
      label: Text(status, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
      backgroundColor: color.withAlpha(38),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildTypeIndicator(bool esMiSolicitud, ThemeData theme) {
    final icon = esMiSolicitud ? Icons.person : Icons.handyman;
    final text = esMiSolicitud ? 'Mi Solicitud' : 'Participando';
    final color = esMiSolicitud ? Colors.green.shade700 : Colors.blue.shade700;
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: theme.textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildBudgetCount(int count, ThemeData theme) {
    return Row(
      children: [
        Text('$count', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(width: 6),
        Text('Presupuestos', style: theme.textTheme.bodySmall),
        const SizedBox(width: 4),
        const Icon(Icons.arrow_forward_ios, size: 12),
      ],
    );
  }
}

extension StringExtension on String {
    String capitalize() {
      if (isEmpty) return this;
      return "${this[0].toUpperCase()}${substring(1).toLowerCase()}";
    }
}