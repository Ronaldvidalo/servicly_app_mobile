import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:servicly_app/pages/presupuesto/mis_presupuestos_page.dart';
import 'package:share_plus/share_plus.dart';
import 'package:servicly_app/widgets/app_background.dart';

// Modelo para los datos de la billetera (sin cambios)
class _BilleteraData {
  final bool isVerified;
  final String userPlan;
  final String referralCode;
  _BilleteraData({required this.isVerified, required this.userPlan, required this.referralCode});
}

class BilleteraPage extends StatefulWidget {
  const BilleteraPage({super.key});
  @override
  State<BilleteraPage> createState() => _BilleteraPageState();
}

class _BilleteraPageState extends State<BilleteraPage> {
  // --- Lógica de negocio (sin cambios) ---
  late Future<_BilleteraData> _billeteraDataFuture;
  final bool _isPaying = false;
  final _promoCodeController = TextEditingController();

  // Datos de simulación
  final double _manoDeObraFacturada = 12500.00;
  final double _materialesFacturados = 3250.00;
  double get _totalFacturado => _manoDeObraFacturada + _materialesFacturados;
  double get _comisionAPagar => _manoDeObraFacturada * 0.05;

  @override
  void initState() {
    super.initState();
    _billeteraDataFuture = _fetchData();
  }

