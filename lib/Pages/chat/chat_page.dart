import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/models/mensaje_model.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:servicly_app/pages/presupuesto/pagina_detalle_presupuesto.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:path/path.dart' as p;

// --- SERVICIO DE CHAT ---
class ChatService {
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final _storage = FirebaseStorage.instance;

  Future<String> subirArchivo(File archivo, String chatId, String extension) async {
    final nombreArchivo = '${DateTime.now().millisecondsSinceEpoch}.$extension';
    final ref = _storage.ref().child('chats/$chatId/media/$nombreArchivo');
    final uploadTask = ref.putFile(archivo);
    final snapshot = await uploadTask.whenComplete(() => {});
    return await snapshot.ref.getDownloadURL();
  }

  Future<void> enviarMensaje({
    required String chatId,
    String? texto,
    String? urlImagen,
    String? urlAudio,
    String? urlVideo,
    String? urlDocumento,
    String? idPresupuesto,
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
    else if (urlVideo != null) { tipo = 'video'; ultimoMensajeTexto = '📹 Video'; nuevoMensajeData['urlContenido'] = urlVideo; nuevoMensajeData['mediaDuration'] = mediaDuration?.inSeconds; }
    else if (urlDocumento != null) { tipo = 'documento'; ultimoMensajeTexto = '📄 ${texto ?? "Documento"}'; nuevoMensajeData['urlContenido'] = urlDocumento; nuevoMensajeData['texto'] = texto; }
    else if (idPresupuesto != null) { tipo = 'presupuesto'; ultimoMensajeTexto = '📄 Presupuesto enviado'; nuevoMensajeData['idPresupuesto'] = idPresupuesto; }
    else { tipo = 'texto'; ultimoMensajeTexto = texto ?? ''; nuevoMensajeData['texto'] = texto; }
    nuevoMensajeData['tipo'] = tipo;

    final chatRef = _firestore.collection('chats').doc(chatId);
    final messagesRef = chatRef.collection('mensajes');

    final ultimoMensaje = {
      'texto': ultimoMensajeTexto,
      'timestamp': FieldValue.serverTimestamp(),
      'idAutor': currentUser.uid,
      'leidoPor': [currentUser.uid],
    };

    final batch = _firestore.batch();
    batch.set(messagesRef.doc(), nuevoMensajeData);
    batch.update(chatRef, {
      'ultimoMensaje': ultimoMensaje,
      'unreadCount': FieldValue.increment(1),
    });
    await batch.commit();
  }

  Future<void> eliminarMensaje(String chatId, String messageId) async {
    await _firestore.collection('chats').doc(chatId).collection('mensajes').doc(messageId).delete();
  }
}

// --- PANTALLA PRINCIPAL DEL CHAT ---
class PaginaChatDetalle extends StatefulWidget {
  final String chatId, nombreOtroUsuario;
  final String? fotoUrlOtroUsuario;
  const PaginaChatDetalle({super.key, required this.chatId, required this.nombreOtroUsuario, this.fotoUrlOtroUsuario});

  @override
  State<PaginaChatDetalle> createState() => _PaginaChatDetalleState();
}

class _PaginaChatDetalleState extends State<PaginaChatDetalle> {
  final _messageController = TextEditingController();
  final _chatService = ChatService();
  bool _estaSubiendo = false;
  bool _isRecording = false;

  @override
  void initState() {
    super.initState();
    _marcarComoLeido();
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _marcarComoLeido() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;
    final chatRef = FirebaseFirestore.instance.collection('chats').doc(widget.chatId);
    await chatRef.update({
      'ultimoMensaje.leidoPor': FieldValue.arrayUnion([currentUser.uid]),
      'unreadCount': 0,
    });
  }
  
  Future<void> _enviarMensajeTexto() async {
    final texto = _messageController.text.trim();
    if (texto.isEmpty) return;
    _messageController.clear();
    FocusScope.of(context).unfocus();
    await _chatService.enviarMensaje(chatId: widget.chatId, texto: texto);
  }

Future<void> _showAttachmentMenu() async {
  showModalBottomSheet(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(
        children: <Widget>[
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Galería (Foto o Video)'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickFromGallery(); // <-- Cambio aquí
            },
          ),
          ListTile(
            leading: const Icon(Icons.camera_alt_outlined),
            title: const Text('Tomar Foto'), // Aclaramos que es para fotos
            onTap: () {
              Navigator.of(ctx).pop();
              _pickFromCamera(); // <-- Cambio aquí
            },
          ),
          ListTile(
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: const Text('Documento'),
            onTap: () {
              Navigator.of(ctx).pop();
              _pickDocument();
            },
          ),
        ],
      ),
    ),
  );
}

  // Función para seleccionar FOTOS o VIDEOS de la GALERÍA
