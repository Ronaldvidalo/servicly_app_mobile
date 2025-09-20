import 'package:flutter/material.dart';

class InicioSeletcCategoriaModel extends ChangeNotifier {
  String? categoriaSeleccionada;

  void setCategoriaSeleccionada(String? value) {
    categoriaSeleccionada = value;
    notifyListeners();
  }

  void limpiarSeleccion() {
    categoriaSeleccionada = null;
    notifyListeners();
  }
}