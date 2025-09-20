import 'package:flutter/material.dart';
import 'package:servicly_app/widgets/app_background.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// --- MEJORA: Se convierte a StatefulWidget para manejar el estado ---
class PlanesPage extends StatefulWidget {
  const PlanesPage({super.key});

  @override
  State<PlanesPage> createState() => _PlanesPageState();
}

class _PlanesPageState extends State<PlanesPage> {
  String? _currentPlan;
  bool _isLoading = true;
  bool _isUpdating = false; // Estado para el proceso de actualización

  @override
  void initState() {
    super.initState();
    _loadUserPlan();
  }

  Future<void> _loadUserPlan() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          setState(() {
            _currentPlan = userDoc.data()?['plan'] as String? ?? 'Free';
          });
        }
      } catch (e) {
        debugPrint("Error cargando el plan del usuario: $e");
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // --- MEJORA: Nueva función para manejar la selección de un plan ---
  Future<void> _seleccionarPlan(String nuevoPlan) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isUpdating = true);

    try {
      // Actualizamos el documento del usuario en Firestore
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).update({
        'plan': nuevoPlan,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('¡Felicidades! Tu plan ahora es $nuevoPlan.'),
            backgroundColor: Colors.green,
          ),
        );
        // Regresamos a la pantalla anterior
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al actualizar el plan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isUpdating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final List<Map<String, dynamic>> planesData = [
      { 'nombre': 'Premium', 'precio': 16.99, 'esRecomendado': true, 'beneficios': ['Todos los beneficios de Standard.', 'Sin comisiones por obra ejecutada.', 'Posicionamiento destacado en búsquedas.', 'Acceso prioritario a nuevas funciones.', 'Soporte premium personalizado.' ]},
      { 'nombre': 'Standard', 'precio': 13.99, 'esRecomendado': false, 'beneficios': ['Todos los beneficios de Free.', 'Ver reseñas y calificaciones.', 'Acceso a promociones exclusivas.', '5 contrataciones sin comisión.', 'Soporte por chat.' ]},
      { 'nombre': 'Free', 'precio': 0.0, 'esRecomendado': false, 'beneficios': ['Acceso básico a la plataforma.', 'Búsqueda de servicios y proveedores.', 'Gestión de citas y contratos.', 'Comisión del 5% por obra ejecutada.' ]},
    ];

    return AppBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: const Text('Nuestros Planes'),
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: colorScheme.onSurface,
        ),
        body: Stack( // Usamos Stack para mostrar el indicador de carga encima
          children: [
            SafeArea(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : ListView(
                      padding: const EdgeInsets.all(16.0),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
                          child: Column(
                            children: [
                              Text('Elige el plan perfecto para ti', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                              const SizedBox(height: 8),
                              Text('Desbloquea más beneficios y lleva tu negocio al siguiente nivel.', style: theme.textTheme.bodyLarge?.copyWith(color: colorScheme.onSurface.withAlpha(200)), textAlign: TextAlign.center),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        ...planesData.map((plan) => Padding(
                              padding: const EdgeInsets.only(bottom: 16.0),
                              child: _PlanCard(
                                nombre: plan['nombre'],
                                precio: plan['precio'],
                                beneficios: plan['beneficios'],
                                esRecomendado: plan['esRecomendado'],
                                esPlanActual: _currentPlan == plan['nombre'],
                                // --- MEJORA: El botón ahora llama a la función _seleccionarPlan ---
                                onTap: () => _seleccionarPlan(plan['nombre']),
                              ),
                            )),
                      ],
                    ),
            ),
            if (_isUpdating) // Indicador de carga que cubre toda la pantalla
              Container(
                color: Colors.black.withOpacity(0.5),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final String nombre;
  final double precio;
  final List<String> beneficios;
  final VoidCallback? onTap;
  final bool esRecomendado;
  final bool esPlanActual;

  const _PlanCard({
    required this.nombre,
    required this.precio,
    required this.beneficios,
    this.onTap,
    this.esRecomendado = false,
    this.esPlanActual = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final formatter = NumberFormat.currency(locale: locale, symbol: '\$');
    final cardColor = esRecomendado ? null : colorScheme.surfaceContainer;
    final textColor = esRecomendado ? colorScheme.onPrimary : colorScheme.onSurface;
    final priceColor = esRecomendado ? colorScheme.onPrimary : colorScheme.primary;
    final iconColor = esRecomendado ? colorScheme.onPrimary : colorScheme.primary;
    final bool isFreePlan = precio == 0.0;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: esRecomendado ? 8.0 : 1.0,
      shadowColor: esRecomendado ? colorScheme.primary.withAlpha(100) : Colors.black.withAlpha(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: esPlanActual ? colorScheme.tertiary : (esRecomendado ? colorScheme.primary : colorScheme.outline.withAlpha(80)),
          width: esPlanActual ? 3 : (esRecomendado ? 2 : 1),
        ),
      ),
      child: Container(
        decoration: esRecomendado
            ? BoxDecoration(
                gradient: LinearGradient(
                  colors: [colorScheme.primary, colorScheme.secondary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              )
            : BoxDecoration(color: cardColor),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(nombre, style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold, color: textColor)),
                  const SizedBox(height: 8),
                  Text(isFreePlan ? 'Gratis' : '${formatter.format(precio)} / mes', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: priceColor)),
                  Divider(height: 32, color: textColor.withAlpha(50)),
                  ...beneficios.map((b) => _BenefitItem(text: b, iconColor: iconColor, textColor: textColor)),
                  if (!isFreePlan) ...[
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: esPlanActual ? null : onTap,
                      style: esRecomendado
                          ? ElevatedButton.styleFrom(
                              backgroundColor: colorScheme.onPrimary,
                              foregroundColor: colorScheme.primary,
                              disabledBackgroundColor: colorScheme.onPrimary.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            )
                          : FilledButton.styleFrom(
                              disabledBackgroundColor: colorScheme.primary.withOpacity(0.5),
                              padding: const EdgeInsets.symmetric(vertical: 16),
                            ),
                      child: Text(esPlanActual ? 'Tu Plan Actual' : 'Elegir este plan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    ),
                  ],
                ],
              ),
            ),
            if (esRecomendado && !esPlanActual) // No mostrar si es el plan actual
              Positioned(
                top: 0, right: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: colorScheme.tertiaryContainer,
                    borderRadius: const BorderRadius.only(topRight: Radius.circular(18), bottomLeft: Radius.circular(20)),
                  ),
                  child: Text('Más Popular', style: theme.textTheme.labelLarge?.copyWith(color: colorScheme.onTertiaryContainer, fontWeight: FontWeight.bold)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BenefitItem extends StatelessWidget {
  final String text;
  final Color iconColor;
  final Color textColor;

  const _BenefitItem({required this.text, required this.iconColor, required this.textColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: textColor, height: 1.4))),
        ],
      ),
    );
  }
}