Future<void> _pickFromGallery() async {
  final pickedFile = await ImagePicker().pickMedia(imageQuality: 70);
  if (pickedFile != null) {
    final file = File(pickedFile.path);
    final fileExtension = p.extension(file.path).toLowerCase();
    final isVideo = ['.mp4', '.mov', '.avi'].contains(fileExtension);
    _enviarArchivo(file, esVideo: isVideo);
  }
}

// Función para TOMAR UNA FOTO con la CÁMARA
Future<void> _pickFromCamera() async {
  final pickedFile = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 70);
  if (pickedFile != null) {
    final file = File(pickedFile.path);
    _enviarArchivo(file, esVideo: false);
  }
}
  Future<void> _pickDocument() async {
    final result = await FilePicker.platform.pickFiles();
    if (result != null && result.files.single.path != null) {
      final file = File(result.files.single.path!);
      _enviarArchivo(file, esDocumento: true);
    }
  }

  Future<void> _enviarArchivo(File file, {bool esVideo = false, bool esDocumento = false}) async {
    setState(() => _estaSubiendo = true);
    try {
      final fileExtension = p.extension(file.path).replaceAll('.', '');
      final url = await _chatService.subirArchivo(file, widget.chatId, fileExtension);
      if (esVideo) {
        final videoController = VideoPlayerController.file(file);
        await videoController.initialize();
        await _chatService.enviarMensaje(chatId: widget.chatId, urlVideo: url, mediaDuration: videoController.value.duration);
        await videoController.dispose();
      } else if (esDocumento) {
        final nombreArchivo = p.basename(file.path);
        await _chatService.enviarMensaje(chatId: widget.chatId, texto: nombreArchivo, urlDocumento: url);
      } else {
        await _chatService.enviarMensaje(chatId: widget.chatId, urlImagen: url);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al subir el archivo: $e')));
    } finally {
      if(mounted) setState(() => _estaSubiendo = false);
    }
  }

  Future<void> _enviarPresupuesto() async {
    // Aquí puedes implementar la lógica para que el profesional seleccione uno de sus presupuestos
    // y lo envíe. Por ahora, es un placeholder.
  }

  void _eliminarMensaje(String messageId) async {
    await _chatService.eliminarMensaje(widget.chatId, messageId);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          CircleAvatar(
            backgroundImage: (widget.fotoUrlOtroUsuario != null && widget.fotoUrlOtroUsuario!.isNotEmpty) ? NetworkImage(widget.fotoUrlOtroUsuario!) : null,
            child: (widget.fotoUrlOtroUsuario == null || widget.fotoUrlOtroUsuario!.isEmpty) ? const Icon(Icons.person) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              widget.nombreOtroUsuario,
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ]),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('chats').doc(widget.chatId).collection('mensajes').orderBy('timestamp', descending: true).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text("Envía un mensaje para empezar."));
                
                final mensajes = snapshot.data!.docs;
                return ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  reverse: true,
                  itemCount: mensajes.length,
                  itemBuilder: (context, index) {
                    final mensaje = Mensaje.fromFirestore(mensajes[index]);
                    final esAutorActual = mensaje.idAutor == FirebaseAuth.instance.currentUser?.uid;
                    return _MessageBubble(
                      mensaje: mensaje,
                      esAutorActual: esAutorActual,
                      onLongPress: () => _showDeleteDialog(mensaje.id),
                    );
                  },
                );
              },
            ),
          ),
          if (_estaSubiendo) const LinearProgressIndicator(),
          _isRecording
              ? _RecordingBar(
                  chatId: widget.chatId,
                  onCancel: () => setState(() => _isRecording = false),
                  onSend: (file, duration) {
                    setState(() => _isRecording = false);
                  },
                )
              : _MessageInputBar(
                  controller: _messageController,
                  onSend: _enviarMensajeTexto,
                  onAttach: _showAttachmentMenu,
                  onPickPresupuesto: _enviarPresupuesto, // Esta función sigue aquí por si la necesitas
                  onStartRecord: () => setState(() => _isRecording = true),
                ),
        ],
      ),
    );
  }

  void _showDeleteDialog(String messageId) {
    showModalBottomSheet(context: context, builder: (ctx) => ListTile(
      leading: const Icon(Icons.delete_outline, color: Colors.red),
      title: const Text('Eliminar Mensaje'),
      onTap: () { Navigator.of(ctx).pop(); _eliminarMensaje(messageId); },
    ));
  }
}


