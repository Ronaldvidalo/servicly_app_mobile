import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTA TUS PÁGINAS AQUÍ ---
// Asegúrate de que las rutas de importación sean correctas para tu proyecto.
import 'package:servicly_app/pages/presupuesto/pagina_detalle_presupuesto.dart';
import 'package:servicly_app/pages/chat/chat_page.dart'; // O el nombre correcto de tu página de detalle de chat
import 'package:servicly_app/Pages/perfil_pagina/perfil_pagina_widget.dart';// O el nombre correcto de tu página de perfil
//import 'package:servicly_app/pages/post/post_detalle_page.dart'; // Descomenta cuando tengas la página de detalle del post


final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();


// --- LÓGICA DE NAVEGACIÓN ---
// Esta función centraliza la lógica para decidir a qué pantalla ir.
void _handleNotificationNavigation(Map<String, dynamic> data) {
  final context = navigatorKey.currentContext;
  if (context == null) {
    print("Error: No se pudo obtener el contexto de navegación.");
    return;
  }

  final currentUserId = FirebaseAuth.instance.currentUser?.uid;
  if (currentUserId == null) {
    print("Error: El usuario no está autenticado para la navegación.");
    return;
  }

  final String? tipo = data['tipo'];
  // Unificamos la obtención del ID desde diferentes posibles claves en el payload.
  final String? idReferencia = data['idReferencia'] ?? data['chatId'] ?? data['postId'] ?? data['profileId'];

  if (tipo == null || idReferencia == null) {
    print("Error: La notificación no tiene 'tipo' o 'idReferencia'. Datos: $data");
    return;
  }

  print("Navegando a tipo: $tipo con ID: $idReferencia");

  // Usamos un switch para decidir a qué página navegar.
  switch (tipo) {
    case 'nuevo_presupuesto':
    case 'actualizacion_presupuesto':
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PaginaDetallePresupuesto(
          presupuestoId: idReferencia,
          currentUserId: currentUserId,
        ),
      ));
      break;

    case 'chat_message':
      // La navegación del chat es más compleja, usamos una función auxiliar.
      _navigateToChat(context, idReferencia, currentUserId);
      break;

    case 'nuevo_like':
    case 'nuevo_comentario':
      // TODO: Reemplaza 'PostDetallePage' con el nombre real de tu página y descomenta la línea.
      // Navigator.push(context, MaterialPageRoute(builder: (_) => PostDetallePage(postId: idReferencia)));
      print("Navegar a la página de detalle del post con ID: $idReferencia (implementación pendiente)");
      break;
    
    case 'nuevo_seguidor':
       Navigator.push(context, MaterialPageRoute(
        builder: (_) => PerfilPaginaWidget(user_id: idReferencia),
      ));
      break;

    default:
      print("Tipo de notificación no reconocido: $tipo");
      // Opcionalmente, puedes navegar a una página de notificaciones general.
      // Navigator.push(context, MaterialPageRoute(builder: (_) => NotificacionesPage()));
      break;
  }
}

Future<void> solicitarPermisoNotificaciones() async {
  // Obtenemos la instancia de Firebase Messaging.
  final messaging = FirebaseMessaging.instance;

  // Solicitamos el permiso al usuario.
  final settings = await messaging.requestPermission(
    alert: true,
    announcement: false,
    badge: true,
    carPlay: false,
    criticalAlert: false,
    provisional: false,
    sound: true,
  );

  // Verificamos el resultado del permiso.
  if (settings.authorizationStatus == AuthorizationStatus.authorized) {
    print('Permiso de notificaciones concedido por el usuario.');
    
    // Una vez concedido el permiso, es un buen momento para obtener y guardar el token.
    final token = await messaging.getToken();
    print('FCM Token: $token');
    // Aquí puedes añadir tu lógica para guardar el token en Firestore.
    // guardarTokenEnFirestore(userId, token);

  } else {
    print('Permiso de notificaciones denegado por el usuario.');
  }
}

// --- FUNCIÓN AUXILIAR PARA NAVEGAR AL CHAT ---
// Esta función obtiene los datos necesarios antes de abrir la página del chat.
Future<void> _navigateToChat(BuildContext context, String chatId, String currentUserId) async {
  try {
    final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
    if (chatDoc.exists) {
      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participantes'] ?? []);
      final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
      
      if (otherUserId.isNotEmpty) {
        final otherUserDoc = await FirebaseFirestore.instance.collection('usuarios').doc(otherUserId).get();
        if (otherUserDoc.exists) {
          final otherUserData = otherUserDoc.data()!;
          Navigator.push(
            context,
            MaterialPageRoute(
              // Asegúrate de que tu página de chat se llame 'PaginaChatDetalle'
              // y acepte estos parámetros.
              builder: (context) => PaginaChatDetalle(
                chatId: chatId,
                nombreOtroUsuario: otherUserData['display_name'] ?? 'Usuario',
                fotoUrlOtroUsuario: otherUserData['photo_url'],
              ),
            ),
          );
        }
      }
    }
  } catch (e) {
    print("Error al navegar al chat: $e");
  }
}


// --- CONFIGURACIÓN DE FIREBASE MESSAGING ---
// Llama a esta función en tu `main()` antes de `runApp()`.
Future<void> setupInteractedMessage() async {
  // 1. Maneja la notificación si la app se abre desde un estado TERMINADO.
  RemoteMessage? initialMessage = await FirebaseMessaging.instance.getInitialMessage();

  if (initialMessage != null) {
    _handleNotificationNavigation(initialMessage.data);
  }

  // 2. Maneja la notificación si la app se abre desde un estado EN SEGUNDO PLANO.
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    _handleNotificationNavigation(message.data);
  });

  // 3. (Opcional) Escucha notificaciones mientras la app está EN PRIMER PLANO.
  // Usualmente aquí no se navega, sino que se muestra un SnackBar o un diálogo.
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Notificación recibida en primer plano: ${message.notification?.title}');
    final context = navigatorKey.currentContext;
    if (context != null && message.notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.notification!.body ?? "Nueva notificación"),
          action: SnackBarAction(
            label: "Ver",
            onPressed: () => _handleNotificationNavigation(message.data),
          ),
        ),
      );
    }
  });
}

// --- EN TU WIDGET PRINCIPAL (ej. main.dart) ---

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//
//   // Llama a la función de configuración aquí.
//   await setupInteractedMessage();
//
//   runApp(const MyApp());
// }
//
// class MyApp extends StatelessWidget {
//   const MyApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       // Asigna la clave global al navigatorKey de tu MaterialApp.
//       navigatorKey: navigatorKey,
//       title: 'Servicly',
//       home: AuthWrapper(), // O tu página de inicio
//     );
//   }
// }
