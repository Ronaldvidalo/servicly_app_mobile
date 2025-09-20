// lib/models/visita_tecnica_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

class VisitaTecnica {
  final String id;
  final String clientId;
  final String providerId;
  final String estado;
  final String propuestoPor;
  final String solicitudId;
  final Timestamp fechaPropuesta;
  
  // --- CAMPOS NUEVOS AÑADIDOS ---
  final Timestamp? fechaConfirmada; // Puede ser nulo si aún no se confirma
  final String? codigoSeguridad;   // Puede ser nulo si aún no se confirma

  // Este es un 'getter' útil que crea la lista de participantes que necesitamos
  List<String> get participantIds => [clientId, providerId];

  VisitaTecnica({
    required this.id,
    required this.clientId,
    required this.providerId,
    required this.estado,
    required this.propuestoPor,
    required this.solicitudId,
    required this.fechaPropuesta,
    // --- AÑADIDOS AL CONSTRUCTOR ---
    this.fechaConfirmada,
    this.codigoSeguridad,
  });

  factory VisitaTecnica.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return VisitaTecnica(
      id: doc.id,
      clientId: data['clientId'] ?? '',
      providerId: data['providerId'] ?? '',
      estado: data['estado'] ?? 'desconocido',
      propuestoPor: data['propuestoPor'] ?? '',
      solicitudId: data['solicitudId'] ?? '',
      fechaPropuesta: data['fechaPropuesta'] ?? Timestamp.now(),
      // --- AÑADIDOS AL FACTORY CONSTRUCTOR ---
      fechaConfirmada: data['fechaConfirmada'] as Timestamp?,
      codigoSeguridad: data['codigoSeguridad'] as String?,
    );
  }
}