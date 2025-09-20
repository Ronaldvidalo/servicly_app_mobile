import 'dart:io';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/models/contrato_model.dart';
import 'package:servicly_app/widgets/rating_stars_widget.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PaginaDetalleContrato extends StatefulWidget {
  final String contratoId;
  final String currentUserId;

  const PaginaDetalleContrato({
    super.key,
    required this.contratoId,
    required this.currentUserId,
  });

  @override
  State<PaginaDetalleContrato> createState() => _PaginaDetalleContratoState();
}

class _PaginaDetalleContratoState extends State<PaginaDetalleContrato> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  int? _uploadingIndex;
  bool _isLoadingAction = false;

   final TextEditingController _chatController = TextEditingController();

 (IconData, Color, Color?) _getInfoHito(String estado, ThemeData theme) {
    switch (estado) {
      case 'EN_REVISION':
        return (
          Icons.hourglass_top_rounded,
          theme.colorScheme.primary,
          theme.colorScheme.primary.withOpacity(0.1));
      case 'CONFIRMADO':
        return (
          Icons.check_circle_rounded,
          Colors.green.shade700,
          Colors.green.withOpacity(0.1));
      case 'PENDIENTE':
      default:
        return (
          Icons.radio_button_unchecked_rounded,
          Colors.grey.shade600,
          null);
    }
  }
  

  Future<void> _actualizarEstadoTrabajo(String nuevoEstado) async {
    if (_isLoadingAction) return;
    setState(() => _isLoadingAction = true);
    try {
      await _firestore.collection('contratos').doc(widget.contratoId).update({'estadoTrabajo': nuevoEstado});
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar estado: $e')));
    } finally {
      if (mounted) setState(() => _isLoadingAction = false);
    }
  }

   void _mostrarFormularioDePago(int index, Contrato contrato, double montoHito) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: _FormularioInformarPago(
          montoDelHito: montoHito,
          onSubirPago: (detalles, archivo) {
            _procesarYSubirPago(index, contrato, detalles, archivo);
            
            // --- AÑADE ESTAS LÍNEAS PARA DEPURAR REGLA DE STORAGE ---
            print('--- DATOS PARA DEPURAR REGLA DE STORAGE ---');
            print('1. UID del Usuario (request.auth.uid): ${widget.currentUserId}');
            print('2. ID del Contrato (contratoId): ${contrato.id}');
            print('3. ID del Cliente en Firestore (debe coincidir con el 1): ${contrato.clienteId}');
            print('-------------------------------------------');
          },
        ),
      ),
    );
  }

Future<void> _procesarYSubirPago(
    int index, Contrato contrato, Map<String, dynamic> detalles, File? archivo) async {
  if (_uploadingIndex != null) return; // Evita subidas múltiples

  setState(() {
    _uploadingIndex = index;
  });
  Navigator.of(context).pop(); // Cierra el bottom sheet

  try {
    String? downloadUrl;

    // ✅ Subir archivo si existe
    if (archivo != null) {
      downloadUrl = await _subirArchivo(archivo, widget.currentUserId);

      print('--- DEPURACIÓN SUBIDA ---');
      print('Archivo: ${archivo.path}');
      print('URL obtenida: $downloadUrl');
      print('Contrato ID: ${contrato.id}');
      print('Cliente ID: ${contrato.clienteId}');
      print('Usuario actual (UID): ${widget.currentUserId}');
      print('-------------------------');
    }

    // ✅ Actualizar hitos en Firestore
    List<Map<String, dynamic>> nuevosHitos =
        contrato.hitosDePago.map((h) => h.toMap()).toList();

    nuevosHitos[index]['estadoPago'] = 'EN_REVISION';
    nuevosHitos[index]['comprobanteUrl'] = downloadUrl;
    nuevosHitos[index]['fechaSubidaComprobante'] = Timestamp.now();
    nuevosHitos[index]['detallesPagoCliente'] = detalles;

    final nuevoEvento = {
      'evento': 'Informe de Pago Recibido',
      'fecha': Timestamp.now(),
      'descripcion':
          'El cliente informó el pago del hito "${nuevosHitos[index]['descripcion']}" por ${detalles['monto']}.',
      'adjuntoUrl': downloadUrl,
    };

    await _firestore.collection('contratos').doc(widget.contratoId).update({
      'hitosDePago': nuevosHitos,
      'historialEventos': FieldValue.arrayUnion([nuevoEvento])
    });

    print("✅ Hito de pago actualizado correctamente");

  } catch (e) {
    print("❌ Error en _procesarYSubirPago: $e");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al subir el pago: $e')),
      );
    }
  } finally {
    if (mounted) {
      setState(() {
        _uploadingIndex = null;
      });
    }
  }
}

