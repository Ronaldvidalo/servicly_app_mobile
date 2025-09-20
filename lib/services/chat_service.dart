// lib/services/chat_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:servicly_app/pages/chat/chat_page.dart'; // Asegúrate que esta es la ruta correcta

class ChatService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;
  final _functions = FirebaseFunctions.instanceFor(region: 'us-central1');

  // --- LÓGICA DE NEGOCIO DEL CHAT ---

  /// Llama a una Cloud Function para obtener un chat existente o crear uno nuevo.
  Future<String> getOrCreateChat(String otherUserId) async {
    try {
      final callable = _functions.httpsCallable('getOrCreateChat');
      final response = await callable.call<Map<String, dynamic>>({'otherUserId': otherUserId});
      final chatId = response.data['chatId'] as String?;
      if (chatId == null || chatId.isEmpty) {
        throw Exception("El ID del chat recibido es nulo o vacío.");
      }
      debugPrint("Chat ID obtenido desde la Cloud Function: $chatId");
      return chatId;
    } on FirebaseFunctionsException catch (e) {
      debugPrint("Error al llamar a la Cloud Function: ${e.code} - ${e.message}");
      throw Exception("No se pudo iniciar el chat. Por favor, intentá de nuevo.");
    } catch (e) {
      debugPrint("Error inesperado en ChatService: $e");
      throw Exception("Ocurrió un error inesperado al iniciar el chat.");
    }
  }

  /// Sube un archivo a la carpeta del chat en Firebase Storage.
  Future<String> subirArchivo(File archivo, String chatId, String extension) async {
    final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child('chats/$chatId/media/$nombreArchivo');
    final uploadTask = ref.putFile(archivo);
    final snapshot = await uploadTask.whenComplete(() => {});
    return await snapshot.ref.getDownloadURL();
  }

  /// Envía un mensaje (de cualquier tipo) a un chat.
  Future<void> enviarMensaje({
    required String chatId,
    String? texto,
    String? urlImagen,
    String? urlAudio,
    Duration? mediaDuration,
  }) async {
    final currentUser = _auth.currentUser;
    if (currentUser == null) return;

    String tipo;
    String ultimoMensajeTexto;
    Map<String, dynamic> nuevoMensajeData = {
      'idAutor': currentUser.uid,
      'timestamp': FieldValue.serverTimestamp(),
      'leidoPor': [currentUser.uid],
    };

    if (urlImagen != null) { tipo = 'imagen'; ultimoMensajeTexto = '📷 Imagen'; nuevoMensajeData['urlContenido'] = urlImagen; }
    else if (urlAudio != null) { tipo = 'audio'; ultimoMensajeTexto = '🎵 Mensaje de voz'; nuevoMensajeData['urlContenido'] = urlAudio; nuevoMensajeData['mediaDuration'] = mediaDuration?.inSeconds; }
    else { tipo = 'texto'; ultimoMensajeTexto = texto ?? ''; nuevoMensajeData['texto'] = texto; }
    nuevoMensajeData['tipo'] = tipo;

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('mensajes');
    final ultimoMensaje = {
      'texto': ultimoMensajeTexto,
      'timestamp': FieldValue.serverTimestamp(),
      'idAutor': currentUser.uid,
    };

    final batch = _firestore.batch();
    batch.set(messagesRef.doc(), nuevoMensajeData);
    batch.update(chatRef, {'ultimoMensaje': ultimoMensaje});
    await batch.commit();
  }

  // --- MANEJO DE NOTIFICACIONES DE CHAT ---

  /// Inicializa los listeners para las notificaciones de chat.
  Future<void> initChatNotifications(GlobalKey<NavigatorState> navigatorKey) async {
    // CORRECCIÓN: Maneja la app abriéndose desde un estado TERMINADO.
    FirebaseMessaging.instance.getInitialMessage().then((RemoteMessage? message) {
      if (message != null && message.data['type'] == 'chat_message') {
        _navigateToChat(navigatorKey, message.data['chatId']);
      }
    });

    // Maneja la app abriéndose desde SEGUNDO PLANO.
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      if (message.data['type'] == 'chat_message') {
        _navigateToChat(navigatorKey, message.data['chatId']);
      }
    });
  }

  /// Navega a la pantalla de chat específica.
  Future<void> _navigateToChat(GlobalKey<NavigatorState> navigatorKey, String? chatId) async {
    if (chatId == null) return;
    final currentUserId = _auth.currentUser?.uid;
    if (currentUserId == null) return;

    try {
      final chatDoc = await _firestore.collection('chats').doc(chatId).get();
      if (chatDoc.exists) {
        final chatData = chatDoc.data()!;
        final participants = List<String>.from(chatData['participantes'] ?? []);
        final otherUserId = participants.firstWhere((id) => id != currentUserId, orElse: () => '');
        
        if (otherUserId.isNotEmpty) {
          final otherUserDoc = await _firestore.collection('usuarios').doc(otherUserId).get();
          if (otherUserDoc.exists) {
            final otherUserData = otherUserDoc.data()!;
            navigatorKey.currentState?.push(
              MaterialPageRoute(
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
      debugPrint("Error al navegar al chat desde notificación: $e");
    }
  }
}

Future<void> enviarMensaje(String chatId, String texto, String idAutor) async {
  if (texto.trim().isEmpty) return;

  final firestore = FirebaseFirestore.instance;
  final mensajesRef = firestore.collection('chats').doc(chatId).collection('mensajes');
  final chatRef = firestore.collection('chats').doc(chatId);
  final timestamp = FieldValue.serverTimestamp();

  // Añade el nuevo mensaje a la sub-colección de mensajes
  await mensajesRef.add({
    'idAutor': idAutor,
    'texto': texto,
    'timestamp': timestamp,
    'leidoPor': [idAutor],
  });

  // Actualiza el campo 'ultimoMensaje' en el documento principal del chat
  // para que aparezca en la lista de chats.
  await chatRef.update({
    'ultimoMensaje': {
      'idAutor': idAutor,
      'texto': texto,
      'timestamp': timestamp,
      'leidoPor': [idAutor],
    },
  });
}