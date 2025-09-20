import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/widgets/app_background.dart';
import 'package:servicly_app/widgets/custom_text_field.dart';
import 'package:servicly_app/widgets/main_button.dart';

class RecuperarPaswordWidget extends StatefulWidget {
  const RecuperarPaswordWidget({super.key});

  @override
  State<RecuperarPaswordWidget> createState() => _RecuperarPaswordWidgetState();
}

class _RecuperarPaswordWidgetState extends State<RecuperarPaswordWidget> {
  final _emailController = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  // *** MEJORA: Función con manejo de errores más específico ***
  Future<void> _enviarLink() async {
    setState(() { _loading = true; _error = null; });
    final email = _emailController.text.trim();

    if (email.isEmpty) {
      setState(() { _loading = false; _error = '¡El correo es requerido!'; });
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
          content: const Text(
            'Enlace enviado a tu correo.\nRevisa tu bandeja de entrada y spam.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16),
          ),
          actionsAlignment: MainAxisAlignment.center,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      if (mounted) Navigator.of(context).pop();

    } on FirebaseAuthException catch (e) {
      String errorMessage = 'Ocurrió un error al enviar el enlace.';
      if (e.code == 'user-not-found') {
        errorMessage = 'No se encontró ninguna cuenta con ese correo.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo no es válido.';
      }
      setState(() { _error = errorMessage; });

    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      // *** MEJORA: Se quita el color de fondo para que AppBackground funcione ***
      extendBodyBehindAppBar: true, // Permite que el cuerpo se extienda detrás del AppBar
      appBar: AppBar(
        // *** MEJORA: AppBar transparente y con colores del tema ***
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.chevron_left, color: colorScheme.primary, size: 28),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Volver',
        ),
        title: Text(
          'Recuperar Contraseña',
          style: TextStyle(
            color: colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      // *** MEJORA: Se aplica el widget de fondo a toda la página ***
      body: AppBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_reset, color: colorScheme.primary, size: 56),
                  const SizedBox(height: 18),
                  Text(
                    '¿Olvidaste tu contraseña?',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Te enviaremos un enlace para restablecer tu contraseña. Ingresa el correo asociado a tu cuenta.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface.withAlpha(180),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        _error!,
                        style: TextStyle(color: colorScheme.error, fontSize: 15),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  CustomTextField(
                    controller: _emailController,
                    label: 'Correo electrónico',
                    icon: Icons.email_outlined,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !_loading,
                  ),
                  const SizedBox(height: 28),
                  MainButton(
                    text: 'Enviar enlace',
                    onPressed: _enviarLink,
                    loading: _loading,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}