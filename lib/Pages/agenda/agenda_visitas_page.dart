import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:servicly_app/Pages/crear_presupuesto/CoordinarVisitaPage.dart';
import 'package:servicly_app/models/visita_tecnica_model.dart';
import 'package:servicly_app/models/user_model.dart'; 
// CAMBIO: Se usa la importación que añadiste para tu página de perfil.
import 'package:servicly_app/Pages/perfil_pagina/perfil_pagina_widget.dart';

class AgendaVisitasPage extends StatefulWidget {
  final String currentUserId;

  const AgendaVisitasPage({super.key, required this.currentUserId});

  @override
  State<AgendaVisitasPage> createState() => _AgendaVisitasPageState();
}

class _AgendaVisitasPageState extends State<AgendaVisitasPage> {
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES');
  }

  // CAMBIO: La función de navegación ahora usa tu PerfilPaginaWidget.
  void _navigateToUserProfile(String userId) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (context) => PerfilPaginaWidget(user_id: userId),
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Agenda'),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('visitas_tecnicas')
            .where('participantIds', arrayContains: widget.currentUserId)
            .where('estado', whereIn: ['propuesta', 'confirmada'])
            .orderBy('fechaPropuesta', descending: false)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            print(snapshot.error);
            return const Center(child: Text('Error al cargar las visitas.'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final visitas = snapshot.data!.docs
              .map((doc) => VisitaTecnica.fromFirestore(doc))
              .toList();
          
          return _buildVisitasList(visitas);
        },
      ),
    );
  }

  Widget _buildVisitasList(List<VisitaTecnica> visitas) {
    return ListView.builder(
      padding: const EdgeInsets.all(8.0),
      itemCount: visitas.length,
      itemBuilder: (context, index) {
        final visita = visitas[index];
        final fecha = visita.fechaPropuesta.toDate();
        
        bool mostrarHeader = index == 0 ||
            visitas[index - 1].fechaPropuesta.toDate().month != fecha.month;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (mostrarHeader)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
                child: Text(
                  DateFormat('MMMM yyyy', 'es_ES').format(fecha).toUpperCase(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 16,
                  ),
                ),
              ),
            _buildVisitaCard(visita),
          ],
        );
      },
    );
  }

  // --- WIDGET DE LA TARJETA TOTALMENTE MODIFICADO ---
  Widget _buildVisitaCard(VisitaTecnica visita) {
    final fecha = visita.fechaPropuesta.toDate();
    final otroParticipanteId = widget.currentUserId == visita.clientId 
        ? visita.providerId 
        : visita.clientId;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(otroParticipanteId).get(),
      builder: (context, userSnapshot) {
        
        if (userSnapshot.connectionState == ConnectionState.waiting) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(title: Text('Cargando información...')),
          );
        }
        
        if (!userSnapshot.hasData || !userSnapshot.data!.exists) {
          return const Card(
            margin: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: ListTile(title: Text('No se encontró al usuario.')),
          );
        }
        
        final usuario = UserModel.fromFirestore(userSnapshot.data!);

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => CoordinarVisitaPage(
                  visitaId: visita.id,
                  solicitudDireccion: 'Dirección...', // Reemplazar con dato real
                  currentUserId: widget.currentUserId,
                ),
              ));
            },
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Row(
                children: [
                  // --- FOTO DE PERFIL A LA IZQUIERDA ---
                  GestureDetector(
                    onTap: () => _navigateToUserProfile(usuario.id),
                    child: CircleAvatar(
                      radius: 24,
                      backgroundImage: usuario.photoUrl != null && usuario.photoUrl!.isNotEmpty
                          ? NetworkImage(usuario.photoUrl!)
                          : null,
                      child: usuario.photoUrl == null || usuario.photoUrl!.isEmpty
                          ? const Icon(Icons.person, size: 28)
                          : null,
                    ),
                  ),
                  const SizedBox(width: 12),
                  
                  // --- INFORMACIÓN CENTRAL ---
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                usuario.displayName, 
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (usuario.esVerificado) ...[
                              const SizedBox(width: 6),
                              Icon(Icons.verified, color: Colors.blue.shade600, size: 16),
                            ]
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.star, color: Colors.amber.shade600, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${usuario.rating.toStringAsFixed(1)} (${usuario.ratingCount} opiniones)',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          visita.estado.toUpperCase(),
                          style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // --- FECHA ESTILO CALENDARIO A LA DERECHA ---
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: visita.estado == 'confirmada' 
                          ? Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5)
                          : Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('d', 'es_ES').format(fecha), 
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20)
                        ),
                        Text(
                          DateFormat('MMM', 'es_ES').format(fecha).toUpperCase(), 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)
                        ),
                        const SizedBox(height: 2),
                         Text(
                          DateFormat('HH:mm', 'es_ES').format(fecha),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      // ... (el código de _buildEmptyState no cambia)
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 60, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          const Text(
            'No tenés visitas pendientes',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              'Cuando coordines una visita técnica con un cliente o proveedor, aparecerá aquí.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
        ],
      ),
    );
  }
}