// lib/services/notification_service.dart

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- IMPORTA TUS PÁGINAS AQUÍ ---
import 'package:servicly_app/pages/presupuesto/pagina_detalle_presupuesto.dart';
import 'package:servicly_app/pages/chat/chat_page.dart';
import 'package:servicly_app/Pages/perfil_pagina/perfil_pagina_widget.dart';

class NotificationService {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  static final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;

  static Future<void> initialize() async {
    RemoteMessage? initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      Future.delayed(const Duration(seconds: 1), () {
        _handleNotificationNavigation(initialMessage.data);
      });
    }
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationNavigationFromData);
    FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _firebaseMessaging.onTokenRefresh.listen(_saveTokenToDatabase);
  }

  static Future<void> requestPermissionAndSaveToken() async {
    NotificationSettings settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('Permiso concedido. Obteniendo y guardando token...');
      String? token = await _firebaseMessaging.getToken();

      // ✅ SOLUCIÓN 1: Nos aseguramos de que el token no sea nulo antes de guardarlo.
      if (token != null) {
        await _saveTokenToDatabase(token);
      }
    } else {
      print('Permiso denegado por el usuario.');
    }
  }

  static Future<void> _saveTokenToDatabase(String token) async {
    String? userId = FirebaseAuth.instance.currentUser?.uid;
    // ✅ SOLUCIÓN 2: Añadimos una guarda para asegurarnos de que hay un usuario.
    if (userId == null) return;

    try {
      // ✅ SOLUCIÓN 3: Usamos 'usuarios' que es el nombre correcto de tu colección.
      await FirebaseFirestore.instance.collection('usuarios').doc(userId).set({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print("FCM Token guardado en Firestore exitosamente.");
    } catch (e) {
      print("Error al guardar el token en Firestore: $e");
    }
  }

  static void _handleNotificationNavigationFromData(RemoteMessage message) {
    _handleNotificationNavigation(message.data);
  }

  static void _showForegroundNotification(RemoteMessage message) {
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
  }

  static void _handleNotificationNavigation(Map<String, dynamic> data) {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    if (currentUserId == null) return;

    final String? tipo = data['tipo'];
    final String? idReferencia = data['idReferencia'] ?? data['chatId'] ?? data['postId'] ?? data['profileId'];

    if (tipo == null || idReferencia == null) return;
    
    switch (tipo) {
      case 'nuevo_presupuesto':
      case 'actualizacion_presupuesto':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PaginaDetallePresupuesto(presupuestoId: idReferencia, currentUserId: currentUserId),
        ));
        break;
      case 'chat_message':
        _navigateToChat(context, idReferencia, currentUserId);
        break;
      case 'nuevo_seguidor':
        Navigator.push(context, MaterialPageRoute(
          builder: (_) => PerfilPaginaWidget(user_id: idReferencia),
        ));
        break;
      default:
        print("Tipo de notificación no reconocido: $tipo");
    }
  }

  static Future<void> _navigateToChat(BuildContext context, String chatId, String currentUserId) async {
    try {
      final chatDoc = await FirebaseFirestore.instance.collection('chats').doc(chatId).get();
      if (!chatDoc.exists) return; // Si no existe el chat, salimos.
      
      final chatData = chatDoc.data()!;
      final participants = List<String>.from(chatData['participantes'] ?? []);
      final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
      
      if (otherUserId.isEmpty) return; // Si no hay otro participante, salimos.

      final otherUserDoc = await FirebaseFirestore.instance.collection('usuarios').doc(otherUserId).get();
      if (!otherUserDoc.exists) return; // Si no existe el otro usuario, salimos.

      final otherUserData = otherUserDoc.data()!;

      // ✅ SOLUCIÓN 4: Verificamos si el widget sigue montado antes de navegar.
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PaginaChatDetalle(
              chatId: chatId,
              nombreOtroUsuario: otherUserData['display_name'] ?? 'Usuario',
              fotoUrlOtroUsuario: otherUserData['photo_url'],
            ),
          ),
        );
      }
    } catch (e) {
      print("Error al navegar al chat: $e");
    }
  }
}