  Future<_BilleteraData> _fetchData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('Usuario no autenticado.');
    }
    try {
      final docRef = FirebaseFirestore.instance.collection('usuarios').doc(user.uid);
      final doc = await docRef.get().timeout(const Duration(seconds: 10));
      if (doc.exists) {
        return _BilleteraData(
          isVerified: doc.data()?['esVerificado'] ?? false,
          userPlan: doc.data()?['plan'] ?? 'Free',
          referralCode: doc.data()?['referralCode'] ?? 'GENERANDO...',
        );
      } else {
        return _BilleteraData(isVerified: false, userPlan: 'Free', referralCode: 'N/A');
      }
    } on TimeoutException {
      throw Exception('La conexión tardó demasiado en responder.');
    } on FirebaseException catch (e) {
      throw Exception('Error de Firebase: ${e.message}');
    } catch (e) {
      throw Exception('Ocurrió un error inesperado al cargar.');
    }
  }

  @override
  void dispose() {
    _promoCodeController.dispose();
    super.dispose();
  }

  Future<void> _iniciarPagoMercadoPago() async { /* ... tu lógica de pago ... */ }
  void _showPaymentOptions(BuildContext context) { /* ... tu lógica de opciones de pago ... */ }

  // --- UI Reconstruida ---
  @override
  Widget build(BuildContext context) {
    return AppBackground( // Mantenemos el fondo degradado de la app
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: FutureBuilder<_BilleteraData>(
            future: _billeteraDataFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Text('Error al cargar: ${snapshot.error}', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  )
                );
              }
              if (snapshot.hasData) {
                final data = snapshot.data!;
                return ListView(
                  padding: const EdgeInsets.all(16.0),
                  children: [
                    _buildHeader(context),
                    const SizedBox(height: 24),
                    _buildFinancialSummaryCard(context),
                    const SizedBox(height: 24),
                    _buildActionButtons(context),
                    const SizedBox(height: 32),

                    if (!data.isVerified) ...[
                      _buildNotVerifiedCard(context),
                      const SizedBox(height: 24),
                    ],
                    if (data.userPlan == 'Free' && data.isVerified) ...[
                      _buildCommissionCard(context),
                      const SizedBox(height: 24),
                    ],
                    
                    _buildSectionTitle(context, 'Últimos Movimientos'),
                    const SizedBox(height: 16),
                    _buildTransactionHistory(context),
                    const SizedBox(height: 24),
                    
                    _buildSectionTitle(context, 'Mi Oficina'),
                    const SizedBox(height: 16),
                    _buildDashboardCard(context),
                    const SizedBox(height: 24),

                    _buildSectionTitle(context, 'Métodos de Cobro'),
                    const SizedBox(height: 16),
                    _buildPaymentLinkCard(
                      context,
                      logoAsset: 'assets/images/mercadopago.png',
                      name: 'Mercado Pago',
                      isEnabled: data.isVerified,
                      onTap: () {}, // Tu lógica aquí
                    ),
                    const SizedBox(height: 24),

                    _buildSectionTitle(context, 'Promociones'),
                    const SizedBox(height: 16),
                    _buildPromoAndReferralCard(context, data.referralCode),
                    const SizedBox(height: 24),
                  ],
                );
              }
              return const Center(child: Text('Iniciando...'));
            },
          ),
        ),
      ),
    );
  }

  // --- Widgets Auxiliares Rediseñados ---

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Mi Billetera',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: Icon(Icons.notifications_none_outlined, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () {
              // Lógica para notificaciones
            },
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialSummaryCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');

    return Container(
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            colorScheme.primary,
            colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Facturado este mes',
            style: theme.textTheme.titleMedium?.copyWith(color: colorScheme.onPrimary.withOpacity(0.8)),
          ),
          const SizedBox(height: 8),
          Text(
            formatter.format(_totalFacturado),
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onPrimary,
              letterSpacing: 1.2,
            ),
          ),
          const Divider(height: 40, color: Colors.white24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Mano de Obra', style: TextStyle(color: colorScheme.onPrimary)),
              Text(formatter.format(_manoDeObraFacturada), style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Materiales', style: TextStyle(color: colorScheme.onPrimary)),
              Text(formatter.format(_materialesFacturados), style: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      children: [
        _buildActionItem(context, icon: Icons.send_outlined, label: 'Enviar'),
        _buildActionItem(context, icon: Icons.call_received, label: 'Recibir'),
        _buildActionItem(context, icon: Icons.add_card_outlined, label: 'Recargar'),
        _buildActionItem(context, icon: Icons.more_horiz, label: 'Más'),
      ],
    );
  }

  Widget _buildActionItem(BuildContext context, {required IconData icon, required String label}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Material(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {},
            child: SizedBox(
              width: 64,
              height: 64,
              child: Icon(icon, color: colorScheme.primary, size: 30),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.bodyMedium),
      ],
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
    );
  }

  Widget _buildTransactionHistory(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          _buildTransactionItem(context, 'Pago recibido por Plomería', '+\$2,500.00', true),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildTransactionItem(context, 'Comisión de Servicly', '-\$125.00', false),
          const Divider(height: 1, indent: 20, endIndent: 20),
          _buildTransactionItem(context, 'Pago recibido por Electricidad', '+\$4,000.00', true),
        ],
      ),
    );
  }

  Widget _buildTransactionItem(BuildContext context, String description, String amount, bool isIncome) {
    final theme = Theme.of(context);
    // Usando el color primario para ingresos y error para egresos
    final color = isIncome ? theme.colorScheme.primary : theme.colorScheme.error;
    final icon = isIncome ? Icons.trending_up_rounded : Icons.trending_down_rounded;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      leading: CircleAvatar(
        backgroundColor: color.withOpacity(0.1),
        child: Icon(icon, color: color),
      ),
      title: Text(description, style: theme.textTheme.bodyLarge),
      subtitle: Text('18 de Julio, 2025', style: theme.textTheme.bodySmall),
      trailing: Text(
        amount,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }

  Widget _buildNotVerifiedCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: colorScheme.tertiaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(Icons.gpp_maybe_outlined, color: colorScheme.onTertiaryContainer, size: 44),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Verifica tu cuenta', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onTertiaryContainer)),
                  const SizedBox(height: 4),
                  Text('Completa la verificación para recibir pagos.', style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.onTertiaryContainer)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {},
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.tertiary,
                        foregroundColor: colorScheme.onTertiary,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Verificar Ahora', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCommissionCard(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      color: colorScheme.errorContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Row(
          children: [
            Icon(Icons.receipt_long_outlined, color: colorScheme.onErrorContainer, size: 44),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Comisión Pendiente', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onErrorContainer)),
                  Text(
                    NumberFormat.currency(locale: 'es_AR', symbol: '\$').format(_comisionAPagar),
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onErrorContainer),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _isPaying ? null : () => _showPaymentOptions(context),
                      style: FilledButton.styleFrom(
                        backgroundColor: colorScheme.error,
                        foregroundColor: colorScheme.onError,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: _isPaying
                          ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(strokeWidth: 3, color: Colors.white))
                          : const Text('Pagar Comisión', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLinkCard(BuildContext context, {required String logoAsset, required String name, bool isLinked = false, bool isEnabled = true, required VoidCallback onTap}) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        leading: SizedBox(width: 40, child: Image.asset(logoAsset, fit: BoxFit.contain)),
        title: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isEnabled ? null : Theme.of(context).disabledColor)),
        trailing: ElevatedButton(
          onPressed: isEnabled ? onTap : null,
          child: Text(isLinked ? 'Gestionar' : 'Vincular'),
        ),
      ),
    );
  }

  Widget _buildDashboardCard(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const MisPresupuestosPage())),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildDashboardStat(context, '12', 'Enviados'),
                  _buildDashboardStat(context, '8', 'Aprobados'),
                  _buildDashboardStat(context, '3', 'Pendientes'),
                ],
              ),
              const Divider(height: 40),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('Gestionar Presupuestos', style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Icon(Icons.arrow_forward_ios, size: 14, color: Theme.of(context).colorScheme.primary),
              ]),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildDashboardStat(BuildContext context, String value, String label) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
  
  Widget _buildPromoAndReferralCard(BuildContext context, String referralCode) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('¿Tienes un código promocional?', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _promoCodeController,
                    decoration: InputDecoration(
                      hintText: 'Ingresa tu código',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(onPressed: () {}, child: const Text('Canjear')),
              ],
            ),
            const Divider(height: 40),
            const Text('¡Invita y gana!', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Comparte tu código y obtén beneficios.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: colorScheme.outline.withOpacity(0.5))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(referralCode, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, letterSpacing: 2)),
                  IconButton(
                    icon: Icon(Icons.share_outlined, color: colorScheme.primary),
                    onPressed: () => Share.share('¡Usa mi código $referralCode para obtener beneficios en Servicly!'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}