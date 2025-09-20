// lib/models/solicitud_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

class Solicitud {
  final String id;
  final String user_id; 
  final String categoria;
  final DocumentReference? clienteRef;
  final String descripcion;
  final String status;
  final String titulo;
  final Timestamp fechaCreacion;
  final String? formaPago;
  final String? horario;
  final String? prioridad;
  final String? provincia;
  final String? municipio;
  final bool requiereSeguro;
  final List<Map<String, dynamic>> media;
  final String direccionCompleta; 

  final int presupuestosCount;

  Solicitud({
    required this.id,
    required this.user_id, 
    required this.categoria,
    this.clienteRef,
    required this.descripcion,
    required this.status,
    required this.titulo,
    required this.fechaCreacion,
    required this.direccionCompleta, 
    this.formaPago,
    this.horario,
    this.prioridad,
    this.provincia,
    this.municipio,
    this.requiereSeguro = false,
    required this.media,
    required this.presupuestosCount,
  });

  factory Solicitud.fromMap(Map<String, dynamic> json, String id) {
       final direccionData = json['direccion'] as Map<String, dynamic>? ?? {};

    return Solicitud(
      id: id,
           user_id: json['user_id'] as String? ?? '', 
      categoria: json['categoria'] as String? ?? '',
      clienteRef: json['clienteRef'] as DocumentReference?,
      descripcion: json['descripcion'] as String? ?? '',
      status: json['status'] as String? ?? 'Activa',
      titulo: json['titulo'] as String? ?? '',
          fechaCreacion: json['fechaCreacion'] as Timestamp? ?? Timestamp.now(), 
      formaPago: json['formaPago'] as String?,
      horario: json['horario'] as String?,
      prioridad: json['prioridad'] as String?,
           provincia: json['provincia'] as String? ?? '',
      municipio: json['municipio'] as String? ?? '',
      requiereSeguro: json['requiereSeguro'] as bool? ?? false,
      media: List<Map<String, dynamic>>.from(json['media'] ?? []),
      presupuestosCount: json['presupuestosCount'] as int? ?? 0,
      direccionCompleta: json['direccionCompleta'] as String? ?? '',
    );
  }

  factory Solicitud.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return Solicitud.fromMap(data, doc.id);
  }

  Map<String, dynamic> toJson() {
    return {
           'user_id': user_id, 
      'categoria': categoria,
      'clienteRef': clienteRef,
      'descripcion': descripcion,
      'status': status,
      'titulo': titulo,
      'fechaCreacion': fechaCreacion, 
      'formaPago': formaPago,
      'horario': horario,
      'prioridad': prioridad,
      'requiereSeguro': requiereSeguro,
      'provincia': provincia,
      'municipio': municipio,
      'direccionCompleta': direccionCompleta,
      'media': media,
      'presupuestosCount': presupuestosCount,
    };
  }
}
