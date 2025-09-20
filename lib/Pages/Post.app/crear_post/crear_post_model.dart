import 'package:flutter/material.dart';

class CrearPostModel {
  // Controladores para los campos del formulario
  final tituloController = TextEditingController();
  final comentarioController = TextEditingController();

  // Si necesitas un PageController para un carrusel local, puedes agregarlo aquí:
  PageController? pageViewController;

  int get pageViewCurrentIndex => pageViewController != null &&
          pageViewController!.hasClients &&
          pageViewController!.page != null
      ? pageViewController!.page!.round()
      : 0;

  void dispose() {
    tituloController.dispose();
    comentarioController.dispose();
    pageViewController?.dispose();
  }
}