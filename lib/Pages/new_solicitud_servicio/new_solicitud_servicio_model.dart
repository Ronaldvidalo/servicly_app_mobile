import 'package:flutter/material.dart';

class SolicitudServicioNewModel extends ChangeNotifier {
  int currentPage = 0;

  // Controladores para los formularios
  PageController pageController = PageController();

  String? categoriaSeleccionada;
  TextEditingController tituloController = TextEditingController();
  TextEditingController detallesController = TextEditingController();
  TextEditingController medidasController = TextEditingController();

  bool incluyeMaterialProveedor = false;
  bool incluyeMaterialCliente = false;
  bool materialesAdefinir = false;

  TextEditingController calleController = TextEditingController();
  TextEditingController numeroController = TextEditingController();
  TextEditingController provinciaController = TextEditingController();
  TextEditingController municipioController = TextEditingController();
  TextEditingController referenciaController = TextEditingController();

  String? fotoPath;
  DateTime? fechaSeleccionada;
  String? horarioSeleccionado;
  bool urgente = false;
  bool programable = false;
  String? metodoPago;

  @override
  void dispose() {
    pageController.dispose();
    tituloController.dispose();
    detallesController.dispose();
    medidasController.dispose();
    calleController.dispose();
    numeroController.dispose();
    provinciaController.dispose();
    municipioController.dispose();
    referenciaController.dispose();
    super.dispose();
  }
}