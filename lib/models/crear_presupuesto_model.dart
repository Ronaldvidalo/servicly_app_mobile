// lib/models/crear_presupuesto_model.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// --- DEFINICIONES DE LOS ÍTEMS ---
class MaterialItem {
  String descripcion;
  int cantidad;
  double precioUnitario;
  MaterialItem({required this.descripcion, required this.cantidad, required this.precioUnitario});
  double get precioTotal => cantidad * precioUnitario;

  factory MaterialItem.fromMap(Map<String, dynamic> map) {
    return MaterialItem(
      descripcion: map['descripcion'] ?? '',
      cantidad: map['cantidad']?.toInt() ?? 0,
      precioUnitario: map['precioUnitario']?.toDouble() ?? 0.0,
    );
  }
}

class ManoDeObraItem {
  String descripcion;
  double? precioGlobal;
  double? cantidad;
  double? precioUnitario;
  String? unidad;
  ManoDeObraItem({required this.descripcion, this.precioGlobal, this.cantidad, this.precioUnitario, this.unidad});
  double get costo => precioGlobal ?? ((cantidad ?? 0) * (precioUnitario ?? 0));

  factory ManoDeObraItem.fromMap(Map<String, dynamic> map) {
    return ManoDeObraItem(
      descripcion: map['descripcion'] ?? '',
      precioGlobal: map['precioGlobal']?.toDouble(),
      cantidad: map['cantidad']?.toDouble(),
      precioUnitario: map['precioUnitario']?.toDouble(),
      unidad: map['unidad'],
    );
  }
}

class FleteItem {
  String descripcion;
  double costo;
  FleteItem({required this.descripcion, required this.costo});

  factory FleteItem.fromMap(Map<String, dynamic> map) {
    return FleteItem(
      descripcion: map['descripcion'] ?? '',
      costo: map['costo']?.toDouble() ?? 0.0,
    );
  }
}

class HitoDePago {
  String descripcion;
  double monto;
  HitoDePago({required this.descripcion, required this.monto});

  factory HitoDePago.fromMap(Map<String, dynamic> map) {
    return HitoDePago(
      descripcion: map['descripcion'] ?? '',
      monto: map['monto']?.toDouble() ?? 0.0,
    );
  }
}

// --- EL MODELO PRINCIPAL QUE EXTIENDE ChangeNotifier ---
class CrearPresupuestoModel extends ChangeNotifier {
  // Listas para los ítems
  List<MaterialItem> materiales = [];
  List<ManoDeObraItem> manoDeObra = [];
  List<FleteItem> fletes = [];
  List<HitoDePago> hitosDePago = [];
  
  // Controladores para los campos de texto
  final TextEditingController fechaInicioController = TextEditingController();
  final TextEditingController duracionController = TextEditingController();
  final TextEditingController garantiaController = TextEditingController();
  final TextEditingController detallePresupuestoController = TextEditingController();
  final TextEditingController validezController = TextEditingController();
  
  // Estado del IVA y del Plan
  bool incluyeIva = false;
  bool _esPlanConPrivilegios = false; // Por defecto es 'Free'

  // --- GETTERS PARA CÁLCULOS ---
  double get subtotalMateriales => materiales.fold(0, (total, item) => total + item.precioTotal);
  double get subtotalManoDeObra => manoDeObra.fold(0, (total, item) => total + item.costo);
  double get subtotalFletes => fletes.fold(0, (total, item) => total + item.costo);
  double get subtotalGeneral => subtotalMateriales + subtotalManoDeObra + subtotalFletes;
  
  double get comision {
    // Si NO es un plan con privilegios (Free), se calcula la comisión del 5%. Si no, es 0.
    return !_esPlanConPrivilegios ? subtotalManoDeObra * 0.05 : 0;
  }
  
  double get iva {
    // El IVA se calcula sobre el subtotal MÁS la comisión.
    return (subtotalGeneral + comision) * 0.21;
  }
  
  double get totalFinal {
    double total = subtotalGeneral + comision;
    if (incluyeIva) {
      total += iva;
    }
    return total;
  }
  
  double get totalHitos => hitosDePago.fold(0, (total, item) => total + item.monto);
  double get montoRestanteHitos => totalFinal - totalHitos;
  double get montoGarantia => subtotalManoDeObra * 0.10; // Se asume que esto es correcto
  double get totalARecibir => totalFinal - comision - montoGarantia; // Se asume que esto es correcto

  bool get hitosCoincidenConTotal {
    if (hitosDePago.isEmpty && totalFinal == 0) return true;
    if (hitosDePago.isEmpty && totalFinal > 0) return false;
    return (totalHitos - totalFinal).abs() < 0.01;
  }
  
  bool get isFormValid => totalFinal > 0;

  // --- MÉTODOS PARA MODIFICAR EL ESTADO ---

