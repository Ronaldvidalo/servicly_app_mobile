// lib/pages/inicio/inicio_widget.dart

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:servicly_app/Pages/recuperar_pasword/recuperar_pasword_widget.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:ui';
import 'package:servicly_app/Pages/inicio/auth_wrapper.dart';
import 'package:servicly_app/Pages/crear_cuenta/crear_cuenta_widget.dart';
import 'package:app_links/app_links.dart';

// Imports para la navegación por deep link
import 'package:servicly_app/pages/post_detalle/post_detalle_page.dart';
import 'package:servicly_app/Pages/detalle_solicitud/detalle_solicitud_servicio_widget.dart';
import 'package:servicly_app/models/solicitud_model.dart';


String? referrerId;

class InicioWidget extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  const InicioWidget({super.key, required this.onThemeChanged});

  @override
  State<InicioWidget> createState() => _InicioWidgetState();
}

class _InicioWidgetState extends State<InicioWidget> {
  // --- VARIABLES DE ESTADO RESTAURADAS ---
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _showPassword = false;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initAppLinks();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _initAppLinks() async {
    final appLinks = AppLinks();
    final initialUri = await appLinks.getInitialAppLink();
    if (initialUri != null) {
      _handleLink(initialUri);
    }
    appLinks.uriLinkStream.listen((uri) {
      if (mounted) {
        _handleLink(uri);
      }
    });
  }

