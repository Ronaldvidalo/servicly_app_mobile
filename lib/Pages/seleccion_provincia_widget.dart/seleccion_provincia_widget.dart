import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/Pages/rol_user/rol_user_widget.dart';
import 'package:servicly_app/data/locations_data.dart';

class SeleccionProvinciaWidget extends StatefulWidget {
  final String paisSeleccionado;
  final double ivaAsignado;
  final String banderaPais;
  final void Function(bool) onThemeChanged;

  const SeleccionProvinciaWidget({
    super.key,
    required this.paisSeleccionado,
    required this.ivaAsignado,
    required this.banderaPais,
    required this.onThemeChanged,
  });

  @override
  State<SeleccionProvinciaWidget> createState() =>
      _SeleccionProvinciaWidgetState();
}

class _SeleccionProvinciaWidgetState extends State<SeleccionProvinciaWidget> {
  late List<String> _listaProvincias;
  final List<String> _provinciasSeleccionadas = [];
  bool _todoElPaisSeleccionado = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _listaProvincias = allLocationsData[widget.paisSeleccionado]?.keys.toList() ?? [];
    _listaProvincias.sort();
  }

  Future<void> _guardarYContinuar() async {
    if (_provinciasSeleccionadas.isEmpty && !_todoElPaisSeleccionado) return;

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Usuario no autenticado.")));
      setState(() => _isLoading = false);
      return;
    }

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'pais': widget.paisSeleccionado,
        'provincias': _todoElPaisSeleccionado ? [] : _provinciasSeleccionadas,
        'trabajaEnTodoElPais': _todoElPaisSeleccionado,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => RolUserWidget(
              seleccionpais: widget.paisSeleccionado,
              provincias: _todoElPaisSeleccionado ? ['Todo el país'] : _provinciasSeleccionadas,
              ivaAsignado: widget.ivaAsignado,
              banderaPais: widget.banderaPais,
              onThemeChanged: widget.onThemeChanged,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al guardar la ubicación: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }
  
  // AHORA: Lógica de selección simplificada para los nuevos chips
  void _onProvinciaTap(String provincia) {
    setState(() {
      if (_provinciasSeleccionadas.contains(provincia)) {
        _provinciasSeleccionadas.remove(provincia);
      } else {
        _provinciasSeleccionadas.add(provincia);
        _todoElPaisSeleccionado = false;
      }
    });
  }

  void _onTodoElPaisTap() {
    setState(() {
      _todoElPaisSeleccionado = !_todoElPaisSeleccionado;
      if (_todoElPaisSeleccionado) {
        _provinciasSeleccionadas.clear();
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  '¿Dónde ofreces tus servicios?',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Puedes seleccionar una o varias provincias.',
                  style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withOpacity(0.7)),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          Expanded(
            // AHORA: Usamos GridView para un diseño de tarjetas moderno y responsivo.
            child: GridView.builder(
              padding: const EdgeInsets.all(16.0),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 200, // Ancho máximo de cada item
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 2.8, // Proporción ancho/alto de cada tarjeta
              ),
              itemCount: _listaProvincias.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  // El primer item es la opción "Todo el país"
                  return _buildChip(
                    'Todo el país', 
                    _todoElPaisSeleccionado, 
                    _onTodoElPaisTap, 
                    isFeatured: true
                  );
                }
                final provincia = _listaProvincias[index - 1];
                final isSelected = _provinciasSeleccionadas.contains(provincia);
                return _buildChip(
                  provincia, 
                  isSelected, 
                  () => _onProvinciaTap(provincia)
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Widget para construir las tarjetas de selección
  Widget _buildChip(String label, bool isSelected, VoidCallback onTap, {bool isFeatured = false}) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: isSelected 
            ? colorScheme.primaryContainer 
            : (isFeatured ? colorScheme.secondaryContainer.withOpacity(0.5) : colorScheme.surfaceContainer),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: isSelected || isFeatured ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? colorScheme.onPrimaryContainer : colorScheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final bool isButtonEnabled = _provinciasSeleccionadas.isNotEmpty || _todoElPaisSeleccionado;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)))
        ),
        child: ElevatedButton(
          onPressed: (isButtonEnabled && !_isLoading) ? _guardarYContinuar : null,
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Theme.of(context).colorScheme.primary,
            foregroundColor: Theme.of(context).colorScheme.onPrimary,
          ),
          child: _isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : const Text(
                  'Continuar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
      ),
    );
  }
}