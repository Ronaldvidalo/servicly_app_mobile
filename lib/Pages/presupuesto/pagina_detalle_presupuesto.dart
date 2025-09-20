import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/models/presupuesto_detallado_model.dart';
import 'package:servicly_app/pages/contrato/pagina_detalle_contrato.dart';
// ✅ CORRECCIÓN 1: Ocultamos la clase 'ChatService' del archivo de la página para evitar conflictos.
import 'package:servicly_app/pages/chat/chat_page.dart' hide ChatService; 
import 'package:servicly_app/services/chat_service.dart'; // Importamos el ChatService correcto.
import 'package:servicly_app/widgets/rating_stars_widget.dart';
import 'package:servicly_app/utils/utilidades_contrato.dart';
// ✅ CORRECCIÓN 3: Se elimina el import de firebase_auth que no se usaba.



class PaginaDetallePresupuesto extends StatefulWidget {
  final String presupuestoId;
  final String currentUserId;

  const PaginaDetallePresupuesto({
    super.key,
    required this.presupuestoId,
    required this.currentUserId,
  });

  @override
  State<PaginaDetallePresupuesto> createState() => _PaginaDetallePresupuestoState();
}

class _PaginaDetallePresupuestoState extends State<PaginaDetallePresupuesto> {
  bool _isLoading = false;
  final ChatService _chatService = ChatService(); // Instancia del servicio de chat

  @override
  void initState() {
    super.initState();
    Future.microtask(() => _marcarComoVistoSiCorresponde());
  }

  // --- LÓGICA DE NEGOCIO ---

  Future<void> _marcarComoVistoSiCorresponde() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('presupuestos').doc(widget.presupuestoId).get();
      if (!doc.exists) return;

      final presupuesto = PresupuestoDetallado.fromFirestore(doc);
      final esCliente = widget.currentUserId == presupuesto.userServicio;

