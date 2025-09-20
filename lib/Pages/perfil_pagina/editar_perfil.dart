import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class EditarPerfilPage extends StatefulWidget {
  const EditarPerfilPage({super.key});

  @override
  State<EditarPerfilPage> createState() => _EditarPerfilPageState();
}

class _EditarPerfilPageState extends State<EditarPerfilPage> {
  final _formKey = GlobalKey<FormState>();
  final String currentUserId = FirebaseAuth.instance.currentUser!.uid;

  // Controladores para los campos de texto
  late TextEditingController _nameController;
  late TextEditingController _descriptionController;

  // Variables de estado
  bool _isLoading = true;
  bool _isSaving = false;
  bool _hasChanges = false;
  
  String? _selectedCountry;
  String? _initialCountry;
  Map<String, dynamic> _userData = {};
  File? _imageFile;

  // Lista de países (reemplazar con tu lista completa)
  final List<String> _countries = ['Argentina', 'Bolivia', 'Chile', 'Colombia', 'Ecuador', 'España', 'México', 'Perú', 'Uruguay', 'Venezuela'];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUserId).get();
      if (doc.exists) {
        _userData = doc.data()!;
        _nameController.text = _userData['display_name'] ?? '';
        _descriptionController.text = _userData['descripcion'] ?? '';
        _initialCountry = _userData['pais'];
        _selectedCountry = _userData['pais'];
        
        // Añadir listeners después de cargar los datos iniciales
        _addListeners();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al cargar datos: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _addListeners() {
    _nameController.addListener(_checkForChanges);
    _descriptionController.addListener(_checkForChanges);
  }

  void _checkForChanges() {
    final nameChanged = _nameController.text != (_userData['display_name'] ?? '');
    final descChanged = _descriptionController.text != (_userData['descripcion'] ?? '');
    final countryChanged = _selectedCountry != _initialCountry;
    final imageChanged = _imageFile != null;

    if (nameChanged || descChanged || countryChanged || imageChanged) {
      if (!_hasChanges) setState(() => _hasChanges = true);
    } else {
      if (_hasChanges) setState(() => _hasChanges = false);
    }
  }

  Future<void> _pickImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        _checkForChanges();
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;
    
    setState(() => _isSaving = true);

    try {
      String? photoUrl = _userData['photo_url'];

      // 1. Subir nueva imagen si existe
      if (_imageFile != null) {
        final ref = FirebaseStorage.instance.ref().child('profile_pictures').child(currentUserId).child('profile.jpg');
        await ref.putFile(_imageFile!);
        photoUrl = await ref.getDownloadURL();
      }

      // 2. Preparar los datos a actualizar en Firestore
      final Map<String, dynamic> dataToUpdate = {};
      if (_nameController.text != (_userData['display_name'] ?? '')) dataToUpdate['display_name'] = _nameController.text;
      if (_descriptionController.text != (_userData['descripcion'] ?? '')) dataToUpdate['descripcion'] = _descriptionController.text;
      if (_selectedCountry != _initialCountry) dataToUpdate['pais'] = _selectedCountry;
      if (photoUrl != _userData['photo_url']) dataToUpdate['photo_url'] = photoUrl;
      
      // 3. Actualizar Firestore solo si hay cambios
      if (dataToUpdate.isNotEmpty) {
        await FirebaseFirestore.instance.collection('usuarios').doc(currentUserId).update(dataToUpdate);
      }
      
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Perfil actualizado con éxito')));
      Navigator.of(context).pop();

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar el perfil: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar Perfil'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: TextButton(
              onPressed: _hasChanges && !_isSaving ? _saveProfile : null,
              child: _isSaving
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Guardar'),
            ),
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECCIÓN FOTO DE PERFIL ---
                    Center(
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                            backgroundImage: _imageFile != null
                                ? FileImage(_imageFile!)
                                : (_userData['photo_url'] != null ? NetworkImage(_userData['photo_url']) : null) as ImageProvider?,
                            child: _imageFile == null && _userData['photo_url'] == null
                                ? const Icon(Icons.person, size: 60)
                                : null,
                          ),
                          Positioned(
                            bottom: 0,
                            right: 0,
                            child: CircleAvatar(
                              radius: 20,
                              backgroundColor: Theme.of(context).colorScheme.primary,
                              child: IconButton(
                                icon: const Icon(Icons.edit, color: Colors.white, size: 20),
                                onPressed: _pickImage,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- CAMPOS EDITABLES ---
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Nombre a mostrar', border: OutlineInputBorder()),
                      validator: (value) => value!.isEmpty ? 'El nombre no puede estar vacío' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(labelText: 'Descripción', border: OutlineInputBorder(), alignLabelWithHint: true),
                      maxLines: 4,
                      maxLength: 200,
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: _selectedCountry,
                      items: _countries.map((String country) {
                        return DropdownMenuItem<String>(value: country, child: Text(country));
                      }).toList(),
                      onChanged: (newValue) {
                        setState(() {
                          _selectedCountry = newValue;
                          _checkForChanges();
                        });
                      },
                      decoration: const InputDecoration(labelText: 'País', border: OutlineInputBorder()),
                    ),
                    const SizedBox(height: 32),

                    // --- SECCIÓN DE SUSCRIPCIÓN ---
                    Text("Mi Plan", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Card(
                      child: ListTile(
                        leading: Icon(
                          _userData['planNombre'] == 'Premium' ? Icons.star_rounded : Icons.shield_outlined,
                          color: _userData['planNombre'] == 'Premium' ? Colors.amber : Colors.blueGrey,
                        ),
                        title: Text(_userData['planNombre'] ?? 'Básico', style: const TextStyle(fontWeight: FontWeight.bold)),
                        trailing: OutlinedButton(
                          onPressed: () { /* Navegar a la página de planes */ },
                          child: const Text('Mejorar Plan'),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- SECCIÓN DE ROL ---
                    Text("Mi Rol", style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    ListTile(
                      title: Text(_userData['rol_user'] ?? 'No definido'),
                      subtitle: _userData['rol_user'] == 'Cliente' 
                          ? const Text('Activa la opción para empezar a ofrecer tus servicios.')
                          : const Text('Gestionas tus servicios como Proveedor.'),
                      trailing: _userData['rol_user'] == 'Cliente'
                          ? Switch(value: false, onChanged: (value) { /* Lógica para iniciar conversión a proveedor */ })
                          : null,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}