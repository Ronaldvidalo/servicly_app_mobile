import 'package:cloud_firestore/cloud_firestore.dart';

class Presupuesto {
  final String id;
  final String realizadoPor;
  final String userServicio;
  final String idSolicitud;
  final String tituloPresupuesto;
  final String status; // 'borrador' o 'enviado'
  final String estado; // 'PENDIENTE', 'ACEPTADO_POR_CLIENTE', etc.
  final double totalFinal;
  final Timestamp fechaCreacion;

  Presupuesto({
    required this.id,
    required this.realizadoPor,
    required this.userServicio,
    required this.idSolicitud,
    required this.tituloPresupuesto,
    required this.status,
    required this.estado,
    required this.totalFinal,
    required this.fechaCreacion,
  });

  factory Presupuesto.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Presupuesto(
      id: doc.id,
      realizadoPor: data['realizadoPor'] as String? ?? '',
      userServicio: data['userServicio'] as String? ?? '',
      idSolicitud: data['idSolicitud'] as String? ?? '',
      tituloPresupuesto: data['tituloPresupuesto'] as String? ?? 'Sin título',
      // Si el campo 'status' no existe, asumimos que es 'enviado' (para tus docs viejos)
      status: data['status'] as String? ?? 'enviado',
      // 'estado' ahora se lee por separado
      estado: data['estado'] as String? ?? 'PENDIENTE',
      totalFinal: (data['totalFinal'] as num? ?? 0.0).toDouble(),
      fechaCreacion: data['fechaCreacion'] as Timestamp? ?? Timestamp.now(),
    );
  }
}