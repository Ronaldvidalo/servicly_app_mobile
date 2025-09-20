// lib/models/chat_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Chat {
  final String id;
  final List<String> participantes;
  final Map<String, String> participantesNombres;
  final Map<String, String> participantesFotos;
  final String ultimoMensajeTexto;
  final Timestamp ultimoMensajeTimestamp;
  final String ultimoMensajeAutorId;
  final List<String> leidoPor;
  // AHORA: Añadimos el contador de mensajes no leídos.
  final int unreadCount; 
  final String tipo; // "personal" o "trabajo"
  final String? nombreGrupo; // ej: "Reparación de Cocina"
  final String? presupuestoId; // Para navegar al detalle del presupuesto


  Chat({
    required this.id,
    required this.participantes,
    required this.participantesNombres,
    required this.participantesFotos,
    required this.ultimoMensajeTexto,
    required this.ultimoMensajeTimestamp,
    required this.ultimoMensajeAutorId,
    required this.leidoPor,
    // AHORA: Se añade al constructor.
    required this.unreadCount, 
    this.tipo = 'personal', // Por defecto es personal para tus chats viejos
    this.nombreGrupo,
    this.presupuestoId,
  });

  factory Chat.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    final ultimoMensaje = data['ultimoMensaje'] as Map<String, dynamic>? ?? {};
    final fotosData = data['participantesFotos'];
    final Map<String, String> fotosMap = fotosData is Map
        ? Map<String, String>.from(fotosData.map((key, value) => MapEntry(key.toString(), value.toString())))
        : {};
    final leidoPorData = ultimoMensaje['leidoPor'] as List<dynamic>? ?? [];

    return Chat(
      id: doc.id,
      participantes: List<String>.from(data['participantes'] ?? []),
      participantesNombres: Map<String, String>.from(data['participantesNombres'] ?? {}),
      participantesFotos: fotosMap,
      ultimoMensajeTexto: ultimoMensaje['texto'] as String? ?? 'Inicia una conversación.',
      ultimoMensajeTimestamp: ultimoMensaje['timestamp'] as Timestamp? ?? Timestamp.now(),
      ultimoMensajeAutorId: ultimoMensaje['idAutor'] as String? ?? '',
      leidoPor: leidoPorData.map((item) => item.toString()).toList(),
      // AHORA: Leemos el contador de forma segura, con un valor por defecto de 0.
      unreadCount: data['unreadCount'] as int? ?? 0,
      tipo: data['tipo'] ?? 'personal',
      nombreGrupo: data['nombreGrupo'],
      presupuestoId: data['presupuestoId'],
    );
  }
}