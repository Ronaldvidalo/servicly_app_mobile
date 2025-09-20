import 'package:flutter/material.dart';

import 'package:servicly_app/models/solicitud_model.dart';
import 'package:servicly_app/pages/crear_presupuesto/crear_presupuesto_widget.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:chewie/chewie.dart';
import 'package:video_player/video_player.dart';
import 'package:servicly_app/Pages/perfil_pagina/perfil_pagina_widget.dart';

class DetalleSolicitudWidget extends StatefulWidget {
  final Solicitud solicitud;

  const DetalleSolicitudWidget({
    super.key,
    required this.solicitud,
  });

  @override
  State<DetalleSolicitudWidget> createState() => _DetalleSolicitudWidgetState();
}

class _DetalleSolicitudWidgetState extends State<DetalleSolicitudWidget> {
  bool _isLoading = true;
  bool _presupuestoYaEnviado = false;
  Map<String, dynamic>? _authorData;
  bool _isAuthorLoading = true;

  @override
  void initState() {
    super.initState();
    _verificarPresupuestoExistente();
    _loadAuthorData();
  }

  Future<void> _loadAuthorData() async {
    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(widget.solicitud.user_id).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _authorData = userDoc.data();
        });
      }
    } catch (e) {
      debugPrint("Error cargando datos del autor: $e");
    } finally {
      if (mounted) setState(() => _isAuthorLoading = false);
    }
  }

  Future<void> _verificarPresupuestoExistente() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('presupuestos')
          .where('idSolicitud', isEqualTo: widget.solicitud.id)
          .where('realizadoPor', isEqualTo: currentUser.uid)
          .limit(1)
          .get();

      if (mounted) {
        setState(() {
          _presupuestoYaEnviado = querySnapshot.docs.isNotEmpty;
        });
      }
    } catch (e) {
      debugPrint("Error al verificar presupuesto: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool esCreadorDeLaSolicitud = FirebaseAuth.instance.currentUser?.uid == widget.solicitud.user_id;

    return Scaffold(
      bottomSheet: esCreadorDeLaSolicitud ? null : _buildBottomSheet(),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: const Text('Detalle de la Solicitud'),
            backgroundColor: theme.scaffoldBackgroundColor,
            elevation: 0,
            scrolledUnderElevation: 2,
            pinned: true,
            floating: true,
          ),
          if (widget.solicitud.media.isNotEmpty)
            SliverToBoxAdapter(child: _MediaViewer(media: widget.solicitud.media)),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _buildAuthorHeader(theme),
                const Divider(height: 32),
                Text(widget.solicitud.titulo, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
              ]),
            ),
          ),
          _buildDetailsGrid(),
          SliverPadding(
            padding: const EdgeInsets.all(16.0),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const Divider(height: 32),
                Text('Descripción del Trabajo', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                Text(
                  widget.solicitud.descripcion,
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.6, color: theme.textTheme.bodyMedium?.color?.withAlpha(204)),
                ),
                const SizedBox(height: 120),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAuthorHeader(ThemeData theme) {
  if (_isAuthorLoading) {
    // ... (Tu código de Shimmer/Loading no cambia)
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(radius: 25, backgroundColor: Colors.black12),
      title: Container(height: 16, width: 150, color: Colors.black12, margin: const EdgeInsets.only(bottom: 4)),
      subtitle: Container(height: 12, width: 100, color: Colors.black12),
    );
  }
  final autorNombre = _authorData?['display_name'] ?? 'Usuario Anónimo';
  final autorFotoUrl = _authorData?['photo_url'] ?? '';

  return InkWell(
    onTap: () {
           Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PerfilPaginaWidget(
            user_id: widget.solicitud.user_id,
          ),
        ),
      );
    },
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        radius: 25,
        backgroundImage: autorFotoUrl.isNotEmpty ? NetworkImage(autorFotoUrl) : null,
        child: autorFotoUrl.isEmpty ? const Icon(Icons.person) : null,
      ),
      title: Text(autorNombre, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text('Publicado el ${DateFormat('dd/MM/yyyy', 'es_ES').format(widget.solicitud.fechaCreacion.toDate())}'),
    ),
  );
}

