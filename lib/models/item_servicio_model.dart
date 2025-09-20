import 'package:cloud_firestore/cloud_firestore.dart';

class ItemServicio {
  final String id;
  final String descripcion;
  final String tipo;
  final double precio;
  final String unidad;

  ItemServicio({
    required this.id,
    required this.descripcion,
    required this.tipo,
    required this.precio,
    required this.unidad,
  });

  factory ItemServicio.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ItemServicio(
      id: doc.id,
      descripcion: data['descripcion'] ?? '',
      tipo: data['tipo'] ?? 'material',
      precio: (data['precio'] ?? 0.0).toDouble(),
      unidad: data['unidad'] ?? 'unidad',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'descripcion': descripcion,
      'tipo': tipo,
      'precio': precio,
      'unidad': unidad,
      'fecha_creacion': FieldValue.serverTimestamp(),
    };
  }
}