/// 🔹 Función separada para subir cualquier archivo (imagen/pdf/etc.)
Future<String?> _subirArchivo(File file, String userId) async {
  try {
    final String nombreArchivo = file.path.split('/').last;
    final String extension = nombreArchivo.split('.').last;

    // Definir tipo MIME
    String contentType = "application/octet-stream";
    if (["jpg", "jpeg", "png"].contains(extension.toLowerCase())) {
      contentType = "image/${extension.toLowerCase() == "jpg" ? "jpeg" : extension.toLowerCase()}";
    } else if (extension.toLowerCase() == "pdf") {
      contentType = "application/pdf";
    }

    // Ruta única
    final Reference ref = _storage
        .ref()
        .child("comprobantes/$userId/${DateTime.now().millisecondsSinceEpoch}_$nombreArchivo");

    final UploadTask uploadTask = ref.putFile(
      file,
      SettableMetadata(contentType: contentType),
    );

    final TaskSnapshot snapshot = await uploadTask;
    final String url = await snapshot.ref.getDownloadURL();

    print("✅ Archivo subido correctamente: $url");
    return url;
  } catch (e) {
    print("❌ Error al subir archivo: $e");
    return null;
  }
}

  Future<void> _actualizarEstadoHito(int index, Contrato contrato, String nuevoEstado) async {
    List<Map<String, dynamic>> nuevosHitos = contrato.hitosDePago.map((h) => h.toMap()).toList();
    nuevosHitos[index]['estadoPago'] = nuevoEstado;

    if (nuevoEstado == 'CONFIRMADO') {
      nuevosHitos[index]['fechaConfirmacionPago'] = Timestamp.now();
    } else if (nuevoEstado == 'PENDIENTE') {
      nuevosHitos[index]['comprobanteUrl'] = null;
      nuevosHitos[index]['fechaSubidaComprobante'] = null;
    }

    await _firestore.collection('contratos').doc(widget.contratoId).update({'hitosDePago': nuevosHitos});
  }

  Future<void> _confirmarFinalizacionYEvaluar(Contrato contrato) async {
    final resultado = await showDialog<Map<String, dynamic>>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _DialogoEvaluacion(),
    );

    if (resultado != null) {
      setState(() => _isLoadingAction = true);
      try {
        final batch = _firestore.batch();
        final contratoRef = _firestore.collection('contratos').doc(widget.contratoId);
        final usuarioRef = _firestore.collection('usuarios').doc(contrato.proveedorId);
        final fechaFinalizacion = Timestamp.now();

        batch.update(contratoRef, {
          'estadoTrabajo': 'EN_GARANTIA',
          'fechaFinalizacionCliente': fechaFinalizacion,
          'evaluacion': {
            'rating': resultado['rating'],
            'comentario': resultado['comentario'],
            'fecha': fechaFinalizacion,
            'clienteId': widget.currentUserId,
          }
        });

        batch.update(usuarioRef, {
          'ratingSum': FieldValue.increment(resultado['rating']),
          'ratingCount': FieldValue.increment(1),
        });
        await batch.commit();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al finalizar: $e')));
      } finally {
        if (mounted) setState(() => _isLoadingAction = false);
      }
    }
  }

  void _verComprobante(String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.network(
            url,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator()),
            errorBuilder: (context, error, stack) => const Center(child: Text('No se pudo cargar la imagen.')),
          ),
        ),
      ),
    );
  }

  // --- CONSTRUCCIÓN DE LA UI (NUEVA ESTRUCTURA) ---

 // --- NUEVA FUNCIÓN PARA ENVIAR MENSAJES ---
  Future<void> _enviarMensaje() async {
    final texto = _chatController.text.trim();
    if (texto.isEmpty) {
      return; // No enviar mensajes vacíos
    }

    _chatController.clear();

    await _firestore
        .collection('chats')
        .doc(widget.contratoId)
        .collection('messages')
        .add({
      'texto': texto,
      'senderId': widget.currentUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }


  // --- WIDGETS DE CONSTRUCCIÓN DE LA UI ---

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _firestore.collection('contratos').doc(widget.contratoId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (!snapshot.hasData || snapshot.data?.data() == null) {
          return const Scaffold(body: Center(child: Text('No se encontró el contrato.')));
        }

        final contrato = Contrato.fromFirestore(snapshot.data!);
        final esCliente = widget.currentUserId == contrato.clienteId;

        return DefaultTabController(
          length: 3,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Seguimiento del Contrato'),
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              elevation: 0,
              scrolledUnderElevation: 2,
            ),
            body: Column(
              children: [
                _buildHeaderFormal(context, contrato),
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildPestanaSeguimiento(context, contrato, esCliente),
                      // --- INTEGRACIÓN DEL CHAT ---
                      _buildPestanaChat(context, contrato, esCliente),
                      _buildPestanaDetalles(context, contrato),
                    ],
                  ),
                ),
                _buildActionArea(context, contrato, esCliente),
              ],
            ),
            bottomNavigationBar: const TabBar(
              tabs: [
                Tab(icon: Icon(Icons.sync_alt_rounded), text: 'Seguimiento'),
                Tab(icon: Icon(Icons.chat_bubble_outline_rounded), text: 'Chat'),
                Tab(icon: Icon(Icons.info_outline_rounded), text: 'Detalles'),
              ],
            ),
          ),
        );
      },
    );
  }
  
  // --- NUEVOS WIDGETS PARA LA UI MEJORADA ---

  Widget _buildHeaderFormal(BuildContext context, Contrato contrato) {
 final theme = Theme.of(context);
    final formatadorMoneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    return Container(
      width: double.infinity,
      color: theme.colorScheme.surfaceContainer,
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Contrato N°: ${contrato.numeroContrato}',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 16),
              Text(
                DateFormat('dd/MM/yyyy').format(contrato.fechaConfirmacion.toDate()),
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildResumenChip(context, icon: Icons.monetization_on_outlined, label: 'Monto Total', value: formatadorMoneda.format(contrato.total)),
              _buildResumenChip(context, icon: Icons.shield_outlined, label: 'Garantía', value: '${contrato.garantiaDias} días'),
              _buildResumenChip(context, icon: Icons.timer_outlined, label: 'Duración', value: contrato.duracionEstimada),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResumenChip(BuildContext context, {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, size: 20, color: theme.colorScheme.primary),
        const SizedBox(height: 4),
        Text(label, style: theme.textTheme.labelSmall),
        Text(value, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildPestanaSeguimiento(BuildContext context, Contrato contrato, bool esCliente) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildHeaderStatus(context, contrato),
        const SizedBox(height: 24),
        _buildHitosDePago(context, contrato, esCliente),
        const SizedBox(height: 24),
        _buildGarantia(context, contrato),
        const SizedBox(height: 24),
        _buildEvaluacion(context, contrato),
      ],
    );
  }
  
  Widget _buildPestanaDetalles(BuildContext context, Contrato contrato) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        Text('Historial de Eventos', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        if (contrato.historialEventos.isEmpty)
          const Text('No hay eventos registrados.'),
        ...contrato.historialEventos.map((evento) {
          final fecha = (evento['fecha'] as Timestamp?)?.toDate();
          return Card(
            child: ListTile(
              leading: const Icon(Icons.history_toggle_off_rounded),
              title: Text(evento['evento'] ?? 'Evento'),
              subtitle: Text(evento['descripcion'] ?? ''),
              trailing: fecha != null
                  ? Text(DateFormat('dd/MM/yy\nHH:mm').format(fecha), textAlign: TextAlign.center, style: Theme.of(context).textTheme.labelSmall)
                  : null,
            ),
          );
        }).toList().reversed,
      ],
    );
  }

