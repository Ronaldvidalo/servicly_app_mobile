// lib/Pages/inicio/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:servicly_app/models/app_user.dart';
import 'package:servicly_app/services/auth_service.dart';
import 'package:servicly_app/pages/home/home_widget.dart';
import 'package:servicly_app/pages/seleccion_pais/seleccion_pais_widget.dart';
import 'package:servicly_app/pages/inicio/inicio_widget.dart';

// Importa los paquetes necesarios
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/services/notification_service.dart';

class AuthWrapper extends StatelessWidget {
  final void Function(bool) onThemeChanged;
  const AuthWrapper({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    final authService = AuthService();

    return StreamBuilder<AppUser?>(
      stream: authService.user,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (snapshot.hasData && snapshot.data != null) {
          final appUser = snapshot.data!;
          if (appUser.isProfileComplete) {
            // El usuario tiene el perfil completo, mostramos HomePortal
            return HomePortal(onThemeChanged: onThemeChanged);
          } else {
            // El usuario está logueado pero no ha completado el perfil
            return SeleccionPaisWidget(onThemeChanged: onThemeChanged);
          }
        }

        // El usuario no está logueado
        return InicioWidget(onThemeChanged: onThemeChanged);
      },
    );
  }
}

class HomePortal extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  const HomePortal({super.key, required this.onThemeChanged});

  @override
  State<HomePortal> createState() => _HomePortalState();
}

class _HomePortalState extends State<HomePortal> {

  @override
  void initState() {
    super.initState();
    
    // Le decimos a Flutter: "Cuando termines de dibujar esta pantalla, ejecuta mi función".
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndRequestNotificationPermission();
    });
  }

  Future<void> _checkAndRequestNotificationPermission() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (!userDoc.exists) return;
      
      final userData = userDoc.data() as Map<String, dynamic>;

      if (!userData.containsKey('fcmToken') || userData['fcmToken'] == null) {
        print("Token no encontrado. Solicitando permiso...");
        await NotificationService.requestPermissionAndSaveToken();
      } else {
        print("El usuario ya tiene un token FCM. No se pide permiso.");
      }
    } catch (e) {
      print("Error al verificar permisos de notificación: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return HomeWidget(onThemeChanged: widget.onThemeChanged);
  }
}
