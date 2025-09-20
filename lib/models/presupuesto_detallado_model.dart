import 'package:cloud_firestore/cloud_firestore.dart';

class PresupuestoDetallado {
  final String id;
  final String titulo;
  final String categoria;
  final Timestamp fechaCreacion;
  final String realizadoPor;
  final String userServicio;
  final int? numeroPresupuesto;
  final List<Map<String, dynamic>> materiales;
  final List<Map<String, dynamic>> manoDeObra;
  final List<Map<String, dynamic>> fletes;
  final List<Map<String, dynamic>> hitosDePago; 
  final String garantia;
  final String duracionEstimada;
  final String fechaInicioEstimada;
  final String validezOferta;
  final String detalles;
  final double subtotal;
  final double comision;
  final bool incluyeIva;
  final double totalFinal;
  final String estado;
  final String? contratoId;
  final bool clienteAceptoCompromiso;
final bool proveedorAceptoCompromiso;
final String idSolicitud;
final String pais;

  PresupuestoDetallado({
    required this.id,
    required this.titulo,
    required this.categoria,
    required this.fechaCreacion,
    required this.realizadoPor,
    required this.userServicio,
    this.numeroPresupuesto,
    required this.materiales,
    required this.manoDeObra,
    required this.fletes,
    required this.hitosDePago, // <-- Se añade al constructor
    required this.garantia,
    required this.duracionEstimada,
    required this.fechaInicioEstimada,
    required this.validezOferta, // <-- Se añade al constructor
    required this.detalles,
    required this.subtotal,
    required this.comision,
    required this.incluyeIva,
    required this.totalFinal,
    required this.estado,
    this.contratoId,
    required this.clienteAceptoCompromiso,
  required this.proveedorAceptoCompromiso,
  required this.idSolicitud, 
   required this.pais,
  });

  factory PresupuestoDetallado.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? {};
    return PresupuestoDetallado(
      id: doc.id,
      titulo: data['tituloPresupuesto'] ?? 'Presupuesto',
      categoria: data['categoria'] ?? 'Sin categoría',
      fechaCreacion: data['fechaCreacion'] ?? Timestamp.now(),
      realizadoPor: data['realizadoPor'] ?? '',
      userServicio: data['userServicio'] ?? '',
      numeroPresupuesto: data['numero_presupuesto'],
      materiales: List<Map<String, dynamic>>.from(data['materiales'] ?? []),
      manoDeObra: List<Map<String, dynamic>>.from(data['manoDeObra'] ?? []),
      fletes: List<Map<String, dynamic>>.from(data['fletes'] ?? []),
      // --- CORRECCIÓN: Se leen los campos de Firestore ---
      hitosDePago: List<Map<String, dynamic>>.from(data['hitosDePago'] ?? []),
      validezOferta: data['validezOferta'] ?? 'No especificada',
      
      garantia: data['garantia'] ?? 'No especificada',
      duracionEstimada: data['duracionEstimada'] ?? 'No especificado',
      fechaInicioEstimada: data['fechaInicioEstimada'] ?? 'No especificada',
      detalles: data['detalles'] ?? 'Ninguno',
      subtotal: (data['subtotal'] as num? ?? 0.0).toDouble(),
      comision: (data['comision'] as num? ?? 0.0).toDouble(),
      incluyeIva: data['incluyeIva'] ?? false,
      totalFinal: (data['totalFinal'] as num? ?? 0.0).toDouble(),
      estado: data['estado'] as String? ?? 'PENDIENTE',
      contratoId: data['contratoId'],
       idSolicitud: data['idSolicitud'] ?? '',
      clienteAceptoCompromiso: data['clienteAceptoCompromiso'] ?? false,
    proveedorAceptoCompromiso: data['proveedorAceptoCompromiso'] ?? false,
     pais: data['pais'] ?? '',
    );
  }
}