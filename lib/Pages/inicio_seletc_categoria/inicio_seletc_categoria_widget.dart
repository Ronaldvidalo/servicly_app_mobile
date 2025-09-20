import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/widgets/app_background.dart';
import 'package:servicly_app/Pages/Seleccion_Notificaciones/Seleccion_Notificaciones.dart';

class InicioSeletcCategoriaWidget extends StatefulWidget {
  // --- PARÁMETROS ACTUALIZADOS ---
  final String? seleccionpais1;
  final List<String> provincias; // <-- Acepta la lista de provincias
  final String? userRol;
  final String? banderaPais;
  final double ivaAsignado;
  final void Function(bool) onThemeChanged;

  const InicioSeletcCategoriaWidget({
    super.key,
    required this.seleccionpais1,
    required this.provincias, // <-- Acepta la lista de provincias
    required this.userRol,
    required this.banderaPais,
    required this.ivaAsignado,
    required this.onThemeChanged,
  });

  @override
  State<InicioSeletcCategoriaWidget> createState() =>
      _InicioSeletcCategoriaWidgetState();
}

class _InicioSeletcCategoriaWidgetState
    extends State<InicioSeletcCategoriaWidget> {
  // --- LÓGICA DE SELECCIÓN MÚLTIPLE ---
  final List<String> _categoriasSeleccionadas = [];
  final TextEditingController _otrosController = TextEditingController();
  bool _isLoading = false;

  // AHORA: Extraje la lógica de selección para que sea más clara.
  void _onCategoryTap(String label) {
    setState(() {
      if (label == 'Todos') {
        if (_categoriasSeleccionadas.contains('Todos')) {
          // Si 'Todos' ya está seleccionado, se limpia todo.
          _categoriasSeleccionadas.clear();
        } else {
          // AHORA: Si se selecciona 'Todos', se añaden todas las categorías EXCEPTO 'Otros'.
          _categoriasSeleccionadas.clear();
          _categoriasSeleccionadas
              .addAll(categorias.map((c) => c['label'] as String).where(
                    (l) => l != 'Otros',
                  ));
        }
      } else {
        // Lógica para categorías individuales
        if (_categoriasSeleccionadas.contains(label)) {
          _categoriasSeleccionadas.remove(label);
          // Si se deselecciona cualquier otra, 'Todos' también se deselecciona.
          _categoriasSeleccionadas.remove('Todos');
        } else {
          _categoriasSeleccionadas.add(label);
          // Si 'Otros' es seleccionado, no afectamos a 'Todos'
          if (label != 'Otros') {
             // Comprobamos si todas las demás categorías (sin contar 'Otros' y 'Todos') están seleccionadas
            final allOtherCategories = categorias
              .where((c) => c['label'] != 'Todos' && c['label'] != 'Otros')
              .every((c) => _categoriasSeleccionadas.contains(c['label']));

            if(allOtherCategories) {
              _categoriasSeleccionadas.add('Todos');
            }
          }
        }
      }
    });
  }

  final List<Map<String, dynamic>> categorias = [
    {'label': 'Todos', 'icon': Icons.apps},
    {'label': 'Plomería', 'icon': Icons.plumbing},
    {'label': 'Gasista', 'icon': Icons.fire_extinguisher},
    {'label': 'Carpintería', 'icon': Icons.chair},
    {'label': 'Pintor', 'icon': Icons.format_paint},
    {'label': 'Albañil', 'icon': Icons.construction},
    {'label': 'Electricista', 'icon': Icons.electrical_services},
    {'label': 'Refrigeración', 'icon': Icons.ac_unit},
    {'label': 'Arquitectura y construcción', 'icon': Icons.apartment},
    {'label': 'Técnicos', 'icon': Icons.build},
    {'label': 'Jardinería', 'icon': Icons.grass},
    {'label': 'Seguridad', 'icon': Icons.security},
    {'label': 'Mantenimiento', 'icon': Icons.brush},
    {'label': 'Transporte y logística', 'icon': Icons.local_shipping},
    {'label': 'Herrería', 'icon': Icons.home_repair_service},
    {'label': 'Cerrajero', 'icon': Icons.vpn_key},
    {'label': 'Limpieza', 'icon': Icons.cleaning_services},
    {'label': 'Control de plagas', 'icon': Icons.bug_report},
    {'label': 'Soldador', 'icon': Icons.precision_manufacturing},
    {'label': 'Mecánico', 'icon': Icons.car_repair},
    {'label': 'Cuidado de Mascotas', 'icon': Icons.pets},
    {'label': 'Cuidado de Niños', 'icon': Icons.child_care},
    {'label': 'Cuidado de Adultos', 'icon': Icons.elderly},
    {'label': 'Otros', 'icon': Icons.more_horiz},
  ];

  @override
  void dispose() {
    _otrosController.dispose();
    super.dispose();
  }

  Future<void> _finalizarRegistro() async {
    setState(() => _isLoading = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // ... (manejo de error igual que antes)
      return;
    }
    
    List<String> categoriasFinales = List.from(_categoriasSeleccionadas);
    if (_categoriasSeleccionadas.contains('Otros') && _otrosController.text.trim().isNotEmpty) {
      categoriasFinales.remove('Otros');
      categoriasFinales.add(_otrosController.text.trim());
    }
    categoriasFinales.remove('Todos');

    if (categoriasFinales.isEmpty) {
      // ... (manejo de error igual que antes)
      return;
    }
    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'userCategorias': categoriasFinales,
      }, SetOptions(merge: true));

      if (mounted) {
        // AHORA: Navegamos a la pantalla de Zonas de Notificación en lugar del Home.
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => SeleccionNotificacionesWidget(
              pais: widget.seleccionpais1!,
              provinciasDeTrabajo: widget.provincias,
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar categorías: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final bool esOtros = _categoriasSeleccionadas.contains('Otros');
    final bool isNextButtonEnabled = _categoriasSeleccionadas.isNotEmpty &&
        (!esOtros || (_otrosController.text.trim().isNotEmpty));

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
      ),
      // AHORA: Usamos `bottomNavigationBar` para los botones de navegación.
      // Esto garantiza que siempre estén visibles y fijos en la parte inferior.
      bottomNavigationBar:
          _buildNavigationButtons(isNextButtonEnabled, colorScheme),
      body: AppBackground(
        child: CustomScrollView(
          // SafeArea se maneja dentro del CustomScrollView con slivers
          slivers: [
            // Sliver para el espaciado superior, respeta el notch/isla dinámica
            SliverSafeArea(
              sliver: SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  child: Column(
                    children: [
                      Text(
                        'Un último paso, elige tus especialidades',
                        style: theme.textTheme.headlineSmall
                            ?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Puedes seleccionar varias. Esto ayudará a que los clientes te encuentren.',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(color: colorScheme.onSurface.withAlpha(180)),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              sliver: SliverGrid(
                // AHORA: Usamos un número fijo de columnas para mayor consistencia visual.
                // 3 columnas es un buen balance para la mayoría de dispositivos.
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 12.0,
                  crossAxisSpacing: 12.0,
                  childAspectRatio: 1.0,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _buildCategoryCard(categorias[index], colorScheme),
                  childCount: categorias.length,
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                children: [
                  if (esOtros)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
                      child: TextField(
                        controller: _otrosController,
                        decoration: InputDecoration(
                          labelText: 'Especifica tu rubro',
                          filled: true,
                          fillColor:
                              colorScheme.surfaceContainerHighest.withAlpha(77),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none),
                          focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: colorScheme.primary, width: 2)),
                        ),
                        onChanged: (val) => setState(() {}),
                      ),
                    ),
                  // AHORA: El espacio se maneja con el padding inferior del scroll
                  // y el `bottomNavigationBar`, por lo que el SizedBox gigante se elimina.
                  const SizedBox(height: 24),
                ],
              ),
            ),
            // AHORA: Añadimos un padding inferior al final del scroll para que el último
            // elemento no quede pegado a los botones de navegación.
            SliverPadding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
      Map<String, dynamic> cat, ColorScheme colorScheme) {
    final String label = cat['label'];
    final bool seleccionado = _categoriasSeleccionadas.contains(label);

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: seleccionado ? 8.0 : 1.0,
      color: seleccionado
          ? colorScheme.primary.withAlpha(40)
          : colorScheme.surface.withAlpha(80),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: seleccionado
              ? colorScheme.primary
              : colorScheme.outline.withAlpha(50),
          width: seleccionado ? 2.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => _onCategoryTap(label),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(cat['icon'],
                    size: 32,
                    color: seleccionado
                        ? colorScheme.primary
                        : colorScheme.onSurface),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight:
                              seleccionado ? FontWeight.bold : FontWeight.normal,
                          color: seleccionado
                              ? colorScheme.primary
                              : colorScheme.onSurface,
                        ),
                  ),
                ),
              ],
            ),
            if (seleccionado)
              Positioned(
                top: 4,
                right: 4,
                child:
                    Icon(Icons.check_circle, color: colorScheme.primary, size: 20),
              ),
          ],
        ),
      ),
    );
  }

  // AHORA: Este widget es ahora la `bottomNavigationBar`.
  Widget _buildNavigationButtons(bool isEnabled, ColorScheme colorScheme) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom), // Padding para la barra de sistema inferior
      color: colorScheme.surface.withAlpha(200), // Un poco más opaco para legibilidad
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30)),
            ),
            child: const Text('Atrás'),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(30),
              gradient: isEnabled
                  ? LinearGradient(
                      colors: [
                        colorScheme.primary,
                        colorScheme.secondary
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : null,
            ),
            child: ElevatedButton(
              onPressed: (_isLoading || !isEnabled) ? null : _finalizarRegistro,
              style: ElevatedButton.styleFrom(
                backgroundColor: isEnabled ? Colors.transparent : null,
                shadowColor: Colors.transparent,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30)),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Finalizar',
                      style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}