      if (esCliente && presupuesto.estado == 'PENDIENTE') {
        await doc.reference.update({'estado': 'VISTO_POR_CLIENTE'});
        await _enviarNotificacion(
          presupuesto: presupuesto,
          destinatarioId: presupuesto.realizadoPor,
          titulo: 'Tu presupuesto fue visto 👀',
          mensaje: 'revisó tu presupuesto para "${presupuesto.titulo}".',
          tipo: 'presupuesto_visto',
        );
      }
    } catch (e) {
      debugPrint('Error al marcar como visto: $e');
    }
  }

  Future<void> _actualizarEstado(String nuevoEstado, PresupuestoDetallado presupuesto) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('presupuestos').doc(widget.presupuestoId).update({'estado': nuevoEstado});

      String titulo = '';
      String mensaje = '';
      final esCliente = widget.currentUserId == presupuesto.userServicio;
      final destinatarioId = esCliente ? presupuesto.realizadoPor : presupuesto.userServicio;

      switch (nuevoEstado) {
        case 'ACEPTADO_POR_CLIENTE':
          titulo = '¡Tu presupuesto fue aceptado! ✅';
          mensaje = 'aceptó tu presupuesto para "${presupuesto.titulo}". Por favor, confirmá el trabajo para comenzar.';
          break;
        case 'RECHAZADO_POR_CLIENTE':
          titulo = 'Un presupuesto fue rechazado ❌';
          mensaje = 'rechazó tu presupuesto para "${presupuesto.titulo}".';
          break;
        case 'CONFIRMADO_POR_PROVEEDOR':
          titulo = '¡Trabajo Confirmado! 🤝';
          mensaje = 'confirmó el trabajo para "${presupuesto.titulo}". El siguiente paso es formalizar el contrato.';
          break;
        case 'CANCELADO_POR_PROVEEDOR':
          titulo = 'El trabajo fue cancelado 😟';
          mensaje = 'no puede realizar el trabajo para "${presupuesto.titulo}" en este momento.';
          break;
      }

      if (titulo.isNotEmpty) {
        await _enviarNotificacion(
          presupuesto: presupuesto,
          destinatarioId: destinatarioId,
          titulo: titulo,
          mensaje: mensaje,
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al actualizar: $e'), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _mostrarDialogoCompromiso(PresupuestoDetallado presupuesto) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return DialogoCompromisoLegal(
          presupuesto: presupuesto,
          currentUserId: widget.currentUserId,
          onContratoGenerado: () => _generarContrato(presupuesto),
        );
      },
    );
  }

  Future<void> _generarContrato(PresupuestoDetallado presupuesto) async {
    final firestore = FirebaseFirestore.instance;
    final contratoRef = firestore.collection('contratos').doc();
    final proveedorRef = firestore.collection('usuarios').doc(presupuesto.realizadoPor);

    try {
      String numeroContrato = await firestore.runTransaction((transaction) async {
        final proveedorSnap = await transaction.get(proveedorRef);
        if (!proveedorSnap.exists) {
          throw Exception("El proveedor no existe!");
        }
        
        final ultimoNumero = proveedorSnap.data()?['contadorContratos'] ?? 0;
        final nuevoNumero = ultimoNumero + 1;
        transaction.update(proveedorRef, {'contadorContratos': nuevoNumero});

        final codigoCat = getCodigoCategoria(presupuesto.categoria);
        final codigoPais = getCodigoPais(presupuesto.pais);
        final numeroFormateado = nuevoNumero.toString().padLeft(3, '0');
        final idUnico = contratoRef.id.substring(contratoRef.id.length - 6).toUpperCase();

        return 'SER-$codigoCat-$numeroFormateado-$codigoPais-$idUnico';
      });

      final batch = firestore.batch();
      batch.set(contratoRef, {
        'numeroContrato': numeroContrato,
        'resumenCompromisos': {
          'montoTotal': presupuesto.totalFinal,
          'duracionEstimada': presupuesto.duracionEstimada,
          'garantia': '${presupuesto.garantia} días',
        },
        'historialEventos': [{
          'evento': 'Contrato Creado',
          'fecha': Timestamp.now(),
          'descripcion': 'Ambas partes aceptaron los términos.'
        }],
        'presupuestoId': widget.presupuestoId,
        'clienteId': presupuesto.userServicio,
        'proveedorId': presupuesto.realizadoPor,
        'titulo': presupuesto.titulo,
        'total': presupuesto.totalFinal,
        'detalles': presupuesto.detalles,
        'garantiaDias': presupuesto.garantia,
        'fechaInicioEstimada': presupuesto.fechaInicioEstimada,
        'hitosDePago': presupuesto.hitosDePago,
        'fechaConfirmacion': FieldValue.serverTimestamp(),
        'estadoTrabajo': 'POR_INICIAR',
      });

      final presupuestoRef = firestore.collection('presupuestos').doc(widget.presupuestoId);
      batch.update(presupuestoRef, {'estado': 'CONTRATO_GENERADO', 'contratoId': contratoRef.id});

      await batch.commit();

      final esCliente = widget.currentUserId == presupuesto.userServicio;
      await _enviarNotificacion(
        presupuesto: presupuesto,
        destinatarioId: esCliente ? presupuesto.realizadoPor : presupuesto.userServicio,
        titulo: '¡Contrato Generado! 🎉',
        mensaje: 'ha formalizado el acuerdo para "${presupuesto.titulo}".',
        tipo: 'nuevo_contrato',
      );

      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => PaginaDetalleContrato(contratoId: contratoRef.id, currentUserId: widget.currentUserId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al generar contrato: $e'), backgroundColor: Colors.red));
      }
    }
  }
  
  Future<void> _enviarNotificacion({
    required PresupuestoDetallado presupuesto,
    required String destinatarioId,
    required String titulo,
    required String mensaje,
    String tipo = 'actualizacion_presupuesto',
  }) async {
    if (destinatarioId == widget.currentUserId) return;
    try {
      final firestore = FirebaseFirestore.instance;
      final remitenteDoc = await firestore.collection('usuarios').doc(widget.currentUserId).get();
      final remitenteNombre = remitenteDoc.data()?['display_name'] ?? 'Un usuario';
      final mensajeCompleto = '$remitenteNombre $mensaje';
      await firestore.collection('notificaciones').add({
        'destinatarioId': destinatarioId,
        'remitenteId': widget.currentUserId,
        'titulo': titulo,
        'mensaje': mensajeCompleto,
        'tipo': tipo,
        'idReferencia': widget.presupuestoId,
        'idSolicitud': presupuesto.idSolicitud,
        'leida': false,
        'fechaCreacion': FieldValue.serverTimestamp(),
    });
    } catch (e) {
      debugPrint('Error al enviar notificación: $e');
    }
  }

  Future<void> _iniciarChat(PresupuestoDetallado presupuesto, String otroUsuarioId, String nombreOtroUsuario, String? fotoUrlOtroUsuario) async {
    setState(() => _isLoading = true);
    try {
      final chatId = await _chatService.getOrCreateChat(otroUsuarioId);
      
      // Creamos el mensaje automático solo si el usuario actual es el cliente
      if (widget.currentUserId == presupuesto.userServicio) {
        final mensajeAutomatico = 'Hola, ¿qué tal? Me gustaría hacerte una pregunta sobre el presupuesto: "${presupuesto.titulo}".';
    await _chatService.enviarMensaje(
  chatId: chatId,
  texto: mensajeAutomatico,
);
      }
      
      if (mounted) {
        Navigator.of(context).push(MaterialPageRoute(
          // ✅ CORRECCIÓN 2: Se usan los parámetros nombrados correctamente.
          builder: (context) => PaginaChatDetalle(
            chatId: chatId,
            nombreOtroUsuario: nombreOtroUsuario,
            fotoUrlOtroUsuario: fotoUrlOtroUsuario,
          ),
        ));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al iniciar chat: $e")));
    } finally {
      if(mounted) setState(() => _isLoading = false);
    }
    }
  

  // --- ACCIONES DE LOS BOTONES ---

  void _onAccept(PresupuestoDetallado p) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aceptar Presupuesto'),
        content: const Text('Se notificará al proveedor para que confirme el trabajo.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Sí, Aceptar')),
        ],
      ),
    );
    if (confirmar == true) {
      await _actualizarEstado('ACEPTADO_POR_CLIENTE', p);
    }
  }

  void _onReject(PresupuestoDetallado p) async {
    await _actualizarEstado('RECHAZADO_POR_CLIENTE', p);
  }

  void _onConfirmWork(PresupuestoDetallado p) async {
    await _actualizarEstado('CONFIRMADO_POR_PROVEEDOR', p);
      }

  void _onCancelWork(PresupuestoDetallado p) async {
    await _actualizarEstado('CANCELADO_POR_PROVEEDOR', p);
  }


  // --- CONSTRUCCIÓN DE LA UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalle del Presupuesto'),
        actions: [
          IconButton(icon: const Icon(Icons.share), onPressed: () {}),
          IconButton(icon: const Icon(Icons.picture_as_pdf), onPressed: () {}),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('presupuestos').doc(widget.presupuestoId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text('El presupuesto no fue encontrado.'));
          }

          final presupuesto = PresupuestoDetallado.fromFirestore(snapshot.data!);

          return Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
                  child: Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Theme.of(context).dividerColor.withAlpha(128)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(13),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        )
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildStatusChip(context, presupuesto.estado),
                        const SizedBox(height: 16),
                        _buildProviderInfo(context, presupuesto),
                        const SizedBox(height: 16),
                        _buildHeader(context, presupuesto),
                        const Divider(height: 32),
                        Text(presupuesto.titulo, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 24),
                        _buildItemsSection(context, 'Materiales', presupuesto.materiales),
                        _buildItemsSection(context, 'Mano de Obra', presupuesto.manoDeObra),
                        _buildItemsSection(context, 'Flete y Otros', presupuesto.fletes),
                        const Divider(height: 32),
                        _buildCondicionesSection(context, presupuesto),
                        const Divider(height: 32),
                        _buildTotalSummarySection(context, presupuesto),
                      ],
                    ),
                  ),
                ),
              ),
              if (_isLoading)
                const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
              else
                _buildActionArea(context, presupuesto),
            ],
          );
        },
      ),
    );
  }

  // --- WIDGETS AUXILIARES DE LA UI ---

  Widget _buildStatusChip(BuildContext context, String estado) {
    final (text, color, icon) = _getStatusInfo(estado);
    return Chip(
      avatar: Icon(icon, color: Colors.white, size: 18),
      label: Text(text, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
      backgroundColor: color,
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }

  (String, Color, IconData) _getStatusInfo(String estado) { 
    switch (estado) {
      case 'PENDIENTE':
        return ('Esperando respuesta', Colors.grey.shade600, Icons.hourglass_empty_rounded);
      case 'VISTO_POR_CLIENTE': 
        return ('Visto', Colors.blue, Icons.visibility_rounded);
      case 'ACEPTADO_POR_CLIENTE':
        return ('Aceptado por cliente', Colors.orange, Icons.check_circle_outline_rounded);
      case 'CONFIRMADO_POR_PROVEEDOR': 
        return ('Confirmado por proveedor', Colors.teal, Icons.thumb_up_alt_rounded);
      case 'RECHAZADO_POR_CLIENTE':
        return ('Rechazado por cliente', Colors.red, Icons.cancel_rounded);
      case 'CANCELADO_POR_PROVEEDOR':
        return ('Cancelado por proveedor', Colors.grey, Icons.do_not_disturb_on_rounded);
      case 'CONTRATO_GENERADO':
        return ('Trabajo Confirmado', Colors.green, Icons.handshake_rounded);
      default:
        return ('Desconocido', Colors.grey, Icons.help_outline_rounded);
    }
  }
Widget _buildActionArea(BuildContext context, PresupuestoDetallado presupuesto) {
  final esCliente = widget.currentUserId == presupuesto.userServicio;

  if (presupuesto.estado == 'CONTRATO_GENERADO') {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: FilledButton.icon(
        icon: const Icon(Icons.assignment_turned_in_outlined),
        label: const Text('Ver Contrato'),
        onPressed: () {
          if (presupuesto.contratoId != null) {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => PaginaDetalleContrato(
                contratoId: presupuesto.contratoId!,
                currentUserId: widget.currentUserId,
              ),
            ));
          }
        },
      ),
    );
  }

  if (presupuesto.estado == 'CONFIRMADO_POR_PROVEEDOR') {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: FilledButton.icon(
        icon: const Icon(Icons.gavel_rounded),
        label: const Text('Formalizar Contrato'),
        onPressed: () => _mostrarDialogoCompromiso(presupuesto),
      ),
    );
  }

  if (esCliente) {
    if (presupuesto.estado == 'PENDIENTE' || presupuesto.estado == 'VISTO_POR_CLIENTE') {
      return _buildButtonRow(
        onPrimary: () => _onAccept(presupuesto),
        primaryText: 'Aceptar Presupuesto',
        onSecondary: () => _onReject(presupuesto),
        secondaryText: 'Rechazar',
      );
    }
  } else { // Es Proveedor
    if (presupuesto.estado == 'ACEPTADO_POR_CLIENTE') {
      return _buildButtonRow(
        onPrimary: () => _onConfirmWork(presupuesto),
        primaryText: 'Confirmar Trabajo',
        onSecondary: () => _onCancelWork(presupuesto),
        secondaryText: 'No puedo hacerlo',
        primaryColor: Colors.green,
      );
    }
  }
  
  return const SizedBox.shrink(); // No mostrar nada en otros estados
}

  Widget _buildButtonRow({
    required VoidCallback onPrimary,
    required String primaryText,
    VoidCallback? onSecondary,
    String? secondaryText,
    Color? primaryColor,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Row(
        children: [
          if (onSecondary != null && secondaryText != null)
            Expanded(
              child: OutlinedButton(onPressed: onSecondary, child: Text(secondaryText)),
            ),
          if (onSecondary != null) const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              icon: const Icon(Icons.check),
              onPressed: onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 12),
                textStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              label: Text(primaryText),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderInfo(BuildContext context, PresupuestoDetallado presupuesto) {
    final esCliente = widget.currentUserId == presupuesto.userServicio;
    final otroUsuarioId = esCliente ? presupuesto.realizadoPor : presupuesto.userServicio;

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('usuarios').doc(presupuesto.realizadoPor).get(),
      builder: (context, snapshot) {
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const ListTile(
            leading: CircleAvatar(radius: 24, child: Icon(Icons.person_off)),
            title: Text('Proveedor no disponible'),
          );
        }

        final userData = snapshot.data!.data() as Map<String, dynamic>;
        final nombre = userData['display_name'] ?? 'Proveedor';
        final fotoUrl = userData['photo_url'];
        
        return ListTile(
          onTap: () => _iniciarChat(presupuesto, otroUsuarioId, nombre, fotoUrl),
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            radius: 24,
            backgroundImage: (fotoUrl != null && fotoUrl.isNotEmpty)
                ? NetworkImage(fotoUrl)
                : null,
            child: (fotoUrl == null || fotoUrl.isEmpty)
                ? const Icon(Icons.person)
                : null,
          ),
          title: Text(nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Proveedor del Servicio'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              RatingStars(
                rating: (userData['rating'] ?? 0.0).toDouble(),
                ratingCount: userData['ratingCount'] ?? 0,
              ),
              const SizedBox(width: 8),
              Icon(Icons.chat_bubble_outline_rounded, color: Theme.of(context).colorScheme.primary),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, PresupuestoDetallado presupuesto) {
    final fecha = DateFormat('dd/MM/yyyy').format(presupuesto.fechaCreacion.toDate());
    final numero = presupuesto.numeroPresupuesto?.toString().padLeft(4, '0') ?? 'N/A';
    return Card(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildHeaderColumn("Presupuesto Nº", numero),
            _buildHeaderColumn("Fecha", fecha),
            _buildHeaderColumn("Válido por", presupuesto.validezOferta),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderColumn(String label, String value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        Text(value, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildItemsSection(BuildContext context, String title, List<Map<String, dynamic>> items) {
    if (items.isEmpty) return const SizedBox.shrink();
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...items.map((item) {
          return ListTile(
            dense: true,
            visualDensity: VisualDensity.compact,
            contentPadding: const EdgeInsets.symmetric(horizontal: 4.0),
            title: Text(item['descripcion'] ?? ''),
            trailing: Text(formatter.format(item['costo'] ?? item['precioTotal'] ?? 0)),
          );
        }),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildCondicionesSection(BuildContext context, PresupuestoDetallado presupuesto) {
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Condiciones y Detalles", style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Card(
          elevation: 0,
          color: Theme.of(context).colorScheme.surfaceContainer,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildInfoRow("Garantía:", "${presupuesto.garantia} días"),
                _buildInfoRow("Tiempo de Ejecución:", presupuesto.duracionEstimada),
                _buildInfoRow("Fecha de Inicio Estimada:", presupuesto.fechaInicioEstimada),
                if (presupuesto.detalles.isNotEmpty)
                  _buildInfoRow("Detalles Adicionales:", presupuesto.detalles),
                if (presupuesto.hitosDePago.isNotEmpty) ...[
                  const Divider(height: 24),
                  _buildInfoRow("Plan de Pagos:", ""),
                  ...presupuesto.hitosDePago.map((hito) => Padding(
                        padding: const EdgeInsets.only(left: 16, top: 4),
                        child: _buildInfoRow("· ${hito['descripcion']}", formatter.format(hito['monto'])),
                      )),
                ]
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(width: 8),
          // ✅ CORRECCIÓN: Envolvemos el valor en un Expanded para que el texto se ajuste.
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.start, // Alineamos al inicio para textos largos.
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalSummarySection(BuildContext context, PresupuestoDetallado presupuesto) {
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    final iva = (presupuesto.subtotal + presupuesto.comision) * 0.21;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            _buildSummaryRow('Subtotal', formatter.format(presupuesto.subtotal)),
            _buildSummaryRow('Comisión Servicly', formatter.format(presupuesto.comision)),
            if (presupuesto.incluyeIva) _buildSummaryRow('IVA (21%)', formatter.format(iva)),
            const Divider(height: 20),
            _buildSummaryRow('TOTAL', formatter.format(presupuesto.totalFinal), isTotal: true),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String title, String amount, {bool isTotal = false}) {
    final theme = Theme.of(context);
    final style = TextStyle(
      fontSize: isTotal ? 20 : 16,
      fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
      color: isTotal ? theme.colorScheme.primary : null,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(title, style: style), Text(amount, style: style)],
      ),
    );
  }
}
class DialogoCompromisoLegal extends StatefulWidget {
  final PresupuestoDetallado presupuesto;
  final String currentUserId;
  // Pasamos la función de generar contrato como un callback
  final Future<void> Function() onContratoGenerado; 

  const DialogoCompromisoLegal({
    super.key,
    required this.presupuesto,
    required this.currentUserId,
    required this.onContratoGenerado,
  });

  @override
  State<DialogoCompromisoLegal> createState() => _DialogoCompromisoLegalState();
}

class _DialogoCompromisoLegalState extends State<DialogoCompromisoLegal> {
  bool _aceptoMisTerminos = false;
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final esCliente = widget.currentUserId == widget.presupuesto.userServicio;
    
    // Verificamos si la otra parte ya aceptó para mostrarlo en la UI
    final clienteYaAcepto = widget.presupuesto.clienteAceptoCompromiso;
    final proveedorYaAcepto = widget.presupuesto.proveedorAceptoCompromiso;

    return AlertDialog(
      title: const Text('Acuerdo de Compromiso'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Para generar el contrato, ambas partes deben aceptar explícitamente sus responsabilidades.',
              style: TextStyle(fontSize: 14),
            ),
            const Divider(height: 24),

            // --- Compromiso del Proveedor ---
            Text('Proveedor:', style: Theme.of(context).textTheme.labelLarge),
            CheckboxListTile(
              value: esCliente ? proveedorYaAcepto : _aceptoMisTerminos,
              // El cliente no puede marcar por el proveedor
              onChanged: esCliente ? null : (value) {
                setState(() {
                  _aceptoMisTerminos = value ?? false;
                });
              },
              title: const Text(
                'Me comprometo a cumplir con los plazos, precios y garantía ofrecidos.',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            
            const SizedBox(height: 16),

            // --- Compromiso del Cliente ---
            Text('Cliente:', style: Theme.of(context).textTheme.labelLarge),
            CheckboxListTile(
              value: !esCliente ? clienteYaAcepto : _aceptoMisTerminos,
              // El proveedor no puede marcar por el cliente
              onChanged: !esCliente ? null : (value) {
                setState(() {
                  _aceptoMisTerminos = value ?? false;
                });
              },
              title: const Text(
                'Me comprometo a realizar los pagos en tiempo y forma.',
                style: TextStyle(fontSize: 12),
              ),
              controlAffinity: ListTileControlAffinity.leading,
              contentPadding: EdgeInsets.zero,
            ),
            
            const Divider(height: 24),

            // --- Términos Generales ---
            const Text(
              'Ambas partes aceptan la mediación de Servicly en caso de disputas y entienden que el incumplimiento puede llevar a sanciones.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          // El botón solo se activa si el usuario ha marcado su propio checkbox
          onPressed: _aceptoMisTerminos && !_isLoading ? _handleAceptarCompromiso : null,
          child: _isLoading 
              ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Aceptar y Confirmar'),
        ),
      ],
    );
  }

  // ✅ --- FUNCIÓN CORREGIDA --- ✅
  Future<void> _handleAceptarCompromiso() async {
    setState(() => _isLoading = true);

    final esCliente = widget.currentUserId == widget.presupuesto.userServicio;
    final presupuestoRef = FirebaseFirestore.instance.collection('presupuestos').doc(widget.presupuesto.id);
    
    try {
      // 1. Actualiza el estado de aceptación del usuario actual
      final updateData = esCliente 
          ? {'clienteAceptoCompromiso': true} 
          : {'proveedorAceptoCompromiso': true};
      await presupuestoRef.update(updateData);

      // 2. VUELVE A LEER los datos más recientes desde Firestore.
      final docActualizado = await presupuestoRef.get();
      final datosActualizados = PresupuestoDetallado.fromFirestore(docActualizado);

      // 3. AHORA SÍ, comprueba si AMBOS han aceptado usando los datos frescos.
      if (datosActualizados.clienteAceptoCompromiso && datosActualizados.proveedorAceptoCompromiso) {
        // ¡Ambos aceptaron! Generar contrato
        await widget.onContratoGenerado();
      }
      
      // Si llegamos aquí, la operación fue exitosa.
      // Si el contrato no se generó aún, simplemente se cierra el diálogo.
      if (mounted) Navigator.of(context).pop();

    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
        );
      }
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }
}
