// lib/models/contrato_model.dart

import 'package:cloud_firestore/cloud_firestore.dart';

// MEJORA: HitoPago ahora maneja un flujo de confirmación completo.
class HitoPago {
  final String descripcion;
  final double monto;
   final Map<String, dynamic>? detallesPagoCliente; // Un mapa para guardar todo

  // CAMBIO: 'pagado' (bool) se reemplaza por 'estadoPago' (String).
  final String estadoPago; // Posibles valores: 'PENDIENTE', 'EN_REVISION', 'CONFIRMADO'
  
  // NUEVO: Campos para el flujo de comprobantes.
  final String? comprobanteUrl;
  final Timestamp? fechaSubidaComprobante;
  final Timestamp? fechaConfirmacionPago;

  HitoPago({
    required this.descripcion,
    required this.monto,
    this.estadoPago = 'PENDIENTE',
    this.comprobanteUrl,
    this.fechaSubidaComprobante,
    this.fechaConfirmacionPago,
    this.detallesPagoCliente, 
  });

  factory HitoPago.fromMap(Map<String, dynamic> map) {
    return HitoPago(
      descripcion: map['descripcion'] ?? '',
      monto: (map['monto'] ?? 0.0).toDouble(),
      estadoPago: map['estadoPago'] ?? 'PENDIENTE',
      comprobanteUrl: map['comprobanteUrl'],
      fechaSubidaComprobante: map['fechaSubidaComprobante'],
      fechaConfirmacionPago: map['fechaConfirmacionPago'],
      detallesPagoCliente: map['detallesPagoCliente'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'descripcion': descripcion,
      'monto': monto,
      'estadoPago': estadoPago,
      'comprobanteUrl': comprobanteUrl,
      'fechaSubidaComprobante': fechaSubidaComprobante,
      'fechaConfirmacionPago': fechaConfirmacionPago,
      'detallesPagoCliente': detallesPagoCliente, 
    };
  }
}

// La clase Evaluacion no necesita cambios.
class Evaluacion {
  final double rating;
  final String comentario;
  final Timestamp fecha;
  final String clienteId;

  Evaluacion({required this.rating, required this.comentario, required this.fecha, required this.clienteId});

  factory Evaluacion.fromMap(Map<String, dynamic> map) {
    return Evaluacion(
      rating: (map['rating'] ?? 0.0).toDouble(),
      comentario: map['comentario'] ?? '',
      fecha: map['fecha'] ?? Timestamp.now(),
      clienteId: map['clienteId'] ?? '',
    );
  }
}

// Modelo principal del Contrato (actualizado)
class Contrato {
  final String id;
  final String presupuestoId;
  final String clienteId;
  final String proveedorId;
  final String titulo;
  final double total;
  final int garantiaDias;
  final String estadoTrabajo;
  final List<HitoPago> hitosDePago;
  final Timestamp fechaConfirmacion;
  final Timestamp? fechaFinalizacionCliente;
  final Evaluacion? evaluacion;
  final String duracionEstimada;

  // --- NUEVOS CAMPOS ---
  final String numeroContrato;
  final Map<String, dynamic> resumenCompromisos;
  final List<Map<String, dynamic>> historialEventos;

  Contrato({
    required this.id,
    required this.presupuestoId,
    required this.clienteId,
    required this.proveedorId,
    required this.titulo,
    required this.total,
    required this.garantiaDias,
    required this.estadoTrabajo,
    required this.hitosDePago,
    required this.fechaConfirmacion,
    this.fechaFinalizacionCliente,
    this.evaluacion,
    required this.duracionEstimada,
    // --- NUEVOS CAMPOS EN EL CONSTRUCTOR ---
    required this.numeroContrato,
    required this.resumenCompromisos,
    required this.historialEventos,
  });

  factory Contrato.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;

    final garantiaValue = data['garantiaDias'];
    int garantiaInt = 0;
    if (garantiaValue is int) {
      garantiaInt = garantiaValue;
    } else if (garantiaValue is String) {
      garantiaInt = int.tryParse(garantiaValue) ?? 0;
    }

    return Contrato(
      id: doc.id,
      presupuestoId: data['presupuestoId'] ?? '',
      clienteId: data['clienteId'] ?? '',
      proveedorId: data['proveedorId'] ?? '',
      titulo: data['titulo'] ?? 'Trabajo sin título',
      total: (data['total'] ?? 0.0).toDouble(),
      garantiaDias: garantiaInt,
      estadoTrabajo: data['estadoTrabajo'] ?? 'DESCONOCIDO',
      hitosDePago: (data['hitosDePago'] as List<dynamic>?)
          ?.map((hito) => HitoPago.fromMap(hito as Map<String, dynamic>))
          .toList() ?? [],
      fechaConfirmacion: data['fechaConfirmacion'] ?? Timestamp.now(),
      fechaFinalizacionCliente: data['fechaFinalizacionCliente'],
      evaluacion: data['evaluacion'] != null
          ? Evaluacion.fromMap(data['evaluacion'] as Map<String, dynamic>)
          : null,
      duracionEstimada: data['duracionEstimada'] ?? 'No especificada',
      
      // --- LECTURA DE NUEVOS CAMPOS DESDE FIRESTORE ---
      numeroContrato: data['numeroContrato'] ?? 'N/A',
      resumenCompromisos: data['resumenCompromisos'] as Map<String, dynamic>? ?? {},
      historialEventos: List<Map<String, dynamic>>.from(data['historialEventos'] ?? []),
    );
  }
}

// La clase ContratoResumen no necesita cambios por ahora.
class ContratoResumen {
  final String id;
  final String titulo;
  final String estadoTrabajo;
  final String clienteId;
  final String proveedorId;
  final double total;
  final Timestamp fechaConfirmacion;

  ContratoResumen({
    required this.id,
    required this.titulo,
    required this.estadoTrabajo,
    required this.clienteId,
    required this.proveedorId,
    required this.total,
    required this.fechaConfirmacion,
  });

  factory ContratoResumen.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data()!;
    return ContratoResumen(
      id: doc.id,
      titulo: data['titulo'] ?? '',
      estadoTrabajo: data['estadoTrabajo'] ?? 'DESCONOCIDO',
      clienteId: data['clienteId'] ?? '',
      proveedorId: data['proveedorId'] ?? '',
      total: (data['total'] ?? 0.0).toDouble(),
      fechaConfirmacion: data['fechaConfirmacion'] ?? Timestamp.now(),
    );
  }
}