Widget _buildPestanaChat(BuildContext context, Contrato contrato, bool esCliente) {
    return Column(
      children: [
        Expanded(
          child: _buildListaMensajes(context),
        ),
        _buildInputArea(context),
      ],
    );
  }

  Widget _buildListaMensajes(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _firestore
          .collection('chats')
          .doc(widget.contratoId)
          .collection('messages')
          .orderBy('timestamp', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text("Aún no hay mensajes. ¡Inicia la conversación!"));
        }

        final messages = snapshot.data!.docs;

        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: messages.length,
          itemBuilder: (context, index) {
            final messageData = messages[index].data();
            final esMiMensaje = messageData['senderId'] == widget.currentUserId;
            
            return _ChatBubble(
              texto: messageData['texto'] ?? '',
              esMiMensaje: esMiMensaje,
            );
          },
        );
      },
    );
  }

  Widget _buildInputArea(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: EdgeInsets.only(
        left: 16, 
        right: 8, 
        top: 8, 
        bottom: 8 + MediaQuery.of(context).viewPadding.bottom
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(top: BorderSide(color: theme.dividerColor)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _chatController,
              decoration: const InputDecoration(
                hintText: 'Escribe un mensaje...',
                border: InputBorder.none,
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
          ),
          IconButton(
            icon: Icon(Icons.send_rounded, color: theme.colorScheme.primary),
            onPressed: _enviarMensaje,
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  (String, Color, IconData) _getStatusInfo(String estado) {
    switch (estado) {
      case 'POR_INICIAR': return ('Por Iniciar', Colors.blue, Icons.play_circle_outline_rounded);
      case 'EN_PROGRESO': return ('En Progreso', Colors.cyan, Icons.construction_rounded);
      case 'FINALIZADO_PROVEEDOR': return ('Finalizado por Proveedor', Colors.orange, Icons.flag_rounded);
      case 'EN_GARANTIA': return ('En Garantía', Colors.amber.shade700, Icons.shield_rounded);
      case 'GARANTIA_EXPIRADA': return ('Completado', Colors.grey, Icons.check_circle);
      default: return ('Completado', Colors.green, Icons.check_circle);
    }
  }

  Widget _buildHeaderStatus(BuildContext context, Contrato contrato) {
    final (texto, color, icono) = _getStatusInfo(contrato.estadoTrabajo);
    return Chip(
      avatar: Icon(icono, color: Colors.white),
      label: Text(texto, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
      backgroundColor: color
    );
  }

  
  Widget _buildHitosDePago(BuildContext context, Contrato contrato, bool esCliente) {
  final theme = Theme.of(context); // Obtenemos el tema una sola vez

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text('Hitos de Pago', style: theme.textTheme.titleLarge),
      const SizedBox(height: 8),
      if (contrato.hitosDePago.isEmpty) const Text('No se definieron hitos de pago.'),
      
      ...contrato.hitosDePago.asMap().entries.map((entry) {
        int idx = entry.key;
        HitoPago hito = entry.value;
        final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

        // La lógica para definir el widget de la derecha no cambia
        Widget trailingWidget;
        switch (hito.estadoPago) {
          case 'PENDIENTE':
            trailingWidget = esCliente
                ? FilledButton(
                    onPressed: () => _mostrarFormularioDePago(idx, contrato, hito.monto),
                    child: const Text('Informar Pago'))
                : Text(formatter.format(hito.monto));
            break;
          case 'EN_REVISION':
            trailingWidget = esCliente
                ? const Chip(label: Text('En revisión...'), avatar: Icon(Icons.hourglass_top, size: 16))
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(icon: const Icon(Icons.check_circle, color: Colors.green), tooltip: 'Confirmar Pago', onPressed: () => _actualizarEstadoHito(idx, contrato, 'CONFIRMADO')),
                      IconButton(icon: const Icon(Icons.cancel, color: Colors.red), tooltip: 'Rechazar Comprobante', onPressed: () => _actualizarEstadoHito(idx, contrato, 'PENDIENTE')),
                    ],
                  );
            break;
          case 'CONFIRMADO':
            trailingWidget = Text(formatter.format(hito.monto), style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.grey));
            break;
          default:
            trailingWidget = const Text('Error');
        }

        // --- APLICAMOS LOS NUEVOS ESTILOS AQUÍ ---
        final (iconData, iconColor, cardColor) = _getInfoHito(hito.estadoPago, theme);

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: cardColor != null ? Colors.transparent : theme.dividerColor.withOpacity(0.5),
            ),
          ),
          color: cardColor, // <-- Color de fondo dinámico
          child: ListTile(
            leading: Icon(
              iconData,      // <-- Ícono dinámico
              color: iconColor, // <-- Color de ícono dinámico
            ),
            title: Text(hito.descripcion),
            subtitle: hito.comprobanteUrl != null && hito.comprobanteUrl!.isNotEmpty
                ? InkWell(
                    child: Text('Ver comprobante', style: TextStyle(color: theme.colorScheme.primary, decoration: TextDecoration.underline)),
                    onTap: () => _verComprobante(hito.comprobanteUrl!),
                  )
                : null,
            trailing: _uploadingIndex == idx
                ? const CircularProgressIndicator()
                : trailingWidget,
          ),
        );
      }),
    ],
  );
}
  
  Widget _buildGarantia(BuildContext context, Contrato contrato) {
    if (contrato.estadoTrabajo != 'EN_GARANTIA' && contrato.estadoTrabajo != 'GARANTIA_EXPIRADA') {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.shield_outlined),
          title: Text('Garantía de ${contrato.garantiaDias} días'),
          subtitle: const Text('La garantía comenzará cuando confirmes la finalización del trabajo.'),
        ),
      );
    }
    
    final fechaFin = contrato.fechaFinalizacionCliente!.toDate();
    final fechaExpiracion = fechaFin.add(Duration(days: contrato.garantiaDias));
    final diasRestantes = fechaExpiracion.difference(DateTime.now()).inDays;

    if (diasRestantes < 0) {
      if (contrato.estadoTrabajo == 'EN_GARANTIA') {
        Future.microtask(() => _actualizarEstadoTrabajo('GARANTIA_EXPIRADA'));
      }
      return const Card(child: ListTile(leading: Icon(Icons.shield, color: Colors.grey), title: Text('Garantía Expirada')));
    }

    return Card(
      color: Colors.amber.shade50,
      child: ListTile(
        leading: const Icon(Icons.shield, color: Colors.amber),
        title: Text('$diasRestantes días de garantía restantes'),
        subtitle: Text('Expira el ${DateFormat('dd/MM/yyyy').format(fechaExpiracion)}'),
      ),
    );
  }
  
  Widget _buildEvaluacion(BuildContext context, Contrato contrato) {
      if(contrato.evaluacion == null) return const SizedBox.shrink();
      
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            Text('Tu Evaluación', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Card(
                child: ListTile(
                    title: RatingStars(rating: contrato.evaluacion!.rating, ratingCount: 0),
                    subtitle: Text('"${contrato.evaluacion!.comentario}"'),
                ),
            ),
        ],
      );
  }

  Widget _buildActionArea(BuildContext context, Contrato contrato, bool esCliente) {
    // CORRECCIÓN: Se usa hito.estadoPago en lugar del antiguo hito.pagado
    bool todosPagosHechos = contrato.hitosDePago.isEmpty || contrato.hitosDePago.every((h) => h.estadoPago == 'CONFIRMADO');

    if (!esCliente) { // Vista del Proveedor
      if (contrato.estadoTrabajo == 'POR_INICIAR') {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: FilledButton.icon(icon: const Icon(Icons.construction), label: const Text('Comenzar Trabajo'), onPressed: () => _actualizarEstadoTrabajo('EN_PROGRESO')),
          );
      }
      if (contrato.estadoTrabajo == 'EN_PROGRESO') {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(icon: const Icon(Icons.flag), label: const Text('Marcar Trabajo como Finalizado'), onPressed: () => _actualizarEstadoTrabajo('FINALIZADO_PROVEEDOR')),
        );
      }
    }
    else { // Vista del Cliente
      if (contrato.estadoTrabajo == 'FINALIZADO_PROVEEDOR' && todosPagosHechos) {
         return Padding(
          padding: const EdgeInsets.all(16.0),
          child: FilledButton.icon(
            icon: const Icon(Icons.check_circle),
            label: const Text('Confirmar Terminación y Evaluar'),
            style: FilledButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () => _confirmarFinalizacionYEvaluar(contrato),
          ),
        );
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildInfoRow({required IconData icon, required String label, required String value, bool isLarge = false}) {
    final textTheme = Theme.of(context).textTheme;
    return Row(
      children: [
        Icon(icon, color: textTheme.bodySmall?.color, size: 20),
        const SizedBox(width: 16),
        Expanded(child: Text(label, style: textTheme.bodyLarge)),
        Text(value, style: isLarge ? textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold) : textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
class _ChatBubble extends StatelessWidget {
  final String texto;
  final bool esMiMensaje;

  const _ChatBubble({required this.texto, required this.esMiMensaje});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final alignment = esMiMensaje ? Alignment.centerRight : Alignment.centerLeft;
    final color = esMiMensaje ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest;
    final textColor = esMiMensaje ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;

    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: esMiMensaje ? const Radius.circular(16) : Radius.zero,
            bottomRight: esMiMensaje ? Radius.zero : const Radius.circular(16),
          ),
        ),
        child: Text(texto, style: TextStyle(color: textColor)),
      ),
    );
  }
}

