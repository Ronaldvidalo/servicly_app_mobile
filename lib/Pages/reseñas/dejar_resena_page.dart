import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DejarResenaPage extends StatefulWidget {
  // El ID del proveedor que está siendo calificado.
  final String proveedorId;
  // El ID del trabajo/presupuesto para asociar la reseña.
  final String presupuestoId;

  const DejarResenaPage({
    super.key,
    required this.proveedorId,
    required this.presupuestoId,
  });

  @override
  State<DejarResenaPage> createState() => _DejarResenaPageState();
}

class _DejarResenaPageState extends State<DejarResenaPage> {
  final _commentController = TextEditingController();
  double _rating = 0.0;
  bool _isLoading = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (_rating == 0.0) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, selecciona una calificación de estrellas.')),
      );
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Debes iniciar sesión para dejar una reseña.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      // --- CORRECCIÓN: Se cambia 'reseñas' a 'resenas' para coincidir con la Cloud Function ---
      final resenaRef = FirebaseFirestore.instance
          .collection('usuarios')
          .doc(widget.proveedorId)
          .collection('resenas') // Se usa el nombre sin 'ñ'
          .doc();

      final newReview = {
        'rating': _rating,
        'comment': _commentController.text.trim(),
        'authorId': currentUser.uid,
        'authorName': currentUser.displayName ?? 'Anónimo',
        'presupuestoId': widget.presupuestoId,
        'timestamp': FieldValue.serverTimestamp(),
      };

      await resenaRef.set(newReview);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Gracias por tu reseña!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al enviar la reseña: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dejar una Reseña'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '¿Qué te pareció el servicio?',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Selecciona una calificación y deja un comentario sobre tu experiencia.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Center(
              child: _StarRating(
                rating: _rating,
                onRatingChanged: (rating) => setState(() => _rating = rating),
              ),
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _commentController,
              decoration: const InputDecoration(
                labelText: 'Tu comentario (opcional)',
                hintText: 'Describe tu experiencia con el proveedor...',
                border: OutlineInputBorder(),
              ),
              maxLines: 5,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitReview,
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Text('Enviar Reseña'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- WIDGET PARA LAS ESTRELLAS DE CALIFICACIÓN ---
class _StarRating extends StatelessWidget {
  final double rating;
  final Function(double) onRatingChanged;

  const _StarRating({required this.rating, required this.onRatingChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        return IconButton(
          onPressed: () => onRatingChanged(index + 1.0),
          icon: Icon(
            index < rating ? Icons.star : Icons.star_border,
            color: Colors.amber.shade600,
            size: 40,
          ),
        );
      }),
    );
  }
}
