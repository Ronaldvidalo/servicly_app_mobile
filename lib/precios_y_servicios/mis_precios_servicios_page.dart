// lib/pages/mis_precios_servicios_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/models/item_servicio_model.dart';
import 'package:servicly_app/pages/planes/planes_page.dart'; // Para el botón de "Ver Planes"

class MisPreciosServiciosPage extends StatefulWidget {
  const MisPreciosServiciosPage({super.key});

  @override
  State<MisPreciosServiciosPage> createState() => _MisPreciosServiciosPageState();
}

class _MisPreciosServiciosPageState extends State<MisPreciosServiciosPage> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  String? _userPlan; // Para guardar el plan del usuario
  bool _isLoading = true; // Para manejar el estado de carga

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  /// Carga el plan del usuario desde Firestore.
  Future<void> _loadUserData() async {
    if (currentUserId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUserId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _userPlan = userDoc.data()?['plan'] ?? 'Free';
        });
      }
    } catch (e) {
      debugPrint("Error cargando el plan del usuario: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showItemForm({ItemServicio? item}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _ItemForm(item: item),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(appBar: AppBar(title: const Text('Mis Precios y Servicios')), body: const Center(child: CircularProgressIndicator()));
    }

    // --- LÓGICA DE PERMISOS ---
    final bool tieneAcceso = (_userPlan == 'Premium' || _userPlan == 'fundador');
 final theme = Theme.of(context); 

   return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Precios y Servicios'),
        // --- CAMBIO DE COLOR AQUÍ ---
        // Usamos el color primario de tu tema para consistencia.
        backgroundColor: theme.colorScheme.primary,
        // Y el color de contraste para el texto y los íconos.
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      body: tieneAcceso
          ? _buildContentView()
          : _buildUpgradeView(),
      floatingActionButton: tieneAcceso
          ? FloatingActionButton(
              onPressed: () => _showItemForm(),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  /// Vista que se muestra si el usuario NO tiene acceso.
  Widget _buildUpgradeView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.workspace_premium_outlined, size: 60, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text('Función Premium', style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text(
              'Guardá tus precios y servicios para crear presupuestos en segundos. ¡Actualizá tu plan para acceder!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.star),
              label: const Text('Ver Planes Premium'),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const PlanesPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Vista principal con la lista de precios si SÍ tiene acceso.
  Widget _buildContentView() {
    return Column(
      children: [
        if (_userPlan == 'fundador')
          _buildPlanFundadorBanner(), // Mostramos el banner solo para fundadores

        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('usuarios')
                .doc(currentUserId)
                .collection('precios_y_servicios')
                .orderBy('fecha_creacion', descending: true)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Aún no tienes ítems guardados.\n\nPresiona el botón "+" para añadir tu primer precio o servicio recurrente.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.grey),
                    ),
                  ),
                );
              }

              final items = snapshot.data!.docs.map((doc) => ItemServicio.fromFirestore(doc)).toList();
              final Map<String, List<ItemServicio>> groupedItems = {};
              for (var item in items) {
                (groupedItems[item.tipo] ??= []).add(item);
              }
              final orderedKeys = ['mano_de_obra', 'material', 'flete'].where((key) => groupedItems.containsKey(key)).toList();

              return ListView.builder(
                padding: const EdgeInsets.all(8.0),
                itemCount: orderedKeys.length,
                itemBuilder: (context, index) {
                  final key = orderedKeys[index];
                  final sectionItems = groupedItems[key]!;
                  final title = key == 'mano_de_obra' ? 'Mano de Obra' : (key == 'material' ? 'Materiales' : 'Fletes y Otros');

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(title.toUpperCase(), style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                      ),
                      ...sectionItems.map((item) {
                        return Dismissible(
                          key: ValueKey(item.id),
                          direction: DismissDirection.endToStart,
                          background: Container(
                            color: Colors.red.shade700,
                            alignment: Alignment.centerRight,
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: const Icon(Icons.delete_sweep, color: Colors.white),
                          ),
                          onDismissed: (direction) {
                            FirebaseFirestore.instance.collection('usuarios').doc(currentUserId).collection('precios_y_servicios').doc(item.id).delete();
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${item.descripcion} eliminado')));
                          },
                          child: Card(
                            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: ListTile(
                              title: Text(item.descripcion),
                              subtitle: Text(item.unidad),
                              trailing: Text('\$${item.precio.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              onTap: () => _showItemForm(item: item),
                            ),
                          ),
                        );
                      }),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  /// Widget del banner del Plan Fundador.
  Widget _buildPlanFundadorBanner() {
    return Card(
      margin: const EdgeInsets.all(12),
      color: Theme.of(context).colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            Icon(Icons.auto_awesome, color: Theme.of(context).colorScheme.onTertiaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                "¡Tenés acceso a esta función gracias a tu Plan Fundador!",
                style: TextStyle(color: Theme.of(context).colorScheme.onTertiaryContainer, fontWeight: FontWeight.w500),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- FORMULARIO PARA AÑADIR/EDITAR UN ÍTEM ---
class _ItemForm extends StatefulWidget {
  final ItemServicio? item;
  const _ItemForm({this.item});

  @override
  State<_ItemForm> createState() => _ItemFormState();
}

class _ItemFormState extends State<_ItemForm> {
  final _formKey = GlobalKey<FormState>();
  late String _descripcion;
  late double _precio;
  late String _unidad;
  late String _tipo;
  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    _descripcion = widget.item?.descripcion ?? '';
    _precio = widget.item?.precio ?? 0.0;
    _unidad = widget.item?.unidad ?? 'unidad';
    _tipo = widget.item?.tipo ?? 'material';
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    _formKey.currentState!.save();
    final String currentUserId = FirebaseAuth.instance.currentUser!.uid;
    final collectionRef = FirebaseFirestore.instance.collection('usuarios').doc(currentUserId).collection('precios_y_servicios');

    if (_isEditing) {
      collectionRef.doc(widget.item!.id).update({
        'descripcion': _descripcion,
        'precio': _precio,
        'unidad': _unidad,
        'tipo': _tipo,
      });
    } else {
      collectionRef.add({
        'descripcion': _descripcion,
        'precio': _precio,
        'unidad': _unidad,
        'tipo': _tipo,
        'fecha_creacion': FieldValue.serverTimestamp(),
      });
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_isEditing ? 'Editar Ítem' : 'Añadir Ítem', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            TextFormField(
              initialValue: _descripcion,
              decoration: const InputDecoration(labelText: 'Descripción'),
              validator: (value) => (value == null || value.isEmpty) ? 'Campo requerido' : null,
              onSaved: (value) => _descripcion = value!,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _precio > 0 ? _precio.toString() : '',
              decoration: const InputDecoration(labelText: 'Precio', prefixText: '\$'),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) => (value == null || value.isEmpty || double.tryParse(value) == null) ? 'Precio inválido' : null,
              onSaved: (value) => _precio = double.parse(value!),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: _unidad,
              decoration: const InputDecoration(labelText: 'Unidad de Medida', hintText: 'ej: unidad, hora, m², etc.'),
              validator: (value) => (value == null || value.isEmpty) ? 'Campo requerido' : null,
              onSaved: (value) => _unidad = value!,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de Ítem'),
              items: const [
                DropdownMenuItem(value: 'material', child: Text('Material')),
                DropdownMenuItem(value: 'mano_de_obra', child: Text('Mano de Obra')),
                DropdownMenuItem(value: 'flete', child: Text('Flete / Otro')),
              ],
              onChanged: (value) {
                if(value != null) setState(() => _tipo = value);
              },
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: Text(_isEditing ? 'Guardar Cambios' : 'Añadir Ítem'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}