// --- DIÁLOGO PARA DEJAR LA EVALUACIÓN ---
class _DialogoEvaluacion extends StatefulWidget {
  @override
  __DialogoEvaluacionState createState() => __DialogoEvaluacionState();
}

class __DialogoEvaluacionState extends State<_DialogoEvaluacion> {
  double _rating = 5.0;
  final _comentarioController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Evaluá al Proveedor'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Calificación: ${_rating.toStringAsFixed(1)} estrellas'),
            Slider(
              value: _rating,
              min: 1,
              max: 5,
              divisions: 8,
              label: _rating.toStringAsFixed(1),
              onChanged: (value) => setState(() => _rating = value),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _comentarioController,
              decoration: const InputDecoration(
                labelText: 'Comentario (opcional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: () {
          Navigator.of(context).pop({
            'rating': _rating,
            'comentario': _comentarioController.text,
          });
        }, child: const Text('Enviar Evaluación')),
      ],
    );
  }
}
class _FormularioInformarPago extends StatefulWidget {
  final Function(Map<String, dynamic> detalles, File? archivo) onSubirPago;
  final double montoDelHito; // <-- Parámetro requerido

  const _FormularioInformarPago({
    required this.onSubirPago,
    required this.montoDelHito, // <-- Se define en el constructor
  });

