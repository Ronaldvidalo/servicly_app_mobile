// lib/pages/contrato/mis_contratos_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/models/contrato_model.dart';
import 'package:servicly_app/widgets/contrato_card.dart'; // Asegúrate que la ruta sea correcta
import 'package:rxdart/rxdart.dart';

class MisContratosPage extends StatefulWidget {
  const MisContratosPage({super.key});
  @override
  State<MisContratosPage> createState() => _MisContratosPageState();
}

class _MisContratosPageState extends State<MisContratosPage> {
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  
  String? _estadoFiltro; // Filtro para "En Progreso", "Completados", etc.

  // Busca contratos donde el usuario es cliente o proveedor
  Stream<List<ContratoResumen>> _fetchContratosStream() {
    if (currentUserId.isEmpty) return Stream.value([]);

    final clienteQuery = FirebaseFirestore.instance
        .collection('contratos')
        .where('clienteId', isEqualTo: currentUserId)
        .orderBy('fechaConfirmacion', descending: true);

    final proveedorQuery = FirebaseFirestore.instance
        .collection('contratos')
        .where('proveedorId', isEqualTo: currentUserId)
        .orderBy('fechaConfirmacion', descending: true);

    return Rx.combineLatest2(
      clienteQuery.snapshots(),
      proveedorQuery.snapshots(),
      (QuerySnapshot<Map<String, dynamic>> clienteSnap, QuerySnapshot<Map<String, dynamic>> proveedorSnap) {
        
        final contratosMap = <String, ContratoResumen>{}; // Usamos un Map para evitar duplicados fácilmente
        
        for (var doc in clienteSnap.docs) {
          contratosMap[doc.id] = ContratoResumen.fromFirestore(doc);
        }
        for (var doc in proveedorSnap.docs) {
          contratosMap[doc.id] = ContratoResumen.fromFirestore(doc);
        }
        
        final sortedList = contratosMap.values.toList();
        
        sortedList.sort((a, b) => b.fechaConfirmacion.compareTo(a.fechaConfirmacion));
        
        return sortedList;
      },
    );
  }
  
  void _showFilterBottomSheet() {
    String? tempEstadoFiltro = _estadoFiltro;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            
            Widget buildRadioTile(String title, String? value) {
              return RadioListTile<String?>(
                title: Text(title),
                value: value,
                groupValue: tempEstadoFiltro,
                onChanged: (newValue) {
                  setModalState(() {
                    tempEstadoFiltro = newValue;
                  });
                },
              );
            }

            return Container(
              padding: const EdgeInsets.all(24.0),
              child: Wrap(
                runSpacing: 24.0,
                children: [
                  Text('Filtrar Contratos', style: Theme.of(context).textTheme.headlineSmall),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Filtrar por Estado', style: Theme.of(context).textTheme.titleMedium),
                      buildRadioTile('Todos', null),
                      buildRadioTile('Por Iniciar', 'POR_INICIAR'),
                      buildRadioTile('En Progreso', 'EN_PROGRESO'),
                      buildRadioTile('Completados', 'COMPLETADOS'),
                    ],
                  ),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: () {
                          setModalState(() {
                            tempEstadoFiltro = null;
                          });
                        },
                        child: const Text('Limpiar'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          setState(() {
                            _estadoFiltro = tempEstadoFiltro;
                          });
                          Navigator.pop(context);
                        },
                        child: const Text('Aplicar Filtro'),
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Contratos'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton.icon(
              onPressed: _showFilterBottomSheet,
              icon: const Icon(Icons.filter_list),
              label: Text(_estadoFiltro ?? 'Todos'),
            ),
          ),
        ],
      ),
      body: currentUserId.isEmpty
          ? const Center(child: Text('Debes iniciar sesión.'))
          : StreamBuilder<List<ContratoResumen>>(
              stream: _fetchContratosStream(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return _buildEmptyState('No tienes contratos.');
                }

                var contratos = snapshot.data!;
                
                if (_estadoFiltro != null) {
                  contratos = contratos.where((c) => c.estadoTrabajo == _estadoFiltro).toList();
                }

                if (contratos.isEmpty) {
                  return _buildEmptyState('No se encontraron contratos con los filtros aplicados.');
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: contratos.length,
                  itemBuilder: (context, index) {
                    final contrato = contratos[index];
                    return ContratoCard(
                      contrato: contrato,
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
          Icon(Icons.folder_off_outlined, size: 60, color: Colors.grey[600]),
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