  void setPlanConPrivilegios(bool tienePrivilegios) {
    if (_esPlanConPrivilegios != tienePrivilegios) {
      _esPlanConPrivilegios = tienePrivilegios;
      _recalcularYNotificar();
    }
  }

  void _recalcularYNotificar() {
    // Este método central asegura que siempre que algo cambie, se notifique a los listeners.
    notifyListeners();
  }

  void addMaterial(MaterialItem item) {
    materiales.add(item);
    _recalcularYNotificar();
  }
  void removeMaterial(int index) {
    materiales.removeAt(index);
    _recalcularYNotificar();
  }

  void addManoDeObra(ManoDeObraItem item) {
    manoDeObra.add(item);
    _recalcularYNotificar();
  }
  void removeManoDeObra(int index) {
    manoDeObra.removeAt(index);
    _recalcularYNotificar();
  }

  void addFlete(FleteItem item) {
    fletes.add(item);
    _recalcularYNotificar();
  }
  void removeFlete(int index) {
    fletes.removeAt(index);
    _recalcularYNotificar();
  }

  void addHito(HitoDePago hito) {
    hitosDePago.add(hito);
    _recalcularYNotificar();
  }
  void updateHito(int index, String descripcion, double monto) {
    hitosDePago[index].descripcion = descripcion;
    hitosDePago[index].monto = monto;
    _recalcularYNotificar();
  }
  void removeHito(int index) {
    hitosDePago.removeAt(index);
    _recalcularYNotificar();
  }

  void toggleIva(bool value) {
    incluyeIva = value;
    _recalcularYNotificar();
  }

  // --- LIMPIEZA Y SERIALIZACIÓN ---
  @override
  void dispose() {
    fechaInicioController.dispose();
    duracionController.dispose();
    garantiaController.dispose();
    detallePresupuestoController.dispose();
    validezController.dispose();
    super.dispose();
  }

  Map<String, dynamic> toMap({
    required String idSolicitud,
    required String userServicio,
    required String categoria,
    required String tituloPresupuesto,
    required String realizadoPor,
    int? numeroPresupuesto,
    required String? provincia,
    required String? municipio,
    required String direccionCompleta, 
  }) {
    return {
      'idSolicitud': idSolicitud,
      'userServicio': userServicio,
      'realizadoPor': realizadoPor,
      'tituloPresupuesto': tituloPresupuesto,
      'categoria': categoria,
      'fechaCreacion': FieldValue.serverTimestamp(),
      'materiales': materiales.map((e) => {'descripcion': e.descripcion, 'cantidad': e.cantidad, 'precioUnitario': e.precioUnitario}).toList(),
      'manoDeObra': manoDeObra.map((e) => {'descripcion': e.descripcion, 'precioGlobal': e.precioGlobal, 'cantidad': e.cantidad, 'precioUnitario': e.precioUnitario, 'unidad': e.unidad}).toList(),
      'fletes': fletes.map((e) => {'descripcion': e.descripcion, 'costo': e.costo}).toList(),
      'hitosDePago': hitosDePago.map((e) => {'descripcion': e.descripcion, 'monto': e.monto}).toList(),
      'garantiaDias': int.tryParse(garantiaController.text) ?? 0,
      'detallesAdicionales': detallePresupuestoController.text,
      'subtotal': subtotalGeneral,
      'comision': comision,
      'incluyeIva': incluyeIva,
      'iva': incluyeIva ? iva : 0,
      'totalFinal': totalFinal,
      'fechaInicio': fechaInicioController.text,
      'duracionEstimada': duracionController.text,
      'montoGarantia': montoGarantia,
      'totalARecibir': totalARecibir,
      'numeroPresupuesto': numeroPresupuesto,
      'validezOferta': validezController.text,
      'provincia': provincia,
      'municipio': municipio,
      'direccionCompleta': direccionCompleta,
    };
  }

  void loadFromMap(Map<String, dynamic> data) {
    materiales = (data['materiales'] as List? ?? []).map((item) => MaterialItem.fromMap(item)).toList();
    manoDeObra = (data['manoDeObra'] as List? ?? []).map((item) => ManoDeObraItem.fromMap(item)).toList();
    fletes = (data['fletes'] as List? ?? []).map((item) => FleteItem.fromMap(item)).toList();
    hitosDePago = (data['hitosDePago'] as List? ?? []).map((item) => HitoDePago.fromMap(item)).toList();

    fechaInicioController.text = data['fechaInicio'] ?? '';
    duracionController.text = data['duracionEstimada'] ?? '';
    garantiaController.text = data['garantiaDias']?.toString() ?? '';
    validezController.text = data['validezOferta'] ?? '';
    detallePresupuestoController.text = data['detallesAdicionales'] ?? '';
    incluyeIva = data['incluyeIva'] ?? false;
    
    notifyListeners();
  }
}