  void _handleLink(Uri link) async {
    if (link.pathSegments.contains('refer') && link.queryParameters.containsKey('by')) {
      setState(() {
        referrerId = link.queryParameters['by'];
        debugPrint('✅ Usuario referido por: $referrerId');
      });
    } else if (link.pathSegments.contains('post') && link.queryParameters.containsKey('id')) {
      final postId = link.queryParameters['id'];
      if (postId != null) {
        debugPrint('✅ Abriendo post con ID: $postId');
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PostDetallePage(postId: postId)),
        );
      }
    } else if (link.pathSegments.contains('service') && link.queryParameters.containsKey('id')) {
      final serviceId = link.queryParameters['id'];
      if (serviceId != null) {
        debugPrint('✅ Abriendo solicitud con ID: $serviceId');
        try {
          final doc = await FirebaseFirestore.instance.collection('solicitudes').doc(serviceId).get();
          if (doc.exists && mounted) {
            final solicitud = Solicitud.fromFirestore(doc);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => DetalleSolicitudWidget(solicitud: solicitud)),
            );
          } else {
            debugPrint('❌ Solicitud con ID $serviceId no encontrada.');
          }
        } catch (e) {
          debugPrint('❌ Error al cargar solicitud: $e');
        }
      }
    }
  }

  Future<void> _checkAndCreateUserProfile(User user) async {
    final userDocRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
    final docSnapshot = await userDocRef.get();
    if (!docSnapshot.exists) {
      await userDocRef.set({
        'uid': user.uid,
        'display_name': user.displayName ?? 'Usuario Anónimo',
        'email': user.email,
        'photo_url': user.photoURL,
        'created_time': FieldValue.serverTimestamp(),
        'rating': 0.0,
        'ratingCount': 0,
        'plan': 'fundador',
        'esVerificado': false,
        'profileComplete': false,
        'referredBy': referrerId,
        'referralCount': 0,
      });
      referrerId = null;
    }
  }

  Future<void> _signInAndNavigate(Future<UserCredential?> Function() signInMethod) async {
    setState(() { _loading = true; _error = null; });
    try {
      final userCredential = await signInMethod();
      if (userCredential != null && userCredential.user != null) {
        await _checkAndCreateUserProfile(userCredential.user!);
        if (mounted) _showSuccessAndNavigate(userCredential);
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Ocurrió un error inesperado: ${e.toString()}";
          _loading = false;
        });
      }
    }
  }

  Future<UserCredential?> _signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return null;
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      return await FirebaseAuth.instance.signInWithCredential(credential);
    } catch (e) {
      if (mounted) setState(() => _error = "Error con Google: ${e.toString()}");
      return null;
    }
  }

  Future<void> _loginWithEmail() async {
    setState(() { _loading = true; _error = null; });
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (!mounted) return;
      _navigateToHome();
    } on FirebaseAuthException catch (e) {
      String errorMessage = "Ocurrió un error.";
      if (e.code == 'user-not-found' || e.code == 'INVALID_LOGIN_CREDENTIALS') {
        errorMessage = 'Correo o contraseña incorrectos.';
      } else if (e.code == 'wrong-password') {
        errorMessage = 'La contraseña es incorrecta.';
      } else if (e.code == 'invalid-email') {
        errorMessage = 'El formato del correo no es válido.';
      }
      if (mounted) setState(() => _error = errorMessage);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showSuccessAndNavigate(UserCredential userCredential) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('¡Bienvenido, ${userCredential.user?.displayName ?? 'usuario'}!')),
    );
    _navigateToHome();
  }
  
  void _navigateToHome() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => AuthWrapper(onThemeChanged: widget.onThemeChanged)),
    );
  }

  // --- MÉTODO build Y HELPERS RESTAURADOS ---
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [colorScheme.primary.withAlpha(50), colorScheme.surface],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 32),
                    child: Image.asset('assets/icon/SB1024.png', height: 100),
                  ),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
                        decoration: BoxDecoration(
                          color: colorScheme.surface.withAlpha(178),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: colorScheme.secondary.withAlpha(51)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_error != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: Text(
                                  _error!,
                                  style: TextStyle(color: colorScheme.error),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            _buildTextField(
                              controller: _emailController,
                              labelText: 'Correo electrónico',
                              icon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: 16),
                            _buildTextField(
                              controller: _passwordController,
                              labelText: 'Contraseña',
                              icon: Icons.lock_outline,
                              obscureText: !_showPassword,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _showPassword ? Icons.visibility : Icons.visibility_off,
                                  color: colorScheme.onSurface.withAlpha(153),
                                ),
                                onPressed: () => setState(() => _showPassword = !_showPassword),
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildLoginButton(),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                Expanded(child: Divider(color: colorScheme.onSurface.withAlpha(51))),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 12),
                                  child: Text('O ingresa con', style: theme.textTheme.bodySmall),
                                ),
                                Expanded(child: Divider(color: colorScheme.onSurface.withAlpha(51))),
                              ],
                            ),
                            const SizedBox(height: 20),
                            _buildSocialButtons(),
                            Center(
                              child: TextButton(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => const RecuperarPaswordWidget()),
                                  );
                                },
                                child: Text(
                                  '¿Olvidaste tu contraseña?',
                                  style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w600),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('¿Aún no tienes cuenta?', style: theme.textTheme.bodyMedium),
                      TextButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => const CrearCuentaWidget()),
                          );
                        },
                        child: Text(
                          'Regístrate',
                          style: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                ],
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
    bool obscureText = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
  }) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: labelText,
        prefixIcon: Icon(icon, color: theme.colorScheme.primary.withAlpha(204)),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerHighest.withAlpha(77),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.primary, width: 2),
        ),
        suffixIcon: suffixIcon,
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.secondary],
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
        onPressed: _loading ? null : _loginWithEmail,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
        ),
        child: _loading
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Text('Iniciar sesión', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildSocialButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        SocialIconButton(
          icon: FontAwesomeIcons.google,
          color: const Color(0xFFDB4437),
          onPressed: _loading ? null : () => _signInAndNavigate(_signInWithGoogle),
        ),
      ],
    );
  }
}

class SocialIconButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;

  const SocialIconButton({
    super.key,
    required this.icon,
    required this.color,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: FaIcon(icon, color: color),
      iconSize: 28,
      padding: const EdgeInsets.all(16),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        side: BorderSide(color: Theme.of(context).dividerColor, width: 1.5),
        backgroundColor: Theme.of(context).colorScheme.surface,
      ),
      onPressed: onPressed,
    );
  }
}