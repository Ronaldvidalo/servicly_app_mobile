import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';

class VerificacionPage extends StatefulWidget {
  const VerificacionPage({super.key});

  @override
  State<VerificacionPage> createState() => _VerificacionPageState();
}

class _VerificacionPageState extends State<VerificacionPage> {
  int _currentStep = 0;
  bool _isLoading = false;

  // Step 1: Contacto
  final _phoneController = TextEditingController();

  // Step 2: Dirección
  final _addressFormKey = GlobalKey<FormState>();
  final _streetController = TextEditingController();
  final _cityController = TextEditingController();
  final _stateController = TextEditingController();
  final _postalCodeController = TextEditingController();
  final _countryController = TextEditingController(text: "Argentina");

  // Step 3: Documentos
  File? _documentImageFile;
  File? _selfieImageFile;
  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _phoneController.dispose();
    _streetController.dispose();
    _cityController.dispose();
    _stateController.dispose();
    _postalCodeController.dispose();
    _countryController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source, {required bool isDocument}) async {
    final pickedFile = await _picker.pickImage(source: source, imageQuality: 80);
    if (pickedFile != null) {
      setState(() {
        if (isDocument) {
          _documentImageFile = File(pickedFile.path);
        } else {
          _selfieImageFile = File(pickedFile.path);
        }
      });
    }
  }

  Future<void> _submitForVerification() async {
    if (!_addressFormKey.currentState!.validate() || _documentImageFile == null || _selfieImageFile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos y sube las imágenes requeridas.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // 1. Subir documento de identidad
      final docRef = FirebaseStorage.instance.ref().child('verificaciones/${user.uid}/documento_identidad.jpg');
      await docRef.putFile(_documentImageFile!);
      final docUrl = await docRef.getDownloadURL();

      // 2. Subir selfie
      final selfieRef = FirebaseStorage.instance.ref().child('verificaciones/${user.uid}/selfie.jpg');
      await selfieRef.putFile(_selfieImageFile!);
      final selfieUrl = await selfieRef.getDownloadURL();

      // 3. Guardar toda la información en Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
        'estadoVerificacion': 'en_revision',
        'documentoVerificacionUrl': docUrl,
        'selfieVerificacionUrl': selfieUrl,
        'fechaSolicitudVerificacion': FieldValue.serverTimestamp(),
        'direccion': {
          'calle': _streetController.text,
          'ciudad': _cityController.text,
          'provincia': _stateController.text,
          'codigoPostal': _postalCodeController.text,
          'pais': _countryController.text,
        },
        'telefono': _phoneController.text,
      });

      if(mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documentos enviados. Tu verificación está en proceso.'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar los documentos: $e')),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verificación de Identidad'),
      ),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < 2) {
            setState(() => _currentStep += 1);
          } else {
            _submitForVerification();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) {
            setState(() => _currentStep -= 1);
          }
        },
        steps: _buildSteps(),
        controlsBuilder: (context, details) {
          return Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
                    children: [
                      ElevatedButton(
                        onPressed: details.onStepContinue,
                        child: Text(_currentStep == 2 ? 'Enviar' : 'Siguiente'),
                      ),
                      if (_currentStep > 0)
                        TextButton(
                          onPressed: details.onStepCancel,
                          child: const Text('Atrás'),
                        ),
                    ],
                  ),
          );
        },
      ),
    );
  }

  List<Step> _buildSteps() {
    final user = FirebaseAuth.instance.currentUser;
    return [
      Step(
        title: const Text('Contacto'),
        isActive: _currentStep >= 0,
        state: _currentStep > 0 ? StepState.complete : StepState.indexed,
        content: Column(
          children: [
            _buildVerificationTile(
              title: 'Correo Electrónico',
              subtitle: user?.email ?? 'No disponible',
              isVerified: user?.emailVerified ?? false,
              onVerify: () async {
                await user?.sendEmailVerification();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Se ha enviado un correo de verificación.')),
                );
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Número de Teléfono',
                hintText: 'Ej: +54 9 11 12345678',
              ),
              keyboardType: TextInputType.phone,
            ),
             const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                // TODO: Implementar lógica de verificación por SMS con Firebase
              },
              child: const Text("Verificar Teléfono"),
            )
          ],
        ),
      ),
      Step(
        title: const Text('Dirección'),
        isActive: _currentStep >= 1,
        state: _currentStep > 1 ? StepState.complete : StepState.indexed,
        content: Form(
          key: _addressFormKey,
          child: Column(
            children: [
              TextFormField(controller: _streetController, decoration: const InputDecoration(labelText: 'Calle y Número'), validator: (v) => v!.isEmpty ? 'Campo requerido' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _cityController, decoration: const InputDecoration(labelText: 'Ciudad'), validator: (v) => v!.isEmpty ? 'Campo requerido' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _stateController, decoration: const InputDecoration(labelText: 'Provincia / Estado'), validator: (v) => v!.isEmpty ? 'Campo requerido' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _postalCodeController, decoration: const InputDecoration(labelText: 'Código Postal'), validator: (v) => v!.isEmpty ? 'Campo requerido' : null),
              const SizedBox(height: 8),
              TextFormField(controller: _countryController, decoration: const InputDecoration(labelText: 'País'), validator: (v) => v!.isEmpty ? 'Campo requerido' : null),
            ],
          ),
        ),
      ),
      Step(
        title: const Text('Documentos'),
        isActive: _currentStep >= 2,
        content: Column(
          children: [
            _buildImagePicker(
              title: 'Documento de Identidad',
              subtitle: 'Sube una foto clara del frente de tu DNI o Pasaporte.',
              imageFile: _documentImageFile,
              onPickImage: (source) => _pickImage(source, isDocument: true),
            ),
            const SizedBox(height: 24),
            _buildImagePicker(
              title: 'Selfie',
              subtitle: 'Sube una foto tuya (selfie) sosteniendo tu documento de identidad.',
              imageFile: _selfieImageFile,
              onPickImage: (source) => _pickImage(source, isDocument: false),
            ),
          ],
        ),
      ),
    ];
  }

  Widget _buildVerificationTile({
    required String title,
    required String subtitle,
    required bool isVerified,
    required VoidCallback onVerify,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(subtitle),
      trailing: isVerified
          ? const Icon(Icons.check_circle, color: Colors.green)
          : TextButton(onPressed: onVerify, child: const Text('Verificar')),
    );
  }

  Widget _buildImagePicker({
    required String title,
    required String subtitle,
    required File? imageFile,
    required Function(ImageSource) onPickImage,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          height: 150,
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).dividerColor),
            borderRadius: BorderRadius.circular(12),
          ),
          child: imageFile != null
              ? ClipRRect(borderRadius: BorderRadius.circular(11), child: Image.file(imageFile, fit: BoxFit.cover))
              : Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton.icon(icon: const Icon(Icons.camera_alt), label: const Text('Cámara'), onPressed: () => onPickImage(ImageSource.camera)),
                      TextButton.icon(icon: const Icon(Icons.photo_library), label: const Text('Galería'), onPressed: () => onPickImage(ImageSource.gallery)),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
