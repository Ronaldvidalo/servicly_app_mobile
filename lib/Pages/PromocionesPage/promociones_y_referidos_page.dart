// lib/pages/promociones_y_referidos_page.dart

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';

class PromocionesYReferidosPage extends StatefulWidget {
  const PromocionesYReferidosPage({super.key});

  @override
  State<PromocionesYReferidosPage> createState() => _PromocionesYReferidosPageState();
}

class _PromocionesYReferidosPageState extends State<PromocionesYReferidosPage> {
  final String? _userId = FirebaseAuth.instance.currentUser?.uid;
   final bool _isCreatingLink = false;
  
  /// Genera y comparte el link de referido.
  Future<void> _compartirLink() async {
    if (_userId == null) return;

    // Ahora el link es una URL simple y predecible
    final String link = "https://serviclyapp-44213.web.app/refer?by=$_userId";
    final String texto = "¡Hola! Te recomiendo Servicly para encontrar profesionales de confianza. Usá mi link para registrarte: $link";
    
    await Share.share(texto);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Promociones y Referidos'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          // ... aquí irían tus otras promos y sorteos ...
          const SizedBox(height: 24),
          _buildReferidosCard(),
        ],
      ),
    );
  }

  Widget _buildReferidosCard() {
  return Card(
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(color: Theme.of(context).dividerColor),
    ),
    child: Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        children: [
          const Icon(Icons.group_add_outlined, size: 48, color: Colors.blue),
          const SizedBox(height: 16),
          Text(
            '¡Invitá y Gana!',
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'Compartí tu link de referido con amigos. Cuando se registren, ¡sumarás puntos para futuros premios!',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // --- WIDGET CORREGIDO Y MÁS SEGURO ---
          StreamBuilder<DocumentSnapshot>(
            stream: FirebaseFirestore.instance.collection('usuarios').doc(_userId).snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData || snapshot.data?.data() == null) {
                // Muestra un placeholder mientras carga o si no hay datos
                return const Text('Cargando referidos...');
              }

              // Hacemos un cast seguro a un mapa
              final data = snapshot.data!.data() as Map<String, dynamic>;
              
              // Verificamos si el campo existe antes de intentar leerlo
              final count = data.containsKey('referralCount') ? data['referralCount'] : 0;

              return Text(
                'Has referido a $count personas',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              );
            }
          ),
          // --- FIN DEL WIDGET CORREGIDO ---

          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _isCreatingLink ? null : _compartirLink,
            icon: _isCreatingLink 
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) 
              : const Icon(Icons.share),
            label: const Text('Compartir mi Link'),
          ),
        ],
      ),
    ),
  );
}
}