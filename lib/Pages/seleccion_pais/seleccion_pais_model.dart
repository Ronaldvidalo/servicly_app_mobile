import 'package:flutter/material.dart';

class SeleccionPaisModel extends ChangeNotifier {
  // Puedes agregar aquí los campos que necesites para tu lógica de selección de país.
  String? paisSeleccionado;

  void seleccionarPais(String pais) {
    paisSeleccionado = pais;
    notifyListeners();
  }

  void limpiarSeleccion() {
    paisSeleccionado = null;
    notifyListeners();
  }
}