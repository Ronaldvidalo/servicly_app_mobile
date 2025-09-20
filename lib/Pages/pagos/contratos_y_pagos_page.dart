import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:servicly_app/pages/pagos/verificacion_page.dart';

class ContratosYPagosPage extends StatefulWidget {
  const ContratosYPagosPage({super.key});

  @override
  State<ContratosYPagosPage> createState() => _ContratosYPagosPageState();
}

class _ContratosYPagosPageState extends State<ContratosYPagosPage> {
  bool _isLoading = false;

  // --- Lógica para llamar a la Cloud Function y vincular la cuenta ---
  Future<void> _vincularCuenta() async {
    setState(() => _isLoading = true);

    try {
      // Llama a la Cloud Function que creamos
      final functions = FirebaseFunctions.instanceFor(region: "us-central1");
      final HttpsCallable callable = functions.httpsCallable('createStripeAccountLink');
      
      final result = await callable.call();
      final String url = result.data['url'];

      // Abre el enlace de Stripe en el navegador
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'No se pudo abrir el enlace: $url';
      }

    } on FirebaseFunctionsException catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error de Firebase: ${e.message}')),
        );
      }
    } catch (e) {
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ocurrió un error: $e')),
        );
      }
    } finally {
      if(mounted) {
        setState(() => _isLoading = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;

    if (currentUserId == null) {
      return const Scaffold(
        body: Center(child: Text("Error: Usuario no autenticado.")),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Billetera'),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('usuarios')
            .doc(currentUserId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("No se pudo cargar tu perfil."));
          }

          final userData = snapshot.data!.data()!;
          final bool esVerificado = userData['esVerificado'] ?? false;
          // Se comprueba si el usuario ya tiene un ID de cuenta de Stripe
          final bool tieneStripeVinculado = (userData['stripeAccountId'] as String?)?.isNotEmpty ?? false;
          final String estadoVerificacion = userData['estadoVerificacion'] ?? 'no_iniciado';

          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (tieneStripeVinculado)
                    _buildStatusCard(
                      context,
                      icon: Icons.check_circle,
                      iconColor: Colors.green,
                      title: '¡Cuenta Vinculada!',
                      subtitle: 'Ya puedes recibir pagos de forma segura a través de Stripe.',
                      buttonText: 'Gestionar Cuenta',
                      onPressed: () {
                        // TODO: Lógica para ir al dashboard de Stripe Express
                      },
                    )
                  else if (esVerificado)
                    _buildStatusCard(
                      context,
                      icon: Icons.credit_card,
                      iconColor: Theme.of(context).colorScheme.primary,
                      title: '¡Estás verificado!',
                      subtitle: 'El siguiente paso es vincular tu cuenta de Stripe para poder recibir pagos por tus servicios.',
                      buttonText: 'Vincular con Stripe',
                      // Se añade el estado de carga al botón
                      onPressed: _isLoading ? null : _vincularCuenta,
                    )
                  else if (estadoVerificacion == 'en_revision')
                     _buildStatusCard(
                      context,
                      icon: Icons.hourglass_top,
                      iconColor: Colors.blue,
                      title: 'Verificación en Proceso',
                      subtitle: 'Hemos recibido tus documentos y lo estamos revisando. Te notificaremos cuando el proceso haya finalizado.',
                      buttonText: 'En Revisión',
                      onPressed: null,
                    )
                  else
                    _buildStatusCard(
                      context,
                      icon: Icons.shield_outlined,
                      iconColor: Colors.orange.shade700,
                      title: 'Verificación Requerida',
                      subtitle: 'Para poder recibir pagos, primero necesitamos verificar tu identidad. Este paso es crucial para la seguridad de todos en la plataforma.',
                      buttonText: 'Iniciar Verificación',
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const VerificacionPage()));
                      },
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusCard(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String buttonText,
    required VoidCallback? onPressed,
  }) {
    return Card(
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Icon(icon, size: 60, color: iconColor),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: onPressed,
              child: _isLoading ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white)) : Text(buttonText),
            ),
          ],
        ),
      ),
    );
  }
}
