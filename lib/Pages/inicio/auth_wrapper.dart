// lib/Pages/inicio/auth_wrapper.dart

import 'package:flutter/material.dart';
import 'package:servicly_app/models/app_user.dart'; // <-- IMPORTA TU MODELO
import 'package:servicly_app/services/auth_service.dart'; // <-- IMPORTA TU SERVICIO
import 'package:servicly_app/services/notification_service.dart';
import 'package:servicly_app/pages/home/home_widget.dart';
import 'package:servicly_app/pages/seleccion_pais/seleccion_pais_widget.dart';
import 'package:servicly_app/pages/inicio/inicio_widget.dart';

class AuthWrapper extends StatelessWidget {
  final void Function(bool) onThemeChanged;
  const AuthWrapper({super.key, required this.onThemeChanged});

  @override
  Widget build(BuildContext context) {
    // 1. Instanciamos nuestro nuevo servicio de autenticación
    final authService = AuthService();

    // 2. Usamos un solo StreamBuilder que escucha nuestro stream combinado y eficiente
    return StreamBuilder<AppUser?>(
      stream: authService.user,
      builder: (context, snapshot) {
        // 3. Mientras espera la primera respuesta (que ya incluye los datos de Firestore), mostramos un indicador de carga
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        // 4. Si tenemos datos de usuario (ya combinados)
        if (snapshot.hasData && snapshot.data != null) {
          final appUser = snapshot.data!;

          // La decisión es simple y directa, sin más esperas
          if (appUser.isProfileComplete) {
            // ✅ CORRECCIÓN: Llamamos a tu HomePortal para que pueda inicializar los servicios
            return HomePortal(onThemeChanged: onThemeChanged);
          } else {
            return SeleccionPaisWidget(onThemeChanged: onThemeChanged);
          }
        }

        // 5. Si no hay datos, el usuario no está logueado
        return InicioWidget(onThemeChanged: onThemeChanged);
      },
    );
  }
}

// --- TU WIDGET INTERMEDIO SE MANTIENE IGUAL ---
// No necesita cambios, seguirá funcionando perfectamente.
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
    _initializeServices();
  }

Future<void> _initializeServices() async {
  try {
    // 1. Pide permiso para recibir notificaciones (Punto 4 del checklist)
    await solicitarPermisoNotificaciones();

    // 2. Configura cómo reaccionar a las notificaciones (lo que ya tenías)
    await setupInteractedMessage();

  } catch (e) {
    debugPrint("Error al inicializar servicios en HomePortal: $e");
  }

  Future<void> initializeServices() async {
    try {
      await setupInteractedMessage();
    } catch (e) {
      debugPrint("Error al inicializar servicios en HomePortal: $e");
    }
  }
}

  @override
  Widget build(BuildContext context) {
    return HomeWidget(onThemeChanged: widget.onThemeChanged);
  }
}