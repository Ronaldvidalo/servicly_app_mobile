import 'package:flutter/material.dart';

class ProcesarPagoPage extends StatefulWidget {
  final double amount;
  final String paymentMethod;

  const ProcesarPagoPage({
    super.key,
    required this.amount,
    required this.paymentMethod,
  });

  @override
  State<ProcesarPagoPage> createState() => _ProcesarPagoPageState();
}

class _ProcesarPagoPageState extends State<ProcesarPagoPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  void _procesarPago() {
    // Aquí iría la lógica para obtener el token del SDK de pago
    // y enviarlo a tu backend para procesar el cargo.
    
    // Simulación de carga
    setState(() => _isLoading = true);
    Future.delayed(const Duration(seconds: 2), () {
      setState(() => _isLoading = false);
      // Simulación de éxito
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Pago realizado con éxito!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop(); // Vuelve a la página anterior
    });
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Pagar con ${widget.paymentMethod}'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Resumen del Monto ---
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total a Pagar:',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    '\$${widget.amount.toStringAsFixed(2)}',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
                  ),
                ],
              ),
              const Divider(height: 32),
              
              // --- Placeholder para el Componente de UI del SDK ---
              Text(
                'Datos de la Tarjeta',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  border: Border.all(color: Colors.grey.shade300, width: 0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Text(
                      'Aquí se integrará el formulario de pago seguro de ${widget.paymentMethod}.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    const Icon(Icons.credit_card, size: 40, color: Colors.grey),
                  ],
                ),
              ),
              const SizedBox(height: 32),

              // --- Botón de Confirmación ---
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _procesarPago,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: _isLoading 
                      ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white))
                      : const Text('Confirmar Pago'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
