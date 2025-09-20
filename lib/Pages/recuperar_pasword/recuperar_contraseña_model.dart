import 'package:flutter/material.dart';

class RecuperarcontraseaModel {
  final emailController = TextEditingController();
  final emailFocusNode = FocusNode();

  void dispose() {
    emailController.dispose();
    emailFocusNode.dispose();
  }
}