class _RecordingBar extends StatefulWidget {
  final String chatId;
  final VoidCallback onCancel;
  final void Function(File audioFile, Duration duration) onSend;
  const _RecordingBar({required this.chatId, required this.onCancel, required this.onSend});
  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> {
  final _soundRecorder = FlutterSoundRecorder();
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  String? _recordingPath;

  @override
  void initState() {
    super.initState();
    _startRecording();
  }
  
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _soundRecorder.closeRecorder();
    super.dispose();
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      widget.onCancel();
      return;
    }
    await _soundRecorder.openRecorder();
    final tempDir = await getTemporaryDirectory();
    _recordingPath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.aac';
    await _soundRecorder.startRecorder(toFile: _recordingPath, codec: Codec.aacADTS);

    _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) setState(() => _recordingDuration++);
    });
  }

  Future<void> _stopRecordingAndSend() async {
    _recordingTimer?.cancel();
    await _soundRecorder.stopRecorder();
    if (_recordingPath == null) return;
    
    final audioFile = File(_recordingPath!);
    final duration = Duration(seconds: _recordingDuration);
    
    final chatService = ChatService();
    await chatService.subirArchivo(audioFile, widget.chatId, 'aac').then((url) {
      chatService.enviarMensaje(chatId: widget.chatId, urlAudio: url, mediaDuration: duration);
    });
    
    widget.onCancel();
  }
  
  Future<void> _cancelRecording() async {
    _recordingTimer?.cancel();
    await _soundRecorder.stopRecorder();
    widget.onCancel();
  }
  
  @override
  Widget build(BuildContext context) {
    final minutes = (_recordingDuration ~/ 60).toString().padLeft(2, '0');
    final seconds = (_recordingDuration % 60).toString().padLeft(2, '0');
    return Material(
      elevation: 8,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
        color: Theme.of(context).cardColor,
        child: Row(
          children: [
            IconButton(icon: const Icon(Icons.delete_outline), color: Colors.red, onPressed: _cancelRecording, tooltip: 'Cancelar'),
            const Icon(Icons.mic, color: Colors.red),
            const SizedBox(width: 16),
            Text("$minutes:$seconds", style: const TextStyle(fontSize: 16)),
            const Spacer(),
            IconButton(icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary), onPressed: _stopRecordingAndSend, tooltip: 'Enviar Audio'),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Mensaje mensaje;
  final bool esAutorActual;
  final VoidCallback onLongPress;
  const _MessageBubble({required this.mensaje, required this.esAutorActual, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    final alignment = esAutorActual ? CrossAxisAlignment.end : CrossAxisAlignment.start;
    final color = esAutorActual ? Theme.of(context).colorScheme.primary : Theme.of(context).colorScheme.surfaceContainerHighest;
    final textColor = esAutorActual ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;
    
    final bubblePadding = (mensaje.tipo == TipoMensaje.texto || mensaje.tipo == TipoMensaje.presupuesto || mensaje.tipo == TipoMensaje.documento)
        ? const EdgeInsets.fromLTRB(14, 10, 14, 6)
        : const EdgeInsets.all(3);

    return GestureDetector(
      onLongPress: esAutorActual ? onLongPress : null,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: alignment,
          children: [
            Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(16)),
              padding: bubblePadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildMessageContent(context, textColor),
                  if (mensaje.tipo == TipoMensaje.texto || mensaje.tipo == TipoMensaje.presupuesto)
                    const SizedBox(height: 5),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (esAutorActual) ...[
                        Icon(
                          mensaje.visto ? Icons.done_all : Icons.done,
                          size: 16,
                          color: mensaje.visto ? Colors.lightBlue.shade300 : textColor.withAlpha(180),
                        ),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        DateFormat('HH:mm').format(mensaje.timestamp.toDate()),
                        style: TextStyle(color: textColor.withAlpha(180), fontSize: 12),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageContent(BuildContext context, Color textColor) {
    switch (mensaje.tipo) {
      case TipoMensaje.texto:
        return Text(mensaje.texto ?? '', style: TextStyle(color: textColor, fontSize: 16));
      case TipoMensaje.imagen:
        return ClipRRect(borderRadius: BorderRadius.circular(13), child: Image.network(mensaje.urlContenido!));
      case TipoMensaje.audio:
        return _AudioPlayerBubble(url: mensaje.urlContenido!, duration: mensaje.mediaDuration, isMyMessage: esAutorActual);
      case TipoMensaje.video:
        return _VideoPlayerBubble(url: mensaje.urlContenido!, duration: mensaje.mediaDuration);
      case TipoMensaje.presupuesto:
        return _PresupuestoBubble(idPresupuesto: mensaje.idPresupuesto!, isMyMessage: esAutorActual);
      case TipoMensaje.documento:
        return _DocumentBubble(fileName: mensaje.texto!, fileUrl: mensaje.urlContenido!, isMyMessage: esAutorActual);
      default:
        return Text('Mensaje no soportado', style: TextStyle(color: textColor, fontStyle: FontStyle.italic));
    }
  }
}

class _MessageInputBar extends StatefulWidget {
  final TextEditingController controller;
  final VoidCallback onSend, onStartRecord, onAttach, onPickPresupuesto;
  const _MessageInputBar({required this.controller, required this.onSend, required this.onStartRecord, required this.onAttach, required this.onPickPresupuesto});

  @override
  State<_MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends State<_MessageInputBar> {
  bool _showSendButton = false;
  
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(() {
      if(mounted) setState(() => _showSendButton = widget.controller.text.isNotEmpty);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      color: Theme.of(context).cardColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: widget.onAttach,
                tooltip: 'Adjuntar',
              ),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  decoration: const InputDecoration(
                    hintText: "Escribe un mensaje...",
                    border: InputBorder.none,
                    filled: false
                  ),
                  onSubmitted: (_) => widget.onSend(),
                )
              ),
              if (_showSendButton)
                IconButton(icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary), onPressed: widget.onSend)
              else
                IconButton(
                  icon: const Icon(Icons.mic_none),
                  onPressed: widget.onStartRecord,
                  iconSize: 28,
                  tooltip: "Grabar mensaje de voz",
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AudioPlayerBubble extends StatefulWidget {
  final String url;
  final Duration? duration;
  final bool isMyMessage;
  const _AudioPlayerBubble({required this.url, this.duration, required this.isMyMessage});

  @override
  State<_AudioPlayerBubble> createState() => _AudioPlayerBubbleState();
}
class _AudioPlayerBubbleState extends State<_AudioPlayerBubble> {
  final _soundPlayer = FlutterSoundPlayer();
  bool _isPlaying = false;
  Duration _position = Duration.zero;
  StreamSubscription? _progressSubscription;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }
  
  Future<void> _initPlayer() async {
    await _soundPlayer.openPlayer();
    _progressSubscription = _soundPlayer.onProgress!.listen((e) {
      if (mounted) setState(() => _position = e.position);
    });
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _soundPlayer.closePlayer(); 
    super.dispose();
  }

  Future<void> _togglePlaying() async {
    if (_soundPlayer.isPlaying) {
      await _soundPlayer.pausePlayer();
    } else {
      await _soundPlayer.startPlayer(fromURI: widget.url, whenFinished: () {
        if(mounted) {
          setState(() {
            _isPlaying = false;
            _position = Duration.zero;
          });
        }
      });
    }
    if(mounted) setState(() => _isPlaying = _soundPlayer.isPlaying);
  }

  String _formatDuration(Duration d) => d.toString().split('.').first.padLeft(8, "0").substring(3);

  @override
  Widget build(BuildContext context) {
    final color = widget.isMyMessage ? Colors.white : Theme.of(context).colorScheme.primary;
    final totalDuration = widget.duration ?? _position;
    final currentPosition = _position.inMilliseconds.toDouble();
    final maxDuration = totalDuration.inMilliseconds.toDouble();
    
    return SizedBox(
      width: MediaQuery.of(context).size.width * 0.6,
      child: Row(
        children: [
          IconButton(icon: Icon(_isPlaying ? Icons.pause : Icons.play_arrow, color: color), onPressed: _togglePlaying),
          Expanded(
            child: Slider(
              value: currentPosition.clamp(0.0, maxDuration > 0 ? maxDuration : 1.0), 
              max: maxDuration > 0 ? maxDuration : 1.0, 
              onChanged: null, 
              activeColor: color, 
              inactiveColor: color.withAlpha(102)
            )
          ),
          const SizedBox(width: 8),
          Text(_formatDuration(widget.duration ?? Duration.zero), style: TextStyle(color: color, fontSize: 12)),
        ],
      ),
    );
  }
}

class _VideoPlayerBubble extends StatefulWidget {
  final String url;
  final Duration? duration;
  const _VideoPlayerBubble({required this.url, this.duration});

  @override
  State<_VideoPlayerBubble> createState() => _VideoPlayerBubbleState();
}
class _VideoPlayerBubbleState extends State<_VideoPlayerBubble> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller = VideoPlayerController.networkUrl(Uri.parse(widget.url))
      ..initialize().then((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }
  String _formatDuration(Duration d) => d.toString().split('.').first.padLeft(8, "0").substring(3);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        if (_controller != null) {
          Navigator.push(context, MaterialPageRoute(builder: (_) => _FullScreenVideoPlayer(controller: _controller!)));
        }
      },
      child: Container(
        constraints: const BoxConstraints(maxHeight: 250),
        child: (_controller != null && _controller!.value.isInitialized)
            ? Stack(
                alignment: Alignment.center,
                children: [
                  ClipRRect(borderRadius: BorderRadius.circular(13), child: AspectRatio(aspectRatio: _controller!.value.aspectRatio, child: VideoPlayer(_controller!))),
                  Container(decoration: BoxDecoration(color: Colors.black.withAlpha(102), shape: BoxShape.circle), child: const Icon(Icons.play_arrow, color: Colors.white, size: 40)),
                  Positioned(bottom: 8, right: 8, child: Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: Colors.black.withAlpha(153), borderRadius: BorderRadius.circular(4)), child: Text(_formatDuration(widget.duration ?? Duration.zero), style: const TextStyle(color: Colors.white, fontSize: 12))))
                ],
              )
            : const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _FullScreenVideoPlayer extends StatefulWidget {
  final VideoPlayerController controller;
  const _FullScreenVideoPlayer({required this.controller});
  @override
  State<_FullScreenVideoPlayer> createState() => _FullScreenVideoPlayerState();
}
class _FullScreenVideoPlayerState extends State<_FullScreenVideoPlayer> {
  @override
  void initState() {
    super.initState();
    if (!widget.controller.value.isPlaying) {
      widget.controller.play();
      widget.controller.setVolume(1.0);
    }
  }

  @override
  void dispose() {
    if (widget.controller.value.isPlaying) {
      widget.controller.pause();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0),
      body: Center(child: AspectRatio(aspectRatio: widget.controller.value.aspectRatio, child: VideoPlayer(widget.controller))),
    );
  }
}

class _PresupuestoBubble extends StatelessWidget {
  final String idPresupuesto;
  final bool isMyMessage;
  const _PresupuestoBubble({required this.idPresupuesto, required this.isMyMessage});

  @override
  Widget build(BuildContext context) {
    final textColor = isMyMessage ? Colors.white : Theme.of(context).colorScheme.onSurfaceVariant;
    final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('presupuestos').doc(idPresupuesto).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox(height: 50, child: Center(child: CircularProgressIndicator()));
        if (!snapshot.data!.exists) return Text("Presupuesto no encontrado.", style: TextStyle(color: textColor, fontStyle: FontStyle.italic));
        final presupuestoData = snapshot.data!.data() as Map<String, dynamic>;
        final titulo = presupuestoData['tituloPresupuesto'] ?? 'Presupuesto';
        final total = (presupuestoData['totalFinal'] ?? 0.0) as num;
        final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
        return SizedBox(
          width: MediaQuery.of(context).size.width * 0.65,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [Icon(Icons.receipt_long_outlined, color: textColor, size: 28), const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Presupuesto Enviado", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)), Text(titulo, style: TextStyle(color: textColor.withAlpha(230)), maxLines: 1, overflow: TextOverflow.ellipsis)]))]),
              const Divider(height: 16, thickness: 0.5),
              Text("TOTAL: ${formatter.format(total)}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 8),
              SizedBox(width: double.infinity, child: ElevatedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => PaginaDetallePresupuesto(presupuestoId: idPresupuesto, currentUserId: currentUserId))), style: ElevatedButton.styleFrom(backgroundColor: isMyMessage ? Colors.white : Theme.of(context).colorScheme.primary, foregroundColor: isMyMessage ? Theme.of(context).colorScheme.primary : Colors.white), child: const Text("Ver Detalles")))
            ],
          ),
        );
      },
    );
  }
}

class _DocumentBubble extends StatelessWidget {
  final String fileName;
  final String fileUrl;
  final bool isMyMessage;

  const _DocumentBubble({required this.fileName, required this.fileUrl, required this.isMyMessage});

  Future<void> _launchUrl() async {
    final uri = Uri.parse(fileUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      // Could show a snackbar here if it fails
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = isMyMessage ? Colors.white : theme.colorScheme.onSurfaceVariant;

    return InkWell(
      onTap: _launchUrl,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.insert_drive_file_rounded, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              fileName,
              style: TextStyle(color: color, decoration: TextDecoration.underline),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}