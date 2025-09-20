import 'package:flutter/material.dart';

class RolUserModel extends ChangeNotifier {
  String? dropDownValue;

  void setDropDownValue(String? value) {
    dropDownValue = value;
    notifyListeners();
  }

  void limpiarSeleccion() {
    dropDownValue = null;
    notifyListeners();
  }
}