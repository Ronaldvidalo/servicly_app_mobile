import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

// --- MODELOS DE DATOS (Ejemplos para que el widget funcione) ---
class Presupuesto {
  final String id;
  final String titulo;
  // Añade aquí los demás campos que necesites de tu modelo real
  Presupuesto({required this.id, required this.titulo});
}

class EventoBitacora {
  final String id;
  final String descripcion;
  final String tipo; // 'INICIO', 'PAGO', 'AVANCE', 'PAUSA', 'FIN', 'GARANTIA'
  final Timestamp timestamp;
  final String autorId;

  EventoBitacora.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc)
      : id = doc.id,
        descripcion = doc.data()?['descripcion'] ?? '',
        tipo = doc.data()?['tipo'] ?? 'AVANCE',
        timestamp = doc.data()?['timestamp'] ?? Timestamp.now(),
        autorId = doc.data()?['autorId'] ?? '';
}

// --- PÁGINA PRINCIPAL DE SEGUIMIENTO ---
class SeguimientoTrabajoPage extends StatefulWidget {
  final String presupuestoId;

  const SeguimientoTrabajoPage({super.key, required this.presupuestoId});

  @override
  State<SeguimientoTrabajoPage> createState() => _SeguimientoTrabajoPageState();
}

class _SeguimientoTrabajoPageState extends State<SeguimientoTrabajoPage> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Seguimiento del Trabajo'),
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('presupuestos').doc(widget.presupuestoId).get(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final presupuestoData = snapshot.data!.data() as Map<String, dynamic>;
          
          return Column(
            children: [
              _buildHeader(context, presupuestoData),
              const Divider(height: 1),
              Expanded(child: _buildTimeline(context)),
              _buildActionBar(context, presupuestoData),
            ],
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Map<String, dynamic> data) {
    final status = data['status'] ?? 'Iniciado';
    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data['tituloPresupuesto'] ?? 'Trabajo sin título',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Estado: '),
              Chip(
                label: Text(status),
                backgroundColor: Colors.blue.shade100,
                labelStyle: TextStyle(color: Colors.blue.shade800),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline(BuildContext context) {
    // En un caso real, aquí iría un StreamBuilder a la subcolección de eventos
    // Por ahora, usamos datos de ejemplo.
    final List<Map<String, dynamic>> eventosEjemplo = [
      {'tipo': 'INICIO', 'descripcion': 'El proveedor ha iniciado el trabajo.', 'timestamp': Timestamp.now()},
      {'tipo': 'PAGO', 'descripcion': 'El cliente ha realizado el pago inicial de \$5,000.', 'timestamp': Timestamp.now()},
      {'tipo': 'AVANCE', 'descripcion': 'Se completó la instalación de la estructura base.', 'timestamp': Timestamp.now()},
      {'tipo': 'PAUSA', 'descripcion': 'Trabajo pausado por mal clima.', 'timestamp': Timestamp.now()},
    ];

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: eventosEjemplo.length,
      itemBuilder: (context, index) {
        final evento = eventosEjemplo[index];
        return _TimelineTile(
          evento: evento,
          isFirst: index == 0,
          isLast: index == eventosEjemplo.length - 1,
        );
      },
    );
  }

  Widget _buildActionBar(BuildContext context, Map<String, dynamic> data) {
    // Lógica para mostrar botones según el estado y el rol del usuario
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, -2),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          // Ejemplo de botones para el proveedor
          ElevatedButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.add_comment_outlined),
            label: const Text('Registrar Avance'),
          ),
          OutlinedButton(
            onPressed: () {},
            child: const Text('Pausar'),
          ),
        ],
      ),
    );
  }
}

// --- WIDGET PARA UN EVENTO EN LA LÍNEA DE TIEMPO ---
class _TimelineTile extends StatelessWidget {
  final Map<String, dynamic> evento;
  final bool isFirst;
  final bool isLast;

  const _TimelineTile({required this.evento, this.isFirst = false, this.isLast = false});

  IconData _getIconForType(String tipo) {
    switch (tipo) {
      case 'INICIO': return Icons.play_circle_fill_outlined;
      case 'PAGO': return Icons.payment;
      case 'AVANCE': return Icons.construction;
      case 'PAUSA': return Icons.pause_circle_outline;
      case 'FIN': return Icons.check_circle;
      case 'GARANTIA': return Icons.shield_outlined;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final timestamp = evento['timestamp'] as Timestamp;
    final fecha = DateFormat('dd/MM/yyyy HH:mm').format(timestamp.toDate());

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              if (!isFirst) Expanded(child: VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor)),
              Icon(_getIconForType(evento['tipo']), color: theme.colorScheme.primary),
              if (!isLast) Expanded(child: VerticalDivider(width: 1, thickness: 1, color: theme.dividerColor)),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fecha, style: theme.textTheme.bodySmall),
                  const SizedBox(height: 4),
                  Text(evento['descripcion'], style: theme.textTheme.bodyLarge),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
