// Archivo: lib/widgets/responsive_layout.dart

import 'package:flutter/material.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget child; // El contenido que irá adentro (tu ListView, Column, etc.)

  const ResponsiveLayout({
    super.key,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center( // Centra el contenido en la pantalla
      child: ConstrainedBox( // Limita el ancho máximo
        constraints: const BoxConstraints(maxWidth: 1200), // Límite de 1200px
        child: child, // Muestra el contenido que le pasaste
      ),
    );
  }
}