  @override
  State<_FormularioInformarPago> createState() => _FormularioInformarPagoState();
}

class _FormularioInformarPagoState extends State<_FormularioInformarPago> {
  final _formKey = GlobalKey<FormState>();
  final _montoController = TextEditingController();
  final _bancoController = TextEditingController();
  final _fechaController = TextEditingController();
  File? _archivoSeleccionado;
  String _nombreArchivo = 'Ningún archivo seleccionado';

  @override
  void initState() {
    super.initState();
    // Pre-cargamos el monto del hito que recibimos
    _montoController.text = widget.montoDelHito.toStringAsFixed(2);
    print("UID actual: ${FirebaseAuth.instance.currentUser?.uid}");
  }

  @override
  void dispose() {
    _montoController.dispose();
    _bancoController.dispose();
    _fechaController.dispose();
    super.dispose();
  }

  Future<void> _seleccionarFecha() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _fechaController.text = DateFormat('dd/MM/yyyy').format(picked);
      });
    }
  }

  Future<void> _seleccionarArchivo() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result != null) {
      setState(() {
        _archivoSeleccionado = File(result.files.single.path!);
        _nombreArchivo = result.files.single.name;
      });
    }
  }

  void _enviarFormulario() {
    if (_formKey.currentState!.validate()) {
      final detalles = {
        'monto': _montoController.text,
        'banco': _bancoController.text,
        'fecha': _fechaController.text,
      };
      widget.onSubirPago(detalles, _archivoSeleccionado);
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatadorMoneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Informar Pago', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              elevation: 0,
              child: ListTile(
                title: const Text('Monto a Pagar'),
                trailing: Text(
                  formatadorMoneda.format(widget.montoDelHito),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _montoController,
              decoration: const InputDecoration(labelText: 'Monto Pagado', prefixText: '\$ '),
              keyboardType: TextInputType.number,
              validator: (v) => v!.isEmpty ? 'Ingresa un monto' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _bancoController,
              decoration: const InputDecoration(labelText: 'Banco de Origen'),
              validator: (v) => v!.isEmpty ? 'Ingresa un banco' : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _fechaController,
              decoration: const InputDecoration(labelText: 'Fecha de Pago', suffixIcon: Icon(Icons.calendar_today)),
              readOnly: true,
              onTap: _seleccionarFecha,
              validator: (v) => v!.isEmpty ? 'Selecciona una fecha' : null,
            ),
            const SizedBox(height: 24),
            Text('Comprobante (Opcional)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.attach_file),
              label: const Text('Seleccionar Archivo (PDF o Imagen)'),
              onPressed: _seleccionarArchivo,
            ),
            const SizedBox(height: 4),
            Text(_nombreArchivo, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _enviarFormulario,
                child: const Text('Enviar Informe de Pago'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}