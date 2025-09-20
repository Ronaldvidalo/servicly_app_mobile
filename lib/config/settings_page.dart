// lib/config/settings_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/Pages/inicio/inicio_widget.dart';
import 'package:servicly_app/pages/pagos/verificacion_page.dart';
import 'package:servicly_app/widgets/app_background.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:servicly_app/Pages/perfil_pagina/editar_perfil.dart';
import 'package:cloud_functions/cloud_functions.dart';

class SettingsPage extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  const SettingsPage({super.key, required this.onThemeChanged});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  bool _isAssigningRole = false;

  Future<void> _asignarRolAdmin() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar tu email.')));
      return;
    }

    setState(() => _isAssigningRole = true);
    
    try {
      HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('setAdminRole');
      final result = await callable.call<Map<String, dynamic>>({'email': user.email});

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(result.data['message']), backgroundColor: Colors.green),
        );
      }
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.message}'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAssigningRole = false);
      }
    }
  }

  Future<void> _onChangePasswordPressed() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.email == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No se pudo encontrar tu correo electrónico.')));
      return;
    }
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: user.email!);
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Correo Enviado'),
            content: Text('Hemos enviado un enlace para gestionar tu contraseña a ${user.email}. Revisa tu bandeja de entrada y spam.'),
            actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Entendido'))],
          ),
        );
      }
    } on FirebaseAuthException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.message}')));
      }
    }
  }

  Future<void> _contactSupport() async {
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: 'contacto@servicly.app', 
      query: 'subject=Contacto de Soporte desde la App',
    );
    if (await canLaunchUrl(emailLaunchUri)) {
      await launchUrl(emailLaunchUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No se pudo abrir la aplicación de correo.'))
        );
      }
    }
  }

  Future<void> _showLogoutConfirmationDialog() async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Salida'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: <Widget>[
            TextButton(child: const Text('Cancelar'), onPressed: () => Navigator.of(dialogContext).pop()),
            TextButton(
              child: Text('Salir', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => InicioWidget(onThemeChanged: widget.onThemeChanged)),
                    (Route<dynamic> route) => false,
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDarkMode = theme.brightness == Brightness.dark;

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Configuración'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: colorScheme.onSurface,
        ),
        body: SafeArea(
          child: _currentUserId == null
              ? const Center(child: Text('Usuario no encontrado.'))
              : StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('usuarios').doc(_currentUserId).snapshots(),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                    final esVerificado = userData['esVerificado'] ?? false;

                    return ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      children: [
                        const SizedBox(height: 16),
                        _buildSectionTitle('Cuenta'),
                        _buildSettingsCard(
                          children: [
                            _buildSettingsTile(
                              icon: Icons.person_outline,
                              title: 'Información Personal',
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => const EditarPerfilPage()));
                              },
                            ),
                            const Divider(height: 1),
                            _buildSettingsTile(
                              icon: Icons.lock_outline,
                              title: 'Crear o Actualizar Contraseña',
                              onTap: _onChangePasswordPressed,
                            ),
                            const Divider(height: 1),
                            ListTile(
                              leading: Icon(Icons.admin_panel_settings, color: Colors.orange.shade700),
                              title: Text('Asignarme Rol de Admin', style: TextStyle(color: Colors.orange.shade700, fontWeight: FontWeight.bold)),
                              onTap: _isAssigningRole ? null : _asignarRolAdmin,
                              trailing: _isAssigningRole ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : null,
                            ),
                            if (!esVerificado) ...[
                              const Divider(height: 1),
                              _buildSettingsTile(
                                icon: Icons.verified_user_outlined,
                                title: 'Verificar mi Cuenta',
                                color: colorScheme.tertiary,
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const VerificacionPage())),
                              ),
                            ]
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Apariencia'),
                        Card(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: SwitchListTile(
                            title: const Text('Modo Oscuro'),
                            value: isDarkMode,
                            onChanged: widget.onThemeChanged,
                            secondary: Icon(isDarkMode ? Icons.dark_mode_outlined : Icons.light_mode_outlined),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('Soporte y Legal'),
                        _buildSettingsCard(
                          children: [
                             _buildSettingsTile(
                                icon: Icons.contact_support_outlined,
                                title: 'Contactar con Soporte',
                                onTap: _contactSupport,
                              ),
                            const Divider(height: 1),
                            _buildSettingsTile(icon: Icons.help_outline, title: 'Centro de Ayuda', onTap: () {}),
                            const Divider(height: 1),
                            _buildSettingsTile(icon: Icons.description_outlined, title: 'Términos y Condiciones', onTap: () {}),
                            const Divider(height: 1),
                            _buildSettingsTile(icon: Icons.privacy_tip_outlined, title: 'Política de Privacidad', onTap: () {}),
                          ],
                        ),
                        const SizedBox(height: 24),
                        _buildSettingsTile(
                          icon: Icons.logout,
                          title: 'Cerrar Sesión',
                          color: colorScheme.error,
                          onTap: _showLogoutConfirmationDialog,
                          isCard: true,
                        ),
                        const SizedBox(height: 24),
                      ],
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 12.0, bottom: 8.0),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    );
  }

  Widget _buildSettingsCard({required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(children: children),
    );
  }

  Widget _buildSettingsTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    bool isCard = false,
  }) {
    final tile = ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: (color == null) ? const Icon(Icons.arrow_forward_ios, size: 16) : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
    return isCard ? Card(shape: tile.shape, child: tile) : tile;
  }
}