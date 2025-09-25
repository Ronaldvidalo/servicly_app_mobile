// lib/Pages/crear_cuenta/crear_cuenta_widget.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/widgets/app_background.dart';
import 'dart:ui';
import 'dart:developer' as developer;
import 'package:servicly_app/services/auth_service.dart';

class CrearCuentaWidget extends StatefulWidget {
  const CrearCuentaWidget({super.key});

  @override
  State<CrearCuentaWidget> createState() => _CrearCuentaWidgetState();
}

class _CrearCuentaWidgetState extends State<CrearCuentaWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _loading = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  final AuthService _authService = AuthService();

  @override
  void dispose() {
    _nombreController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  // ✅ MÉTODO CORREGIDO
  Future<void> _crearCuenta() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => _loading = true);

    try {
      final userCredential = await _authService.signUpWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        displayName: _nombreController.text.trim(),
      );

    
      if (userCredential != null && mounted) {
              Navigator.of(context).pop();
      }

    } on FirebaseAuthException catch (e) {
      // Tu manejo de errores se mantiene igual, está perfecto.
      String errorMessage = 'Ocurrió un error de autenticación.';
      if (e.code == 'weak-password') {
        errorMessage = 'La contraseña es muy débil (mínimo 6 caracteres).';
      } else if (e.code == 'email-already-in-use') {
        errorMessage = 'Ya existe una cuenta con este correo.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo no es válido.';
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      developer.log('Error inesperado al crear cuenta:', error: e, name: 'CrearCuenta');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Ocurrió un error inesperado.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    // El resto de tu archivo (el método build y sus helpers) no necesita ningún cambio.
    // Simplemente asegúrate de que esta función _crearCuenta esté actualizada.
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Registro'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
      ),
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                        height:
                            MediaQuery.of(context).padding.top + kToolbarHeight),
                    Image.asset('assets/icon/SB1024.png', height: 100),
                    const SizedBox(height: 24),
                    Text(
                      'Crea tu cuenta',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: colorScheme.surface.withAlpha(178),
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: colorScheme.secondary.withAlpha(51)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _buildTextField(
                                controller: _nombreController,
                                labelText: 'Nombre y Apellido',
                                icon: Icons.person_outline,
                                validator: (value) => value!.isEmpty
                                    ? 'Por favor, ingresa tu nombre'
                                    : null,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _emailController,
                                labelText: 'Correo electrónico',
                                icon: Icons.email_outlined,
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) =>
                                    (value == null || !value.contains('@'))
                                        ? 'Ingresa un correo válido'
                                        : null,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _passwordController,
                                labelText: 'Crear contraseña',
                                icon: Icons.lock_outline,
                                isPassword: true,
                                showPassword: _showPassword,
                                onToggleVisibility: () =>
                                    setState(() => _showPassword = !_showPassword),
                                validator: (value) =>
                                    (value == null || value.length < 6)
                                        ? 'Mínimo 6 caracteres'
                                        : null,
                              ),
                              const SizedBox(height: 20),
                              _buildTextField(
                                controller: _confirmPasswordController,
                                labelText: 'Confirmar contraseña',
                                icon: Icons.lock_person_outlined,
                                isPassword: true,
                                showPassword: _showConfirmPassword,
                                onToggleVisibility: () => setState(() =>
                                    _showConfirmPassword = !_showConfirmPassword),
                                validator: (value) =>
                                    (value != _passwordController.text)
                                        ? 'Las contraseñas no coinciden'
                                        : null,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    _buildRegisterButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

    Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    required IconData icon,
    String? Function(String?)? validator,
    bool isPassword = false,
    bool showPassword = false,
    VoidCallback? onToggleVisibility,
    TextInputType? keyboardType,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      obscureText: isPassword && !showPassword,
      keyboardType: keyboardType,
      validator: validator,
      enabled: !_loading,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: colorScheme.onSurface.withAlpha(153)),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPassword ? Icons.visibility_off : Icons.visibility,
                  color: colorScheme.onSurface.withAlpha(153),
                ),
                onPressed: onToggleVisibility,
              )
            : null,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(77),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Container(
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
        onPressed: _loading ? null : _crearCuenta,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: _loading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2))
            : const Text('Crear cuenta y continuar',
                style: TextStyle(
                    fontSize: 16,
                    color: Colors.white,
                    fontWeight: FontWeight.bold)),
      ),
    );
  }
}