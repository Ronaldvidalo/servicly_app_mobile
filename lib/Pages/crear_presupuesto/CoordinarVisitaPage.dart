import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:servicly_app/models/visita_tecnica_model.dart';

// --- WIDGET PRINCIPAL ---

class CoordinarVisitaPage extends StatefulWidget {
  final String visitaId;
  final String solicitudDireccion;
  final String currentUserId;

  const CoordinarVisitaPage({
    super.key,
    required this.visitaId,
    required this.solicitudDireccion,
    required this.currentUserId,
  });

  @override
  State<CoordinarVisitaPage> createState() => _CoordinarVisitaPageState();
}

class _CoordinarVisitaPageState extends State<CoordinarVisitaPage> {
  
  @override
  void initState() {
    super.initState();
    initializeDateFormatting('es_ES');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Coordinar Visita Técnica'),
        actions: [
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('visitas_tecnicas').doc(widget.visitaId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox.shrink();
              final visita = VisitaTecnica.fromFirestore(snapshot.data!);
              if (visita.estado == 'confirmada') {
                return PopupMenuButton<String>(
                  onSelected: (value) {
                    if (value == 'reprogramar') _reprogramarVisita();
                    if (value == 'cancelar') _cancelarVisita();
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    const PopupMenuItem<String>(value: 'reprogramar', child: Text('Reprogramar Visita')),
                    const PopupMenuItem<String>(value: 'cancelar', child: Text('Cancelar Visita')),
                  ],
                );
              }
              return const SizedBox.shrink();
            }
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('visitas_tecnicas').doc(widget.visitaId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return _buildErrorView('No se encontró la solicitud de visita.');
          }
          
          final visita = VisitaTecnica.fromFirestore(snapshot.data!);
          final bool soyProveedor = widget.currentUserId == visita.providerId;
          
          return FutureBuilder<Map<String, Usuario>>(
            future: _getUsersData(visita.providerId, visita.clientId),
            builder: (context, userSnapshot) {
              if (!userSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              if (userSnapshot.hasError) {
                return _buildErrorView('Error al cargar datos de usuarios.');
              }
              
              final provider = userSnapshot.data!['provider']!;
              final client = userSnapshot.data!['client']!;

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  _buildUserInfoCard(
                    usuario: soyProveedor ? client : provider,
                    rol: soyProveedor ? 'Cliente' : 'Profesional'
                  ),
                  const SizedBox(height: 16),
                  _buildAddressCard(widget.solicitudDireccion),
                  const SizedBox(height: 24),
                  _buildStatusSection(visita, soyProveedor),
                  const SizedBox(height: 24),
                  if (visita.estado == 'confirmada')
                    _buildSecurityCodeCard(visita, soyProveedor),
                ],
              );
            }
          );
        },
      ),
    );
  }

  Future<Map<String, Usuario>> _getUsersData(String providerId, String clientId) async {
    try {
      final providerDoc = await FirebaseFirestore.instance.collection('usuarios').doc(providerId).get();
      final clientDoc = await FirebaseFirestore.instance.collection('usuarios').doc(clientId).get();
      if (!providerDoc.exists || !clientDoc.exists) {
        throw Exception("Uno de los usuarios no fue encontrado.");
      }
      return {
        'provider': Usuario.fromFirestore(providerDoc),
        'client': Usuario.fromFirestore(clientDoc),
      };
    } catch (e) {
      throw Exception("Error al obtener datos de usuarios: $e");
    }
  }

  // --- WIDGETS DE LA UI ---
  
  Widget _buildErrorView(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(message, textAlign: TextAlign.center),
      ),
    );
  }

  Widget _buildUserInfoCard({required Usuario usuario, required String rol}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            CircleAvatar(
              radius: 30,
              backgroundImage: usuario.photoUrl.isNotEmpty ? NetworkImage(usuario.photoUrl) : null,
              child: usuario.photoUrl.isEmpty ? const Icon(Icons.person, size: 30) : null,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(rol, style: theme.textTheme.labelMedium),
                  Text(usuario.displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  if (rol == 'Profesional' && usuario.esVerificado) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.verified, color: Colors.blue.shade600, size: 16),
                        const SizedBox(width: 4),
                        Text('Profesional Verificado', style: TextStyle(color: Colors.blue.shade600, fontWeight: FontWeight.bold, fontSize: 12)),
                      ],
                    )
                  ]
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddressCard(String direccion) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(Icons.location_on_outlined, color: Theme.of(context).colorScheme.primary),
        title: const Text('Dirección de la Visita', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(direccion),
      ),
    );
  }

  Widget _buildStatusSection(VisitaTecnica visita, bool soyProveedor) {
    final theme = Theme.of(context);
    
    switch (visita.estado) {
      case 'confirmada':
        return Column(
          children: [
            Icon(Icons.check_circle, color: Colors.green.shade600, size: 48),
            const SizedBox(height: 8),
            Text('Visita Confirmada', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(
              DateFormat("'para el' d 'de' MMMM 'a las' HH:mm 'hs.'", 'es_ES').format(visita.fechaConfirmada!.toDate()),
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
          ],
        );
      
      case 'propuesta':
        final bool yoPropuse = widget.currentUserId == visita.propuestoPor;
        return yoPropuse
            ? _buildWaitingForResponse(visita)
            : _buildProposalReceived(visita);
      
      case 'cancelada':
        return Column(
          children: [
            Icon(Icons.cancel, color: Colors.red.shade700, size: 48),
            const SizedBox(height: 8),
            Text('Visita Cancelada', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
          ],
        );

      default: // 'pendiente' o cualquier otro estado
        // CAMBIO: Se pasa el objeto 'visita' a la función
        return _buildInitialProposal(visita);
    }
  }

  // CAMBIO: La función ahora recibe el objeto 'visita'
  Widget _buildInitialProposal(VisitaTecnica visita) {
    return Column(
      children: [
        const Icon(Icons.hourglass_empty, size: 40, color: Colors.grey),
        const SizedBox(height: 16),
        const Text('Aún no se ha definido un horario para la visita.', textAlign: TextAlign.center),
        const SizedBox(height: 16),
        FilledButton.icon(
          icon: const Icon(Icons.calendar_month),
          label: const Text('Proponer Horario'),
          // CAMBIO: Se pasa el objeto 'visita' a la función de proponer
          onPressed: () => _proponerNuevoHorario(visita),
        )
      ],
    );
  }

  Widget _buildProposalReceived(VisitaTecnica visita) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text('Propuesta Recibida', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
            Text(
              DateFormat("'El' d 'de' MMMM 'a las' HH:mm 'hs.'", 'es_ES').format(visita.fechaPropuesta.toDate()),
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    // CAMBIO: Se pasa el objeto 'visita' a la función de proponer
                    onPressed: () => _proponerNuevoHorario(visita),
                    child: const Text('Proponer Otro'),
                  ),
                ),
                const SizedBox(width: 12),
                  Expanded(
                  child: FilledButton(
                    onPressed: () => _confirmarHorario(visita),
                    child: const Text('Aceptar Horario'),
                  ),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildWaitingForResponse(VisitaTecnica visita) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text('Enviaste una propuesta de horario:', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 8),
        Text(
          DateFormat("'El' d 'de' MMMM 'a las' HH:mm 'hs.'", 'es_ES').format(visita.fechaPropuesta.toDate()),
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        const Text('Esperando respuesta de la otra parte...', style: TextStyle(fontStyle: FontStyle.italic)),
      ],
    );
  }

 Widget _buildSecurityCodeCard(VisitaTecnica visita, bool soyProveedor) {
  final theme = Theme.of(context);
  return Card(
      elevation: 0,
      color: theme.colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Text(
              'Código de Seguridad',
              style: theme.textTheme.titleMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.bold
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'El cliente te pedirá este código para confirmar tu identidad al llegar.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onPrimaryContainer.withAlpha((255 * 0.8).round())
              ),
            ),
            const SizedBox(height: 16),
            Text(
              visita.codigoSeguridad?.split('').join(' ') ?? '----',
              style: theme.textTheme.displayMedium?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: 8,
                color: theme.colorScheme.onPrimaryContainer
              ),
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Generar nuevo código'),
              onPressed: () => _regenerarCodigo(visita.id),
              style: TextButton.styleFrom(
                foregroundColor: theme.colorScheme.onPrimaryContainer
              ),
            )
          ],
        ),
      ),
    );
  }

  // --- LÓGICA DE ACCIONES ---

  // CAMBIO: La función ahora recibe 'visita' para poder acceder a los IDs
  Future<void> _proponerNuevoHorario(VisitaTecnica visita) async {
    final DateTime? fecha = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
    );
    if (fecha == null || !mounted) return;

    final TimeOfDay? hora = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (hora == null || !mounted) return;

    final fechaYHoraPropuesta = DateTime(fecha.year, fecha.month, fecha.day, hora.hour, hora.minute);
    
    await FirebaseFirestore.instance.collection('visitas_tecnicas').doc(widget.visitaId).update({
      'fechaPropuesta': Timestamp.fromDate(fechaYHoraPropuesta),
      'propuestoPor': widget.currentUserId,
      'estado': 'propuesta',
      // CAMBIO: Se añade el campo 'participantIds' en la actualización
      'participantIds': [visita.clientId, visita.providerId],
    });
  }

  Future<void> _confirmarHorario(VisitaTecnica visita) async {
    final nuevoCodigo = _generarCodigoAleatorio();
    await FirebaseFirestore.instance.collection('visitas_tecnicas').doc(visita.id).update({
      'fechaConfirmada': visita.fechaPropuesta,
      'estado': 'confirmada',
      'codigoSeguridad': nuevoCodigo,
      // CAMBIO: Se añade el campo 'participantIds' en la actualización
      'participantIds': [visita.clientId, visita.providerId],
    });
  }
  
  String _generarCodigoAleatorio() {
    return (1000 + Random().nextInt(9000)).toString();
  }

  Future<void> _regenerarCodigo(String visitaId) async {
    final nuevoCodigo = _generarCodigoAleatorio();
    await FirebaseFirestore.instance.collection('visitas_tecnicas').doc(visitaId).update({
      'codigoSeguridad': nuevoCodigo,
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nuevo código de seguridad generado.'), backgroundColor: Colors.blue),
      );
    }
  }

  Future<void> _reprogramarVisita() async {
    await FirebaseFirestore.instance.collection('visitas_tecnicas').doc(widget.visitaId).update({
      'estado': 'pendiente',
      'fechaPropuesta': null,
      'fechaConfirmada': null,
      'propuestoPor': null,
      'codigoSeguridad': null,
    });
  }

  Future<void> _cancelarVisita() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar Visita'),
        content: const Text('¿Estás seguro de que quieres cancelar esta visita? Esta acción no se puede deshacer.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('No')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(context).pop(true), 
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      await FirebaseFirestore.instance.collection('visitas_tecnicas').doc(widget.visitaId).update({
        'estado': 'cancelada',
      });
    }
  }
}


// --- MODELOS (Reemplazar con los tuyos) ---
// Este modelo debe estar en su propio archivo, pero lo incluyo aquí como referencia.
class Usuario {
  final String id;
  final String displayName;
  final String photoUrl;
  final bool esVerificado;

  Usuario({required this.id, required this.displayName, required this.photoUrl, this.esVerificado = false});

  factory Usuario.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return Usuario(
      id: doc.id,
      displayName: data['display_name'] ?? 'Usuario',
      photoUrl: data['photo_url'] ?? '',
      esVerificado: data['esVerificado'] ?? false,
    );
  }
}