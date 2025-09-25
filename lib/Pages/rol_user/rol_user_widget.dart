// lib/Pages/rol_user/rol_user_widget.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/widgets/app_background.dart';
import 'package:servicly_app/Pages/inicio_seletc_categoria/inicio_seletc_categoria_widget.dart';

class RolUserWidget extends StatefulWidget {
  final String seleccionpais;
  final List<String> provincias;
  final String banderaPais;
  final double ivaAsignado;
  final void Function(bool) onThemeChanged;

  const RolUserWidget({
    super.key,
    required this.seleccionpais,
    required this.provincias,
    required this.banderaPais,
    required this.ivaAsignado,
    required this.onThemeChanged,
  });

  @override
  State<RolUserWidget> createState() => _RolUserWidgetState();
}

class _RolUserWidgetState extends State<RolUserWidget> {
  String? _rolSeleccionado;
  bool _isSaving = false;

  static const Color proveedorColor = Colors.blue;
  static const Color clienteColor = Colors.green;
  static const Color ambosColor = Colors.purple;

  final List<Map<String, dynamic>> roles = [
    {'label': 'Ofrecer Servicio', 'value': 'Proveedor', 'icon': Icons.handyman_outlined, 'color': proveedorColor},
    {'label': 'Contratar Servicios', 'value': 'Cliente', 'icon': Icons.shopping_bag_outlined, 'color': clienteColor},
    {'label': 'Ambas', 'value': 'Ambos', 'icon': Icons.sync_alt_rounded, 'color': ambosColor},
  ];

  // ✅ FUNCIÓN CORREGIDA
  Future<void> _guardarRolYContinuar() async {
    if (_rolSeleccionado == null || _isSaving) return;
    setState(() => _isSaving = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Usuario no autenticado.')));
        setState(() => _isSaving = false);
      }
      return;
    }

    try {
      if (_rolSeleccionado == 'Cliente') {
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
          'rol_user': _rolSeleccionado,
          'profileComplete': true,
        });
        
        if (mounted) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }

      } else {
        await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
          'rol_user': _rolSeleccionado,
        });

        // ✅ CORRECCIÓN: Añadimos todos los parámetros requeridos
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => InicioSeletcCategoriaWidget(
                // Datos que vienen de la pantalla anterior
                seleccionpais1: widget.seleccionpais,
                provincias: widget.provincias,
                banderaPais: widget.banderaPais,
                ivaAsignado: widget.ivaAsignado,
                // Dato que se seleccionó en ESTA pantalla
                userRol: _rolSeleccionado!, // Usamos '!' porque sabemos que no es nulo aquí
                // Callback del tema
                onThemeChanged: widget.onThemeChanged,
              )
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar el perfil: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // El método build no necesita cambios
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Selecciona tu rol'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        automaticallyImplyLeading: false,
      ),
      bottomNavigationBar: _buildBottomBar(),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundImage: AssetImage(widget.banderaPais),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                ),
                const SizedBox(height: 24),
                Text(
                  '¿Qué deseas hacer en la aplicación?',
                  style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: roles.map((rol) {
                    return _buildRoleCard(
                      context: context,
                      label: rol['label'],
                      value: rol['value'],
                      icon: rol['icon'],
                      color: rol['color'],
                      isSelected: _rolSeleccionado == rol['value'],
                      onTap: () => setState(() => _rolSeleccionado = rol['value']),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    // Este widget no necesita cambios
    final colorScheme = Theme.of(context).colorScheme;
    const double size = 160.0;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: size,
        height: size,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? color.withAlpha(40) : colorScheme.surface.withAlpha(100),
          border: Border.all(
            color: isSelected ? color : Colors.transparent,
            width: 3,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: isSelected
              ? [BoxShadow(color: color.withAlpha(70), blurRadius: 12, spreadRadius: 2)]
              : [],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 48, color: isSelected ? color : colorScheme.onSurface),
            const SizedBox(height: 12),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        color: isSelected ? color : colorScheme.onSurface,
                      ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    // Este widget no necesita cambios
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        color: Theme.of(context).colorScheme.surface.withAlpha((255 * 0.8).round()),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  gradient: _rolSeleccionado != null
                      ? LinearGradient(
                          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
                          begin: Alignment.centerLeft, end: Alignment.centerRight,
                        )
                      : null,
                ),
                child: ElevatedButton.icon(
                  onPressed: (_isSaving || _rolSeleccionado == null) ? null : _guardarRolYContinuar,
                  icon: _isSaving
                      ? Container(
                          width: 20,
                          height: 20,
                          padding: const EdgeInsets.all(2.0),
                          child: const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                        )
                      : const Icon(Icons.arrow_forward),
                  label: Text(_isSaving ? 'Guardando...' : 'Siguiente'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _rolSeleccionado != null ? Colors.transparent : null,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}