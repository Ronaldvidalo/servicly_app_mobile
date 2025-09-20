import 'package:flutter/material.dart';
import 'package:servicly_app/Pages/seleccion_provincia_widget.dart/seleccion_provincia_widget.dart';
import 'package:servicly_app/widgets/app_background.dart';

class SeleccionPaisWidget extends StatefulWidget {
  final void Function(bool) onThemeChanged;

  const SeleccionPaisWidget({
    super.key,
    required this.onThemeChanged,
  });

  @override
  State<SeleccionPaisWidget> createState() => _SeleccionPaisWidgetState();
}

class _SeleccionPaisWidgetState extends State<SeleccionPaisWidget> {
  // Se restaura la lista original con todos los datos.
  final List<Map<String, dynamic>> paises = [
    {'nombre': 'Argentina', 'bandera': 'assets/images/Argentina.png', 'ivaAsignado': 0.21},
    {'nombre': 'Brasil', 'bandera': 'assets/images/brasil.jpeg', 'ivaAsignado': 0.17},
    {'nombre': 'Colombia', 'bandera': 'assets/images/colombia.png', 'ivaAsignado': 0.19},
    {'nombre': 'Chile', 'bandera': 'assets/images/chile.png', 'ivaAsignado': 0.19},
    {'nombre': 'España', 'bandera': 'assets/images/españa.jpeg', 'ivaAsignado': 0.21},
    {'nombre': 'Venezuela', 'bandera': 'assets/images/venezuela.png', 'ivaAsignado': 0.16},
  ];

  String? paisSeleccionado;
  // Se mantiene la variable para el IVA, como solicitaste.
  double? ivaPaisSeleccionado;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isLargeScreen = MediaQuery.of(context).size.width > 600;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Selecciona tu país'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                      height:
                          MediaQuery.of(context).padding.top + kToolbarHeight),
                  Text(
                    '¿Desde dónde nos visitas?',
                    style: theme.textTheme.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Selecciona tu país para continuar',
                    style: theme.textTheme.bodyLarge
                        ?.copyWith(color: colorScheme.onSurface.withAlpha(180)),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Wrap(
                    spacing: 20,
                    runSpacing: 20,
                    alignment: WrapAlignment.center,
                    children: paises.map((pais) {
                      final seleccionado = paisSeleccionado == pais['nombre'];
                      return GestureDetector(
                        onTap: () {
                          // Al tocar, guardamos tanto el nombre como el IVA.
                          setState(() {
                            paisSeleccionado = pais['nombre'];
                            ivaPaisSeleccionado = pais['ivaAsignado'];
                          });
                        },
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: seleccionado
                                      ? colorScheme.primary
                                      : theme.dividerColor,
                                  width: seleccionado ? 4 : 2,
                                ),
                                boxShadow: seleccionado
                                    ? [
                                        BoxShadow(
                                          color: colorScheme.primary
                                              .withAlpha(100),
                                          blurRadius: 12,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : [],
                              ),
                              child: CircleAvatar(
                                radius: isLargeScreen ? 48 : 40,
                                backgroundImage:
                                    AssetImage(pais['bandera']!),
                                backgroundColor:
                                    colorScheme.surfaceContainerHighest,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              pais['nombre']!,
                              style: theme.textTheme.bodyLarge?.copyWith(
                                fontWeight: seleccionado
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: seleccionado
                                    ? colorScheme.primary
                                    : colorScheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 40),
                  _buildContinueButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContinueButton() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withAlpha(102),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: paisSeleccionado == null
            ? null
            : () {
                // Buscamos la bandera correspondiente al país seleccionado
                final String banderaPais = paises.firstWhere(
                    (p) => p['nombre'] == paisSeleccionado)['bandera'];

                // La navegación ahora pasa todos los datos necesarios.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => SeleccionProvinciaWidget(
                      paisSeleccionado: paisSeleccionado!,
                      ivaAsignado: ivaPaisSeleccionado!,
                      banderaPais: banderaPais,
                      onThemeChanged: widget.onThemeChanged,
                    ),
                  ),
                );
              },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
          disabledBackgroundColor: Colors.grey.withAlpha(100),
        ),
        child: const Text(
          'Continuar',
          style: TextStyle(
              fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
