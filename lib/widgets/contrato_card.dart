// lib/widgets/contrato_card.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/models/contrato_model.dart';
import 'package:servicly_app/pages/contrato/pagina_detalle_contrato.dart';

class ContratoCard extends StatefulWidget {
  final ContratoResumen contrato;
  final String currentUserId;

  const ContratoCard({
    super.key,
    required this.contrato,
    required this.currentUserId,
  });

  @override
  State<ContratoCard> createState() => _ContratoCardState();
}

class _ContratoCardState extends State<ContratoCard> {
  Map<String, dynamic>? _otraParteData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchOtraParteData();
  }

  /// Busca en Firestore los datos del otro usuario involucrado en el contrato.
  Future<void> _fetchOtraParteData() async {
    final esCliente = widget.currentUserId == widget.contrato.clienteId;
    final otraParteId = esCliente ? widget.contrato.proveedorId : widget.contrato.clienteId;

    if (otraParteId.isEmpty) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(otraParteId).get();
      if (userDoc.exists && mounted) {
        setState(() {
          _otraParteData = userDoc.data();
        });
      }
    } catch (e) {
      debugPrint("Error cargando datos de la otra parte: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Navega a la pantalla de detalle del contrato.
  void _navegarADetalle() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PaginaDetalleContrato(
          contratoId: widget.contrato.id,
          currentUserId: widget.currentUserId,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final esCliente = widget.currentUserId == widget.contrato.clienteId;
    final formatadorMoneda = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    final nombreOtraParte = _otraParteData?['display_name'] ?? 'Cargando...';
    final fotoUrlOtraParte = _otraParteData?['photo_url'] ?? '';
    final rolOtraParte = esCliente ? 'Proveedor' : 'Cliente';

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Título corregido
            Text(
              'Contrato: ${widget.contrato.titulo.replaceAll('Presupuesto para: ', '')}',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            
            // Layout de usuario mejorado
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (_isLoading)
                  const CircleAvatar(radius: 22, backgroundColor: Colors.black26)
                else
                  CircleAvatar(
                    radius: 22,
                    backgroundImage: fotoUrlOtraParte.isNotEmpty ? NetworkImage(fotoUrlOtraParte) : null,
                    child: fotoUrlOtraParte.isEmpty ? const Icon(Icons.person, size: 24) : null,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rolOtraParte,
                        style: theme.textTheme.labelSmall,
                      ),
                      Text(
                        nombreOtraParte,
                        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Text(
                  formatadorMoneda.format(widget.contrato.total),
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Fila inferior con estado y navegación precisa
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  avatar: Icon(Icons.play_circle_outline_rounded, size: 18, color: Colors.blue.shade700),
                  label: Text(widget.contrato.estadoTrabajo.replaceAll('_', ' ')),
                  backgroundColor: Colors.blue.withOpacity(0.1),
                  side: BorderSide.none,
                ),
                TextButton(
                  onPressed: _navegarADetalle,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Ver seguimiento'),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_forward_ios, size: 14),
                    ],
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }
}