import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

class VideoPlayerWidget extends StatefulWidget {
  final String videoUrl;

  const VideoPlayerWidget({
    super.key,
    required this.videoUrl,
  });

  @override
  State<VideoPlayerWidget> createState() => _VideoPlayerWidgetState();
}

class _VideoPlayerWidgetState extends State<VideoPlayerWidget> {
  // Usamos controladores nulables para evitar errores de inicialización tardía.
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  @override
  void dispose() {
    // Liberamos los recursos de forma segura.
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> _initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController!.initialize();

      // Creamos el controlador de Chewie que añade la interfaz de usuario.
      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'No se pudo cargar el video.',
              style: TextStyle(color: Colors.white.withOpacity(0.8)),
            ),
          );
        },
      );
      
      // Si el widget todavía existe, actualizamos el estado.
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error al inicializar el video: $e");
      if (mounted) {
        setState(() {
          _isLoading = false; // Dejamos de cargar incluso si hay error
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Si está cargando o hubo un error en la inicialización, muestra un indicador.
    if (_isLoading || _chewieController == null) {
      return AspectRatio(
        aspectRatio: 16 / 9, // Proporción estándar de video
        child: Container(
          color: Colors.black,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    // Si todo está listo, muestra el reproductor de Chewie.
    return AspectRatio(
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      child: Chewie(
        controller: _chewieController!,
      ),
    );
  }
}