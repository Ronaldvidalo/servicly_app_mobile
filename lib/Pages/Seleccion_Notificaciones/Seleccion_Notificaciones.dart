import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/Pages/home/home_widget.dart';
import 'package:servicly_app/pages/planes/planes_page.dart';
import 'package:servicly_app/data/locations_data.dart';

class SeleccionNotificacionesWidget extends StatefulWidget {
  final String pais;
  final List<String> provinciasDeTrabajo;
  final void Function(bool) onThemeChanged;

  const SeleccionNotificacionesWidget({
    super.key,
    required this.pais,
    required this.provinciasDeTrabajo,
    required this.onThemeChanged,
  });

  @override
  State<SeleccionNotificacionesWidget> createState() => _SeleccionNotificacionesWidgetState();
}

class _SeleccionNotificacionesWidgetState extends State<SeleccionNotificacionesWidget> {
  final List<String> _zonasSeleccionadas = [];
  String _userPlan = 'Free';
  int _limiteSeleccion = 3;
  
  // AHORA: Usamos un Future para cargar los datos de forma asíncrona.
  late Future<void> _loadFuture;

  @override
  void initState() {
    super.initState();
    _loadFuture = _loadUserPlan();
  }

  Future<void> _loadUserPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (mounted && userDoc.exists) {
        _userPlan = userDoc.data()?['plan'] ?? 'Free';
        _limiteSeleccion = _userPlan == 'Free' ? 3 : 6;
      }
    }
  }

  void _onZonaTap(String zona) {
    setState(() {
      if (_zonasSeleccionadas.contains(zona)) {
        _zonasSeleccionadas.remove(zona);
      } else {
        if (_zonasSeleccionadas.length < _limiteSeleccion) {
          _zonasSeleccionadas.add(zona);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Límite alcanzado (${_zonasSeleccionadas.length} de $_limiteSeleccion).'),
              action: _userPlan == 'Free' ? SnackBarAction(
                label: 'Mejorar Plan',
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PlanesPage())),
              ) : null,
            ),
          );
        }
      }
    });
  }

  Future<void> _guardarYFinalizar() async {
    if (_zonasSeleccionadas.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes seleccionar al menos una zona para recibir notificaciones.')));
       return;
    }
    
    // El _isLoading ahora solo se usa aquí.
    setState(() {}); // Para redibujar el botón con el loader
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).set({
        'zonasDeNotificacion': _zonasSeleccionadas,
        'profileComplete': true,
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => HomeWidget(onThemeChanged: widget.onThemeChanged)),
          (route) => false,
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al guardar: $e")));
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('')),
      bottomNavigationBar: _buildBottomBar(),
      // AHORA: FutureBuilder maneja el estado de carga inicial.
      body: FutureBuilder(
        future: _loadFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      'Elige dónde recibir alertas de trabajo',
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Selecciona hasta $_limiteSeleccion municipios.',
                      style: theme.textTheme.bodyLarge,
                      textAlign: TextAlign.center,
                    ),
                     const SizedBox(height: 8),
                    Text(
                      'Seleccionadas: ${_zonasSeleccionadas.length} de $_limiteSeleccion',
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.primary, fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.provinciasDeTrabajo.length,
                  itemBuilder: (context, index) {
                    final provincia = widget.provinciasDeTrabajo[index];
                    final municipios = List<String>.from(allLocationsData[widget.pais]?[provincia] ?? []);
                    municipios.sort();
                    
                    // Contamos solo las selecciones de esta provincia
                    final selectedCount = municipios.where((m) => _zonasSeleccionadas.contains(m)).length;

                    return ExpansionTile(
                      title: Text(provincia, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("$selectedCount municipio(s) seleccionados"),
                      // AHORA: Usamos un ListView.builder interno para una lista eficiente.
                      children: [
                        SizedBox(
                          // Le damos una altura máxima para que sea desplazable si hay muchos
                          height: MediaQuery.of(context).size.height * 0.4,
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: municipios.length,
                            itemBuilder: (context, munIndex) {
                              final municipio = municipios[munIndex];
                              final isSelected = _zonasSeleccionadas.contains(municipio);
                              return CheckboxListTile(
                                title: Text(municipio),
                                value: isSelected,
                                onChanged: (val) => _onZonaTap(municipio),
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor.withOpacity(0.5)))
        ),
        child: FilledButton(
          onPressed: _zonasSeleccionadas.isEmpty ? null : _guardarYFinalizar,
          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
          child: const Text('Finalizar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}