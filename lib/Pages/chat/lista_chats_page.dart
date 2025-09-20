import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/models/chat_model.dart';
import 'package:servicly_app/pages/chat/chat_page.dart'; 
import 'package:servicly_app/pages/chat/buscar_contactos_page.dart';

class ListaChatsPage extends StatefulWidget {
  const ListaChatsPage({super.key});

  @override
  State<ListaChatsPage> createState() => _ListaChatsPageState();
}

class _ListaChatsPageState extends State<ListaChatsPage> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Mensajes'),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('chats')
            .where('participantes', arrayContains: _currentUserId)
            .orderBy('ultimoMensaje.timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24.0),
                child: Text(
                  'No tienes conversaciones activas.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
              ),
            );
          }

          final chatDocs = snapshot.data!.docs;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
            itemCount: chatDocs.length,
            itemBuilder: (context, index) {
              final chat = Chat.fromFirestore(chatDocs[index]);
              return _ChatItem(chat: chat, currentUserId: _currentUserId);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            builder: (context) => const PaginaBusquedaContactos(),
          );
        },
        child: const Icon(Icons.add_comment_outlined),
      ),
    );
  }
}

// --- VERSIÓN ÚNICA Y CORRECTA DE _ChatItem ---
class _ChatItem extends StatelessWidget {
  final Chat chat;
  final String currentUserId;

  const _ChatItem({required this.chat, required this.currentUserId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    // --- LÓGICA DE ADAPTACIÓN ---
    bool esChatDeTrabajo = chat.tipo == 'trabajo';

    String titulo;
    String? fotoUrl;
    Widget iconoPlaceholder;

    if (esChatDeTrabajo) {
      // Si es un chat de trabajo, usamos el nombre del grupo y un ícono de maletín
      titulo = chat.nombreGrupo ?? 'Chat de Trabajo';
      fotoUrl = null; // O una imagen genérica si tenés una
      iconoPlaceholder = const Icon(Icons.work_outline, size: 30);
    } else {
      // Si es personal, usamos la lógica que ya tenías
      final otroUsuarioId = chat.participantes.firstWhere((id) => id != currentUserId, orElse: () => '');
      titulo = chat.participantesNombres[otroUsuarioId] ?? 'Usuario';
      fotoUrl = chat.participantesFotos[otroUsuarioId];
      iconoPlaceholder = const Icon(Icons.person, size: 30);
    }
    
    // El resto de la lógica de mensajes no leídos y fecha se mantiene
    final ultimoMensajeFecha = DateFormat('HH:mm').format(chat.ultimoMensajeTimestamp.toDate());
    final bool hayMensajesNuevos = chat.unreadCount > 0 && chat.ultimoMensajeAutorId != currentUserId;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PaginaChatDetalle(
                chatId: chat.id,
                nombreOtroUsuario: titulo,
                fotoUrlOtroUsuario: fotoUrl,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                    ? NetworkImage(fotoUrl)
                    : null,
                child: (fotoUrl == null || fotoUrl.isEmpty)
                    ? iconoPlaceholder
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: hayMensajesNuevos ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      chat.ultimoMensajeTexto,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: hayMensajesNuevos 
                            ? theme.textTheme.bodyLarge?.color 
                            : Colors.grey,
                        fontWeight: hayMensajesNuevos ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    ultimoMensajeFecha,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: hayMensajesNuevos ? theme.colorScheme.primary : null,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Badge(
                    label: Text('${chat.unreadCount}'),
                    isLabelVisible: hayMensajesNuevos,
                    backgroundColor: Colors.blue.shade700,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}