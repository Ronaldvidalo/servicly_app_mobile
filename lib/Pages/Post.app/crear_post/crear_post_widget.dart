import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path/path.dart' as p;
import 'package:servicly_app/widgets/app_background.dart';
import 'package:video_player/video_player.dart';
import 'package:video_compress/video_compress.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';

class CrearPostWidget extends StatefulWidget {
  const CrearPostWidget({super.key});

  @override
  State<CrearPostWidget> createState() => _CrearPostWidgetState();
}

class _CrearPostWidgetState extends State<CrearPostWidget> {
  final _tituloController = TextEditingController();
  final _comentarioController = TextEditingController();
  final List<File> _archivosMediaOptimizados = [];
  bool _isLoading = false;

  bool _isAdmin = false;
  bool _isLoadingRole = true;
  String? _visibilidadSeleccionada;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  @override
  void dispose() {
    _tituloController.dispose();
    _comentarioController.dispose();
    super.dispose();
  }

Future<void> _loadUserRole() async {
  setState(() => _isLoadingRole = true);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) {
    debugPrint("DEPURACIÓN: Usuario no logueado.");
    if (mounted) setState(() => _isLoadingRole = false);
    return;
  }

  try {
    debugPrint("DEPURACIÓN: Forzando actualización del token...");
    IdTokenResult tokenResult = await user.getIdTokenResult(true);

    // --- ¡ESTA LÍNEA ES LA MÁS IMPORTANTE! ---
    debugPrint("DEPURACIÓN: Claims del token: ${tokenResult.claims}");

    final bool isAdminClaim = tokenResult.claims?['admin'] == true;
    debugPrint("DEPURACIÓN: ¿Es admin según el token?: $isAdminClaim");

    if (mounted) {
      setState(() {
        _isAdmin = isAdminClaim;
        _isLoadingRole = false;
      });
    }
  } catch (e) {
    debugPrint("DEPURACIÓN: Error al cargar rol desde el token: $e");
    if (mounted) setState(() => _isLoadingRole = false);
  }
}

  Future<void> _seleccionarMedia() async {
    final picker = ImagePicker();
    final List<XFile> pickedFiles = await picker.pickMultipleMedia();

    if (pickedFiles.isEmpty) return;
    setState(() => _isLoading = true);

    // Procesamos todos los archivos en paralelo
    final List<Future<File?>> futures = pickedFiles.map((xfile) {
      final file = File(xfile.path);
      final esVideo = ['.mp4', '.mov', '.avi'].contains(p.extension(file.path).toLowerCase());
      return esVideo ? _procesarVideo(file) : _procesarImagen(file);
    }).toList();

    // Esperamos a que todos terminen
    final List<File?> resultados = await Future.wait(futures);

    // Añadimos solo los que no son nulos a la lista
    if (mounted) {
      setState(() {
        _archivosMediaOptimizados.addAll(resultados.whereType<File>());
        _isLoading = false;
      });
    }
  }
  
  Future<File?> _procesarVideo(File videoFile) async {
    final controller = VideoPlayerController.file(videoFile);
    await controller.initialize();
    final durationInSeconds = controller.value.duration.inSeconds;
    await controller.dispose();

    if (durationInSeconds > 60) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("El video no puede durar más de 1 minuto.")));
      return null;
    }

    final MediaInfo? mediaInfo = await VideoCompress.compressVideo(
      videoFile.path,
      quality: VideoQuality.MediumQuality,
      deleteOrigin: false,
    );
    
    return mediaInfo?.file;
  }

  Future<File?> _procesarImagen(File imageFile) async {
    final tempDir = await getTemporaryDirectory();
    final targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}.jpg');

    final XFile? result = await FlutterImageCompress.compressAndGetFile(
      imageFile.path,
      targetPath,
      quality: 85,
      minWidth: 1080,
      minHeight: 1080,
    );

    return result != null ? File(result.path) : null;
  }

  Future<void> _crearNuevoPost() async {
    if (!_puedeCrear) return;
    setState(() => _isLoading = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      setState(() => _isLoading = false);
      return;
    }
    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).get();
      final userData = userDoc.data() ?? {};
      final userCategorias = userData['userCategorias'] as List<dynamic>?;
      final userCountry = userData['pais'] as String?;

      final List<Map<String, String>> mediaList = [];
      final storageRef = FirebaseStorage.instance.ref();

      for (var file in _archivosMediaOptimizados) {
        final fileName = '${currentUser.uid}_${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
        final fileRef = storageRef.child('post_media/$fileName');
        
        await fileRef.putFile(file);
        final url = await fileRef.getDownloadURL();
        
        final fileExtension = p.extension(file.path).toLowerCase();
        final type = (fileExtension == '.mp4') ? 'video' : 'image';

        mediaList.add({'type': type, 'url': url});
      }

      final postData = <String, dynamic>{
        'title': _tituloController.text.trim(),
        'description': _comentarioController.text.trim(),
        'user_id': currentUser.uid,
        'authorId': currentUser.uid,
        'timestamp': FieldValue.serverTimestamp(),
        'likes': [],
        'savedBy': [],
        'media': mediaList,
        'commentCount': 0,
      };

      if (userCountry != null) postData['pais'] = userCountry;
      if (userCategorias != null && userCategorias.isNotEmpty) {
        postData['userCategorias'] = userCategorias;
        postData['category'] = userCategorias.first;
      } else {
        postData['category'] = 'General';
      }
      
      if (_isAdmin && _visibilidadSeleccionada != null) {
        postData['visibilidad'] = _visibilidadSeleccionada;
      }

      await FirebaseFirestore.instance.collection('post').add(postData);

      _resetForm();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Post creado exitosamente!')));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al crear el post: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _resetForm() {
    _tituloController.clear();
    _comentarioController.clear();
    setState(() {
      _archivosMediaOptimizados.clear();
    });
  }

  bool get _puedeCrear => _archivosMediaOptimizados.isNotEmpty && _tituloController.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Crear Publicación'),
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: FilledButton.tonal(
              onPressed: _puedeCrear && !_isLoading ? _crearNuevoPost : null,
              child: _isLoading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Publicar', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          )
        ],
      ),
      body: AppBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildMediaUploader(),
                if (_archivosMediaOptimizados.isNotEmpty) _buildMediaPreview(),
                const SizedBox(height: 24),
                _buildTextField(
                  controller: _tituloController,
                  labelText: 'Título del proyecto',
                  onChanged: (_) => setState((){}),
                ),
                const SizedBox(height: 16),
                _buildTextField(
                  controller: _comentarioController,
                  labelText: 'Describe tu trabajo...',
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                if (_isAdmin) _buildVisibilidadSelector(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVisibilidadSelector() {
    if (_isLoadingRole) {
      return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()));
    }
    return DropdownButtonFormField<String>(
      initialValue: _visibilidadSeleccionada,
      hint: const Text('Seleccionar Visibilidad (Admin)'),
      decoration: InputDecoration(
        filled: true,
        fillColor: Theme.of(context).colorScheme.surfaceContainerHighest.withAlpha(77),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
      ),
      items: const [
        DropdownMenuItem(value: 'global', child: Text('🌎 Global (Todos los países)')),
        DropdownMenuItem(value: 'Argentina', child: Text('🇦🇷 Solo Argentina')),
      ],
      onChanged: (value) {
        setState(() {
          _visibilidadSeleccionada = value;
        });
      },
    );
  }

  Widget _buildMediaUploader() {
    final colorScheme = Theme.of(context).colorScheme;
    return DottedBorder(
      color: colorScheme.primary.withAlpha(150),
      strokeWidth: 2,
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      dashPattern: const [8, 4],
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _seleccionarMedia,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(50),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Icon(Icons.add_photo_alternate_outlined, size: 48, color: colorScheme.primary),
              const SizedBox(height: 12),
              Text('Añadir Imágenes o Videos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary)),
              const SizedBox(height: 4),
              Text('Muestra tu trabajo a la comunidad', style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMediaPreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _archivosMediaOptimizados.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          return _buildPreviewTile(_archivosMediaOptimizados[index], index);
        },
      ),
    );
  }

  Widget _buildPreviewTile(File file, int index) {
    final fileExtension = p.extension(file.path).toLowerCase();
    final esVideo = ['.mp4', '.mov', '.avi'].contains(fileExtension);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          esVideo
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.secondary, colorScheme.primary],
                      begin: Alignment.bottomLeft, end: Alignment.topRight,
                    ),
                  ),
                  child: const Icon(Icons.videocam_outlined, color: Colors.white, size: 32),
                )
              : Image.file(file, fit: BoxFit.cover),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => setState(() => _archivosMediaOptimizados.removeAt(index)),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: colorScheme.errorContainer,
                child: Icon(Icons.close, size: 16, color: colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String labelText,
    int? maxLines,
    Function(String)? onChanged,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: labelText,
        alignLabelWithHint: true,
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withAlpha(77),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
      ),
    );
  }
}