Widget _buildDetailsGrid() {
  final String ubicacion = [widget.solicitud.municipio, widget.solicitud.provincia]
      .where((s) => s != null && s.isNotEmpty)
      .join(', ');

  final List<Widget> detailChips = [
    _DetailChip(icon: Icons.category_outlined, label: 'Categoría', value: widget.solicitud.categoria),
    if (ubicacion.isNotEmpty)
      _DetailChip(icon: Icons.location_on_outlined, label: 'Ubicación', value: ubicacion),
    if (widget.solicitud.prioridad != null && widget.solicitud.prioridad!.isNotEmpty)
      _DetailChip(icon: Icons.priority_high_rounded, label: 'Prioridad', value: widget.solicitud.prioridad!),
    if (widget.solicitud.formaPago != null && widget.solicitud.formaPago!.isNotEmpty)
      _DetailChip(icon: Icons.payment_outlined, label: 'Pago', value: widget.solicitud.formaPago!),
    if (widget.solicitud.horario != null && widget.solicitud.horario!.isNotEmpty)
      _DetailChip(icon: Icons.access_time_outlined, label: 'Horario', value: widget.solicitud.horario!),
    _DetailChip(icon: Icons.shield_outlined, label: 'Requiere Seguro', value: widget.solicitud.requiereSeguro ? 'Sí' : 'No'),
  ];

  return SliverPadding(
    padding: const EdgeInsets.symmetric(horizontal: 16.0),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 250.0,
        mainAxisSpacing: 12.0,
        crossAxisSpacing: 12.0,
        // --- LA CORRECCIÓN ESTÁ AQUÍ ---
        // 1. Eliminamos `mainAxisExtent: 70`.
        // 2. Añadimos `childAspectRatio`.
        // Un valor de 2.4 significa que el ancho de la celda será 2.4 veces su altura.
        // Esto le da más espacio vertical para que el texto no se desborde.
        childAspectRatio: 2.4, 
      ),
      delegate: SliverChildBuilderDelegate(
        (context, index) => detailChips[index],
        childCount: detailChips.length,
      ),
    ),
  );
}


  Widget _buildBottomSheet() {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).padding.bottom),
      width: double.infinity,
      decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Colors.grey.withAlpha(50), width: 1))),
      child: _buildActionButton(),
    );
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_presupuestoYaEnviado) {
      return Center(
        child: Chip(
          avatar: Icon(Icons.check_circle, color: Colors.green.shade700),
          label: const Text('Ya enviaste un presupuesto'),
          backgroundColor: Colors.green.withAlpha(50),
        ),
      );
    }

    return ElevatedButton.icon(
      icon: const Icon(Icons.note_add_outlined),
      label: const Text('Crear Presupuesto'),
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => CrearPresupuestoPage(solicitud: widget.solicitud),
          ),
        );
      },
    );
  }
}

class _DetailChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _DetailChip({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: theme.textTheme.labelSmall, overflow: TextOverflow.ellipsis),
                Text(
                  value,
                  style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _MediaViewer extends StatefulWidget {
  final List<Map<String, dynamic>> media;
  const _MediaViewer({required this.media});

  @override
  State<_MediaViewer> createState() => _MediaViewerState();
}

class _MediaViewerState extends State<_MediaViewer> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.media.isEmpty) return const SizedBox.shrink();

    return AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView.builder(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                _currentPage = index;
              });
            },
            itemCount: widget.media.length,
            itemBuilder: (context, index) {
              final item = widget.media[index];
              final type = item['type'] ?? 'image';
              final url = item['url'] ?? '';

              if (url.isEmpty) return const Center(child: Icon(Icons.error_outline, color: Colors.red, size: 60));
              
              if (type == 'video') {
                return _VideoPlayerItem(videoUrl: url);
              } else {
                return GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        backgroundColor: Colors.transparent,
                        insetPadding: EdgeInsets.zero,
                        child: Stack(
                          children: [
                            PhotoView(
                              imageProvider: NetworkImage(url),
                              minScale: PhotoViewComputedScale.contained,
                              maxScale: PhotoViewComputedScale.covered * 2,
                            ),
                            Positioned(
                              top: 40,
                              right: 20,
                              child: IconButton(
                                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                                onPressed: () => Navigator.of(context).pop(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                  // AHORA: El único cambio. `BoxFit.cover` se cambia por `BoxFit.contain`.
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    width: double.infinity,
                    loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
                    errorBuilder: (context, error, stackTrace) => const Center(child: Icon(Icons.broken_image, color: Colors.grey, size: 60)),
                  ),
                );
              }
            },
          ),
          if (widget.media.length > 1)
            Positioned(
              bottom: 10,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(widget.media.length, (index) {
                  final baseColor = Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black;
                  final alpha = _currentPage == index ? (255 * 0.9).round() : (255 * 0.4).round();
                  return Container(
                    width: 8.0,
                    height: 8.0,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: baseColor.withAlpha(alpha),
                    ),
                  );
                }),
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPlayerItem extends StatefulWidget {
  final String videoUrl;
  const _VideoPlayerItem({required this.videoUrl});

  @override
  _VideoPlayerItemState createState() => _VideoPlayerItemState();
}

// CORRECCIÓN: La clase State debe extender su propio widget: State<_VideoPlayerItem>
class _VideoPlayerItemState extends State<_VideoPlayerItem> {
  VideoPlayerController? _videoPlayerController;
  ChewieController? _chewieController;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    initializePlayer();
  }

  @override
  void dispose() {
    _videoPlayerController?.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  Future<void> initializePlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.videoUrl));
      await _videoPlayerController!.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController!,
        autoPlay: false,
        looping: false,
        placeholder: const Center(child: CircularProgressIndicator()),
        errorBuilder: (context, errorMessage) {
          return const Center(
            child: Text('Error al cargar el video', style: TextStyle(color: Colors.white)),
          );
        },
      );
      
      if (mounted) setState(() => _isLoading = false);

    } catch(e) {
      debugPrint("Error inicializando video: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _chewieController == null || !_videoPlayerController!.value.isInitialized) {
      return const AspectRatio(
        aspectRatio: 16 / 9,
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return AspectRatio(
      aspectRatio: _videoPlayerController!.value.aspectRatio,
      child: Chewie(
        controller: _chewieController!,
      ),
    );
  }
}