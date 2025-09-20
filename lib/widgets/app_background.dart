import 'package:flutter/material.dart';

class AppBackground extends StatelessWidget {
  final Widget child;

  const AppBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDarkMode = Theme.of(context).brightness == Brightness.dark;

    // *** LÓGICA PARA MODO OSCURO ***
    // Define los colores del gradiente según el tema.
    final gradientColors = isDarkMode
        ? [ colorScheme.primary.withAlpha(50), colorScheme.surface ] // Tu gradiente para modo oscuro
        : [ Colors.white, Colors.grey.shade100 ]; // Un gradiente sutil para modo claro (o el que prefieras)

    return Container(
      // La altura y el ancho se ajustan al 100% del padre
      height: double.infinity,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: child, // Aquí se mostrará el contenido de tu página
    );
  }
}