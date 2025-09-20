import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:servicly_app/Pages/presupuesto/mis_presupuestos_page.dart';
import 'package:servicly_app/models/solicitud_model.dart';
import 'package:flutter/services.dart';
import 'package:servicly_app/models/crear_presupuesto_model.dart';
import 'package:servicly_app/pages/planes/planes_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:servicly_app/models/item_servicio_model.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:servicly_app/Pages/crear_presupuesto/CoordinarVisitaPage.dart';
import 'package:servicly_app/pages/chat/chat_page.dart';

class CrearPresupuestoPage extends StatefulWidget {
  final Solicitud solicitud;
  final String? presupuestoId;

  const CrearPresupuestoPage({
    super.key,
    required this.solicitud,
    this.presupuestoId,
  });

  @override
  State<CrearPresupuestoPage> createState() => _CrearPresupuestoPageState();
}

class _CrearPresupuestoPageState extends State<CrearPresupuestoPage> {
  late final CrearPresupuestoModel _model;
  bool _isSaving = false;
  int _currentStep = 0;
  final int _totalSteps = 4;
  final PageController _pageController = PageController();

  Map<String, dynamic>? _clientData;
  bool _isLoading = true;
  int? _numeroPresupuesto;
  String? _currentPresupuestoId;
  bool _isSuccess = false;
  bool _isProviderVerified = false;
  bool _esPlanConPrivilegios = false;

  @override
  void initState() {
    super.initState();
    _currentPresupuestoId = widget.presupuestoId;
    _model = CrearPresupuestoModel();
    _model.addListener(() => setState(() {}));
    _loadInitialData();
  }
  
  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }
    try {
      if (_currentPresupuestoId != null) {
        final doc = await FirebaseFirestore.instance.collection('presupuestos').doc(_currentPresupuestoId).get();
        if (doc.exists) {
          _model.loadFromMap(doc.data()!);
          _numeroPresupuesto = doc.data()?['numeroPresupuesto'];
        }
      }

      final responses = await Future.wait([
        FirebaseFirestore.instance.collection('usuarios').doc(widget.solicitud.user_id).get(),
        FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get(),
        if (_currentPresupuestoId == null)
          FirebaseFirestore.instance.collection('presupuestos').where('realizadoPor', isEqualTo: user.uid).count().get(),
      ]);

      final clientDoc = responses[0] as DocumentSnapshot<Map<String, dynamic>>;
      final professionalDoc = responses[1] as DocumentSnapshot<Map<String, dynamic>>;
      
      if (mounted) {
        setState(() {
          if (clientDoc.exists) _clientData = clientDoc.data();
          if (professionalDoc.exists) {
            final userPlan = professionalDoc.data()?['plan'] ?? 'Free';
            _esPlanConPrivilegios = (userPlan == 'Premium' || userPlan == 'fundador');
            _isProviderVerified = professionalDoc.data()?['esVerificado'] ?? false;
            _model.setPlanConPrivilegios(_esPlanConPrivilegios);
          }
          if (_currentPresupuestoId == null && responses.length > 2) {
            final budgetCount = responses[2] as AggregateQuerySnapshot;
            _numeroPresupuesto = (budgetCount.count ?? 0) + 1;
          }
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando datos iniciales: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _model.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<bool> _showExitDialog() async {
    final bool? shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Salir sin guardar?'),
        content: const Text('Tenés cambios sin guardar. ¿Querés guardar un borrador antes de salir?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          TextButton(
            child: const Text('Descartar'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
          FilledButton(
            child: const Text('Guardar Borrador'),
            onPressed: () async {
              await _guardarBorrador();
              if (mounted) Navigator.of(context).pop(true);
            },
          ),
        ],
      ),
    );
    return shouldPop ?? false;
  }
  
  Future<void> _handleBackNavigation() async {
    final bool canPop = await _showExitDialog();
    if (canPop && mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _guardarBorrador() async {
    final professionalUserId = FirebaseAuth.instance.currentUser?.uid;
    if (professionalUserId == null) return;
    setState(() => _isSaving = true);
    try {
      final data = _model.toMap(
        idSolicitud: widget.solicitud.id,
        userServicio: widget.solicitud.user_id,
        categoria: widget.solicitud.categoria,
        tituloPresupuesto: 'Presupuesto para: ${widget.solicitud.titulo}',
        realizadoPor: professionalUserId,
        numeroPresupuesto: _numeroPresupuesto,
        provincia: widget.solicitud.provincia,
        municipio: widget.solicitud.municipio,
        direccionCompleta: widget.solicitud.direccionCompleta,
      );
      data['status'] = 'borrador';
      if (_currentPresupuestoId == null) {
        final docRef = await FirebaseFirestore.instance.collection('presupuestos').add(data);
        if(mounted) {
          setState(() {
            _currentPresupuestoId = docRef.id;
          });
        }
      } else {
        await FirebaseFirestore.instance.collection('presupuestos').doc(_currentPresupuestoId).update(data);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Borrador guardado con éxito.'), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar el borrador: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _crearChatDeTrabajo(String presupuestoId) async {
    final professionalUserId = FirebaseAuth.instance.currentUser?.uid;
    if (professionalUserId == null) return;
    
    final clientId = widget.solicitud.user_id;
    final chatData = {
      'tipo': 'trabajo',
      'presupuestoId': presupuestoId,
      'nombreGrupo': 'Trabajo: ${widget.solicitud.titulo}',
      'participantes': [clientId, professionalUserId],
      'ultimoMensaje': {
        'texto': 'Presupuesto enviado. ¡Inicia la conversación!',
        'timestamp': FieldValue.serverTimestamp(),
        'idAutor': 'system',
        'leidoPor': [],
      },
      'unreadCount': 1,
      'creadoEn': FieldValue.serverTimestamp(),
    };
    try {
      await FirebaseFirestore.instance.collection('chats').doc(presupuestoId).set(chatData);
      debugPrint('Chat de trabajo creado con ID: $presupuestoId');
    } catch (e) {
      debugPrint('Error al crear el chat de trabajo: $e');
    }
  }
  
  Future<void> _abrirChatConCliente() async {
    final otherUserId = widget.solicitud.user_id;
    if (otherUserId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo identificar al cliente.'), backgroundColor: Colors.red),
      );
      return;
    }
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);
    try {
      HttpsCallable callable = FirebaseFunctions.instanceFor(region: 'southamerica-east1').httpsCallable('getOrCreateChat');
      final result = await callable.call<Map<String, dynamic>>({'otherUserId': otherUserId});
      final chatId = result.data['chatId'];
      
      if (!mounted) return;
      Navigator.of(context).pop();

      if (chatId != null) {
        final clientName = _clientData?['display_name'] ?? 'Cliente';
        final clientPhoto = _clientData?['photo_url'];
        Navigator.of(context).push(MaterialPageRoute(
          builder: (context) => PaginaChatDetalle(
            chatId: chatId,
            nombreOtroUsuario: clientName,
            fotoUrlOtroUsuario: clientPhoto,
          ),
        ));
      } else {
        throw Exception('No se pudo obtener el ID del chat.');
      }
    } catch (e) {
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el chat: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _solicitarVisita() async {
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Solicitar Visita Técnica'),
        content: const Text('Se enviará una notificación al cliente para coordinar una visita. El presupuesto actual quedará en pausa. ¿Continuar?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, solicitar')),
        ],
      ),
    );

    if (confirmar != true) return;
    showDialog(context: context, builder: (_) => const Center(child: CircularProgressIndicator()), barrierDismissible: false);

    try {
      final professionalUserId = FirebaseAuth.instance.currentUser?.uid;
      if (professionalUserId == null) {
        throw Exception("Usuario no autenticado.");
      }
      final newVisitaDoc = await FirebaseFirestore.instance.collection('visitas_tecnicas').add({
        'solicitudId': widget.solicitud.id,
        'providerId': professionalUserId,
        'clientId': widget.solicitud.user_id,
        'estado': 'pendiente',
        'fechaCreacion': FieldValue.serverTimestamp(),
        'participantIds': [professionalUserId, widget.solicitud.user_id],
      });
      
      if (!mounted) return;
      Navigator.of(context).pop();
      Navigator.of(context).push(MaterialPageRoute(
        builder: (context) => CoordinarVisitaPage(
          visitaId: newVisitaDoc.id,
          solicitudDireccion: widget.solicitud.direccionCompleta,
          currentUserId: professionalUserId,
        ),
      ));
    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al solicitar la visita: $e'), backgroundColor: Colors.red),
      );
    }
  }
  
  Future<void> _confirmarYGuardar() async {
    FocusScope.of(context).unfocus();
    if (!_model.isFormValid) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Debes añadir al menos un costo.'), backgroundColor: Colors.orange));
        _goToStep(0);
      return;
    }
    if(!_model.hitosCoincidenConTotal) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('La suma de los hitos de pago no coincide con el total.'), backgroundColor: Colors.red));
        _goToStep(1);
      return;
    }
    final bool? confirmar = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: const Text('Confirmar Envío'),
        content: const Text('¿Estás seguro de que quieres enviar este presupuesto? Una vez enviado, no podrás editarlo.'),
        actions: <Widget>[
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sí, Enviar')),
        ],
      ),
    );
    if (confirmar == true) await _guardarPresupuestoYContinuar();
  }

  Future<void> _guardarPresupuestoYContinuar() async {
    final professionalUserId = FirebaseAuth.instance.currentUser?.uid;
    if (professionalUserId == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: Debes iniciar sesión.'), backgroundColor: Colors.red));
      return;
    }
    setState(() => _isSaving = true);
    try {
      final data = _model.toMap(
        idSolicitud: widget.solicitud.id,
        userServicio: widget.solicitud.user_id,
        categoria: widget.solicitud.categoria,
        tituloPresupuesto: 'Presupuesto para: ${widget.solicitud.titulo}',
        realizadoPor: professionalUserId,
        numeroPresupuesto: _numeroPresupuesto,
        provincia: widget.solicitud.provincia,
        municipio: widget.solicitud.municipio,
        direccionCompleta: widget.solicitud.direccionCompleta, 
      );
      data['status'] = 'enviado';
      
      String presupuestoId;
      if (_currentPresupuestoId != null) {
        await FirebaseFirestore.instance.collection('presupuestos').doc(_currentPresupuestoId).update(data);
        presupuestoId = _currentPresupuestoId!;
      } else {
        final docRef = await FirebaseFirestore.instance.collection('presupuestos').add(data);
        presupuestoId = docRef.id;
      }
      
      if (mounted) {
        setState(() {
          _isSuccess = true;
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al enviar: $e'), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  
  void _goToStep(int step) {
    setState(() => _currentStep = step);
    _pageController.animateToPage(step, duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _onStepContinue() {
    if (_currentStep < _totalSteps - 1) {
      _goToStep(_currentStep + 1);
    } else {
      _confirmarYGuardar();
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      _handleBackNavigation();
    }
  }
  
  void _mostrarFormularioMaterial({MaterialItem? initialItem}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddMaterialForm(esPlanConPrivilegios: _esPlanConPrivilegios, onUpgradeTap: () => _showUpgradeDialog(context), initialItem: initialItem),
      ),
    );
    if (result != null) {
      _model.addMaterial(result['item']);
      if (result['guardar'] == true) await _guardarItemEnCatalogo(result['item']);
    }
  }

  void _mostrarFormularioManoDeObra({ManoDeObraItem? initialItem}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddManoDeObraForm(esPlanConPrivilegios: _esPlanConPrivilegios, onUpgradeTap: () => _showUpgradeDialog(context), initialItem: initialItem),
      ),
    );
    if (result != null) {
      _model.addManoDeObra(result['item']);
      if (result['guardar'] == true) await _guardarItemEnCatalogo(result['item']);
    }
  }

  void _mostrarFormularioFlete({FleteItem? initialItem}) async {
    final result = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddFleteForm(esPlanConPrivilegios: _esPlanConPrivilegios, onUpgradeTap: () => _showUpgradeDialog(context), initialItem: initialItem),
      ),
    );
    if (result != null) {
      _model.addFlete(result['item']);
      if (result['guardar'] == true) await _guardarItemEnCatalogo(result['item']);
    }
  }
  
  void _mostrarFormularioHito({int? index, HitoDePago? hito}) async {
    final result = await showModalBottomSheet<HitoDePago>(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: _AddHitoForm(hito: hito, montoRestante: _model.montoRestanteHitos + (hito?.monto ?? 0)),
      ),
    );
    if (result != null) {
      if (index != null) {
        _model.updateHito(index, result.descripcion, result.monto);
      } else {
        _model.addHito(result);
      }
    }
  }
  
  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
        context: context,
        initialDate: DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime(2101));
    if (picked != null) {
      _model.fechaInicioController.text = DateFormat('dd/MM/yyyy').format(picked);
    }
  }

  Future<void> _guardarItemEnCatalogo(dynamic item) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    try {
      ItemServicio itemServicio;
      if (item is MaterialItem) {
        itemServicio = ItemServicio(id: '', tipo: 'material', descripcion: item.descripcion, precio: item.precioUnitario, unidad: 'unidad');
      } else if (item is ManoDeObraItem) {
        itemServicio = ItemServicio(id: '', tipo: 'mano_de_obra', descripcion: item.descripcion, precio: item.precioGlobal ?? item.precioUnitario ?? 0, unidad: item.unidad ?? 'global');
      } else if (item is FleteItem) {
        itemServicio = ItemServicio(id: '', tipo: 'flete', descripcion: item.descripcion, precio: item.costo, unidad: 'unidad');
      } else {
        return;
      }
      await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).collection('precios_y_servicios').add({
        'tipo': itemServicio.tipo,
        'descripcion': itemServicio.descripcion,
        'precio': itemServicio.precio,
        'unidad': itemServicio.unidad,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ítem guardado en "Mis Precios"'), backgroundColor: Colors.green));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar el ítem: $e')));
    }
  }

  Future<void> _showUpgradeDialog(BuildContext context) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Función Premium'),
        content: const Text('Para usar ítems guardados de tu catálogo, necesitas una suscripción Premium.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Ahora no')),
          FilledButton(onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PlanesPage()));
          }, child: const Text('Ver Planes')),
        ],
      ),
    );
  }

  Future<void> _seleccionarItemDelCatalogo(String tipo) async {
    final itemSeleccionado = await Navigator.push<ItemServicio>(
      context,
      MaterialPageRoute(builder: (context) => _SeleccionarItemPage(tipo: tipo)),
    );

    if (itemSeleccionado == null) return;

    if (tipo == 'material') {
      final initialItem = MaterialItem(
        descripcion: itemSeleccionado.descripcion,
        cantidad: 1,
        precioUnitario: itemSeleccionado.precio,
      );
      _mostrarFormularioMaterial(initialItem: initialItem);
    } else if (tipo == 'mano_de_obra') {
      final initialItem = ManoDeObraItem(
        descripcion: itemSeleccionado.descripcion,
        precioGlobal: itemSeleccionado.precio,
      );
      _mostrarFormularioManoDeObra(initialItem: initialItem);
    } else if (tipo == 'flete') {
      final initialItem = FleteItem(
        descripcion: itemSeleccionado.descripcion,
        costo: itemSeleccionado.precio
      );
      _mostrarFormularioFlete(initialItem: initialItem);
    }
  }

  void _onIvaToggle(bool incluyeIva) {
    _model.toggleIva(incluyeIva);
    if (_model.hitosDePago.isNotEmpty) {
      final double diferencia = _model.totalFinal - _model.totalHitos;
      if (diferencia.abs() > 0.01) {
        final ultimoHito = _model.hitosDePago.last;
        final nuevoMonto = ultimoHito.monto + diferencia;
        _model.updateHito(
          _model.hitosDePago.length - 1,
          ultimoHito.descripcion,
          nuevoMonto > 0 ? nuevoMonto : 0,
        );
      }
    } else if (_model.totalFinal > 0) {
      _model.addHito(HitoDePago(descripcion: 'Pago único', monto: _model.totalFinal));
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final bool shouldPop = await _showExitDialog();
        if (shouldPop && mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          leading: BackButton(onPressed: _handleBackNavigation),
          title: Text(_isSuccess ? 'Envío Exitoso' : (_currentPresupuestoId == null ? 'Crear Presupuesto' : 'Editando Borrador')),
        ),
        body: _isSuccess ? _buildSuccessView() : _buildFormView(),
        bottomNavigationBar: _isSuccess ? null : _buildBottomBar(),
      ),
    );
  }

  Widget _buildFormView() {
    return _isLoading 
      ? const Center(child: CircularProgressIndicator()) 
      : Column(
          children: [
            _buildStaticHeader(),
            _buildProgressBar(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _buildStepContentWrapper(_buildCostosStep()),
                  _buildStepContentWrapper(_buildHitosDePagoSection()),
                  _buildStepContentWrapper(_buildCondicionesSection()),
                  _buildStepContentWrapper(_buildResumenStep()),
                ],
              ),
            ),
          ],
        );
  }
  
  Widget _buildSuccessView() {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 80),
            const SizedBox(height: 24),
            Text('¡Presupuesto Enviado!', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text('El cliente será notificado y se ha creado un chat de trabajo para que coordinen los detalles.', style: theme.textTheme.bodyLarge, textAlign: TextAlign.center),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.receipt_long_outlined),
                label: const Text('Ver mis Presupuestos'),
                onPressed: () {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const MisPresupuestosPage()),
                    (route) => route.isFirst,
                  );
                },
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              child: const Text('Volver al Inicio'),
              onPressed: () {
                Navigator.of(context).popUntil((route) => route.isFirst);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    if (!_isProviderVerified) {
      return Card(
        margin: const EdgeInsets.only(bottom: 16),
        color: Theme.of(context).colorScheme.surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Theme.of(context).dividerColor)
        ),
        child: const Padding(
          padding: EdgeInsets.all(12.0),
          child: Row(
            children: [
              Icon(Icons.verified_user_outlined, color: Colors.grey, size: 20),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verifica tu perfil para solicitar visitas o chatear con el cliente.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text('Consultar Cliente'),
              onPressed: _abrirChatConCliente,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.location_on_outlined, size: 18),
              label: const Text('Solicitar Visita'),
              onPressed: _solicitarVisita,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContentWrapper(Widget child) {
    return SingleChildScrollView(padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0), child: child);
  }
  
  Widget _buildBottomBar() {
    bool isLastStep = _currentStep == _totalSteps - 1;
    final theme = Theme.of(context);
    final totalFormatted = NumberFormat.currency(locale: 'es_AR', symbol: '\$').format(_model.totalFinal);
    
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).padding.bottom),
      child: BottomAppBar(
        surfaceTintColor: theme.scaffoldBackgroundColor,
        height: 70,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _currentStep == 0 ? null : _onStepCancel,
              child: const Text('Atrás'),
            ),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    totalFormatted,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: theme.colorScheme.primary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  InkWell(
                    onTap: _isSaving ? null : _guardarBorrador,
                    child: Text(
                      'Guardar Borrador',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _isSaving ? Colors.grey : theme.textTheme.bodyMedium?.color,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            FilledButton(
              onPressed: _isSaving ? null : _onStepContinue,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(isLastStep ? 'Enviar' : 'Siguiente'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStaticHeader() {
    final theme = Theme.of(context);
    final clientName = _clientData?['display_name'] ?? 'Cliente';
    final clientPhoto = _clientData?['photo_url'] ?? '';
    return Theme(
      data: theme.copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        leading: CircleAvatar(backgroundImage: clientPhoto.isNotEmpty ? NetworkImage(clientPhoto) : null, child: clientPhoto.isEmpty ? const Icon(Icons.person) : null),
        title: Text(clientName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        subtitle: Text(widget.solicitud.titulo, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Row(mainAxisSize: MainAxisSize.min, children: [ Text("Detalles", style: TextStyle(fontSize: 12)), SizedBox(width: 4), Icon(Icons.info_outline, size: 16)]),
        children: [Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: Text(widget.solicitud.descripcion, style: theme.textTheme.bodyMedium?.copyWith(color: theme.textTheme.bodyMedium?.color?.withAlpha(204))))],
      ),
    );
  }

  Widget _buildProgressBar() {
    final steps = ['Costos', 'Pagos', 'Condiciones', 'Resumen'];
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
      decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor, border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
      child: Row(
        children: List.generate(steps.length, (index) {
          bool isActive = _currentStep >= index;
          return Expanded(
            child: InkWell(
              onTap: () => _goToStep(index),
              child: Column(
                children: [
                  Text(steps[index], style: TextStyle(fontSize: 12, fontWeight: isActive ? FontWeight.bold : FontWeight.normal, color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey)),
                  const SizedBox(height: 8),
                  Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 4.0),
                    decoration: BoxDecoration(color: isActive ? Theme.of(context).colorScheme.primary : Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }
  
  Widget _buildCostosStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Paso 1: Costos Directos", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Añade ítems manualmente o selecciónalos de tu lista de precios guardados.", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        _buildActionButtons(),
        SeccionDeCostoWidget(title: 'Materiales', subtotal: _model.subtotalMateriales, items: _model.materiales, onAdd: () => _mostrarFormularioMaterial(), onSelectFromCatalog: () => _seleccionarItemDelCatalogo('material'), esPlanConPrivilegios: _esPlanConPrivilegios, onUpgradeTap: () => _showUpgradeDialog(context), itemBuilder: (item, index) => ListTile(title: Text(item.descripcion), subtitle: Text('${item.cantidad} x ${NumberFormat.simpleCurrency(locale: 'es_AR').format(item.precioUnitario)}'), trailing: Text(NumberFormat.simpleCurrency(locale: 'es_AR').format(item.precioTotal)), onLongPress: () => _model.removeMaterial(index))),
        SeccionDeCostoWidget(title: 'Mano de Obra', subtotal: _model.subtotalManoDeObra, items: _model.manoDeObra, onAdd: () => _mostrarFormularioManoDeObra(), onSelectFromCatalog: () => _seleccionarItemDelCatalogo('mano_de_obra'), esPlanConPrivilegios: _esPlanConPrivilegios, onUpgradeTap: () => _showUpgradeDialog(context), itemBuilder: (item, index) => ListTile(title: Text(item.descripcion), trailing: Text(NumberFormat.simpleCurrency(locale: 'es_AR').format(item.costo)), onLongPress: () => _model.removeManoDeObra(index))),
        SeccionDeCostoWidget(title: 'Flete y Otros', subtotal: _model.subtotalFletes, items: _model.fletes, onAdd: () => _mostrarFormularioFlete(), onSelectFromCatalog: () => _seleccionarItemDelCatalogo('flete'), esPlanConPrivilegios: _esPlanConPrivilegios, onUpgradeTap: () => _showUpgradeDialog(context), itemBuilder: (item, index) => ListTile(title: Text(item.descripcion), trailing: Text(NumberFormat.simpleCurrency(locale: 'es_AR').format(item.costo)), onLongPress: () => _model.removeFlete(index))),
      ],
    );
  }
  
  Widget _buildHitosDePagoSection() {
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Paso 2: Plan de Pagos", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Define los momentos en que el cliente deberá pagar.", style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_model.hitosDePago.isEmpty) const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No hay hitos de pago definidos.', style: TextStyle(color: Colors.grey)))),
                ..._model.hitosDePago.asMap().entries.map((entry) { int index = entry.key; HitoDePago hito = entry.value; return ListTile(contentPadding: EdgeInsets.zero, title: Text(hito.descripcion), trailing: Text(formatter.format(hito.monto)), onTap: () => _mostrarFormularioHito(index: index, hito: hito), onLongPress: () => _model.removeHito(index)); }),
                const SizedBox(height: 8),
                Align(alignment: Alignment.centerRight, child: TextButton.icon(icon: const Icon(Icons.add), label: const Text('Añadir Hito de Pago'), onPressed: () => _mostrarFormularioHito())),
                if (_model.hitosDePago.isNotEmpty) ...[
                  const Divider(),
                  if (_model.montoRestanteHitos > 0.01) ListTile(contentPadding: EdgeInsets.zero, dense: true, title: Text("Monto restante por asignar", style: TextStyle(color: Theme.of(context).colorScheme.secondary)), trailing: Text(formatter.format(_model.montoRestanteHitos), style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary))),
                  ListTile(contentPadding: EdgeInsets.zero, title: const Text("Total de Hitos", style: TextStyle(fontWeight: FontWeight.bold)), trailing: Text(formatter.format(_model.totalHitos), style: TextStyle(fontWeight: FontWeight.bold, color: _model.hitosCoincidenConTotal ? Colors.green : Colors.red))),
                  if(!_model.hitosCoincidenConTotal) Text("La suma de los hitos no coincide con el total.", style: TextStyle(color: Colors.red.shade700, fontSize: 12)),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
  
  Widget _buildCondicionesSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Paso 3: Condiciones", style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextFormField(controller: _model.fechaInicioController, decoration: const InputDecoration(labelText: "Fecha de inicio estimada", suffixIcon: Icon(Icons.calendar_today)), readOnly: true, onTap: _selectDate),
                const SizedBox(height: 16),
                TextFormField(controller: _model.duracionController, decoration: const InputDecoration(labelText: "Duración estimada del trabajo")),
                const SizedBox(height: 16),
                TextFormField(controller: _model.garantiaController, decoration: const InputDecoration(labelText: "Días de Garantía"), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly]),
                const SizedBox(height: 16),
                TextFormField(controller: _model.validezController, decoration: const InputDecoration(labelText: "Validez de la oferta", hintText: "Ej: 15 días")),
                const SizedBox(height: 16),
                TextFormField(controller: _model.detallePresupuestoController, decoration: const InputDecoration(labelText: "Detalles y Aclaraciones (Opcional)"), maxLines: 3),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResumenStep() {
    final theme = Theme.of(context);
    final providerData = FirebaseAuth.instance.currentUser;
    final clientName = _clientData?['display_name'] ?? 'Cliente';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Paso 4: Vista Previa", style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text("Revisa el presupuesto final antes de enviarlo.", style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        Card(
          elevation: 4,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [ Text("PRESUPUESTO", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)), Text("Nº ${_numeroPresupuesto?.toString().padLeft(4, '0') ?? '...'}", style: theme.textTheme.bodySmall) ]),
                Text("Fecha: ${DateFormat('dd/MM/yyyy').format(DateTime.now())}", style: theme.textTheme.bodySmall),
                const Divider(height: 24),
                _buildPartyInfo("DE:", providerData?.displayName ?? 'Proveedor', providerData?.email ?? ''),
                const SizedBox(height: 16),
                _buildPartyInfo("PARA:", clientName, ''),
                const Divider(height: 24),
                if(_model.materiales.isNotEmpty) ..._buildBreakdownSection("Materiales", _model.materiales.map((e) => MapEntry(e.descripcion, e.precioTotal))),
                if(_model.manoDeObra.isNotEmpty) ..._buildBreakdownSection("Mano de Obra", _model.manoDeObra.map((e) => MapEntry(e.descripcion, e.costo))),
                if(_model.fletes.isNotEmpty) ..._buildBreakdownSection("Fletes y Otros", _model.fletes.map((e) => MapEntry(e.descripcion, e.costo))),
                const Divider(height: 24),
                _buildSummaryRow('Subtotal', _model.subtotalGeneral),
                if (_model.comision > 0) _buildSummaryRow('Comisión Servicly (5%)', _model.comision),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Incluir IVA en el Total', style: TextStyle(fontSize: 16))),
                      Switch(value: _model.incluyeIva, onChanged: _onIvaToggle)
                    ],
                  ),
                ),
                if (_model.incluyeIva) _buildSummaryRow('IVA (21%)', _model.iva),
                const Divider(height: 20),
                _buildSummaryRow('TOTAL', _model.totalFinal, isTotal: true, color: theme.colorScheme.primary),
              ],
            ),
          ),
        )
      ],
    );
  }
  
  Widget _buildPartyInfo(String title, String name, String email) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: Theme.of(context).textTheme.labelSmall),
        Text(name, style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
        if (email.isNotEmpty) Text(email, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  List<Widget> _buildBreakdownSection(String title, Iterable<MapEntry<String, double>> items) {
    return [
      Text(title.toUpperCase(), style: Theme.of(context).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...items.map((item) => _buildSummaryRow(item.key, item.value)),
      const SizedBox(height: 16),
    ];
  }
  
  Widget _buildSummaryRow(String title, double amount, {bool isTotal = false, Color? color}) {
    final style = TextStyle(fontSize: isTotal ? 20 : 16, fontWeight: isTotal ? FontWeight.bold : FontWeight.normal, color: color);
    return Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row(children: [Expanded(child: Text(title, style: style.copyWith(fontWeight: FontWeight.normal))), Text(NumberFormat.currency(locale: 'es_AR', symbol: '\$').format(amount), style: style)]));
  }
}

// --- CLASES AUXILIARES Y FORMULARIOS ---
class SeccionDeCostoWidget<T> extends StatelessWidget {
  final String title;
  final double subtotal;
  final List<T> items;
  final VoidCallback onAdd;
  final Widget Function(T item, int index) itemBuilder;
  final bool esPlanConPrivilegios;
  final VoidCallback onUpgradeTap;
  final VoidCallback onSelectFromCatalog;

  const SeccionDeCostoWidget({
    super.key,
    required this.title,
    required this.subtotal,
    required this.items,
    required this.onAdd,
    required this.itemBuilder,
    required this.esPlanConPrivilegios,
    required this.onUpgradeTap,
    required this.onSelectFromCatalog,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: true,
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: Text(NumberFormat.currency(locale: 'es_AR', symbol: '\$').format(subtotal), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        children: [
          if (items.isEmpty) const Padding(padding: EdgeInsets.all(16.0), child: Text('No hay ítems agregados.', style: TextStyle(color: Colors.grey))),
          ...items.asMap().entries.map((entry) => itemBuilder(entry.value, entry.key)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton.icon(
                  icon: Icon(Icons.list_alt, color: esPlanConPrivilegios ? null : Colors.grey),
                  label: Text('Seleccionar', style: TextStyle(color: esPlanConPrivilegios ? null : Colors.grey)),
                  onPressed: esPlanConPrivilegios ? onSelectFromCatalog : onUpgradeTap,
                ),
                const SizedBox(width: 8),
                FilledButton.icon(icon: const Icon(Icons.add), label: const Text('Añadir Manual'), onPressed: onAdd),
              ],
            ),
          )
        ],
      ),
    );
  }
}

class _AddMaterialForm extends StatefulWidget {
  final bool esPlanConPrivilegios;
  final VoidCallback onUpgradeTap;
  final MaterialItem? initialItem;
  const _AddMaterialForm({required this.esPlanConPrivilegios, required this.onUpgradeTap, this.initialItem});
  
  @override State<_AddMaterialForm> createState() => _AddMaterialFormState();
}

class _AddMaterialFormState extends State<_AddMaterialForm> {
  final _formKey = GlobalKey<FormState>();
  final _d = TextEditingController();
  final _c = TextEditingController();
  final _p = TextEditingController();
  bool _guardarItem = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _d.text = widget.initialItem!.descripcion;
      _c.text = widget.initialItem!.cantidad.toString();
      _p.text = widget.initialItem!.precioUnitario.toStringAsFixed(2);
    }
  }

  @override
  void dispose() {
    _d.dispose();
    _c.dispose();
    _p.dispose();
    super.dispose();
  }

  void _s() {
    if (_formKey.currentState!.validate()) {
      final item = MaterialItem(
        descripcion: _d.text,
        cantidad: int.parse(_c.text),
        precioUnitario: double.parse(_p.text.replaceAll(',', '.'))
      );
      Navigator.of(context).pop({'item': item, 'guardar': widget.esPlanConPrivilegios && _guardarItem});
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20.0),
    child: Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(widget.initialItem == null ? 'Añadir Material' : 'Editar Material', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextFormField(controller: _d, decoration: const InputDecoration(labelText: 'Descripción'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(child: TextFormField(controller: _c, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => v!.isEmpty ? 'Requerido' : null)),
            const SizedBox(width: 10),
            Expanded(child: TextFormField(controller: _p, decoration: const InputDecoration(labelText: 'Precio Unitario', prefixText: '\$'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,2}'))], validator: (v) => v!.isEmpty ? 'Requerido' : null))
          ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: !widget.esPlanConPrivilegios ? widget.onUpgradeTap : null,
            child: AbsorbPointer(
              absorbing: !widget.esPlanConPrivilegios,
              child: CheckboxListTile(
                value: _guardarItem,
                title: Text('Guardar en "Mis Precios"', style: TextStyle(color: widget.esPlanConPrivilegios ? null : Colors.grey)),
                subtitle: widget.esPlanConPrivilegios ? null : const Text('Función Premium'),
                onChanged: (value) => setState(() => _guardarItem = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _s, child: Text(widget.initialItem == null ? 'Añadir' : 'Confirmar')))
        ],
      ),
    ),
  );
}
class _AddManoDeObraForm extends StatefulWidget {
  final bool esPlanConPrivilegios;
  final VoidCallback onUpgradeTap;
  final ManoDeObraItem? initialItem;
  
  const _AddManoDeObraForm({
    required this.esPlanConPrivilegios, 
    required this.onUpgradeTap, 
    this.initialItem
  });

  @override 
  State<_AddManoDeObraForm> createState() => _AddManoDeObraFormState();
}

class _AddManoDeObraFormState extends State<_AddManoDeObraForm> {
  final _formKey = GlobalKey<FormState>();
  final _d = TextEditingController(), _c = TextEditingController(), _p = TextEditingController(), _g = TextEditingController();
  String? _u;
  bool _isGlobal = true;
  bool _guardarItem = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _d.text = widget.initialItem!.descripcion;
      _isGlobal = widget.initialItem!.precioGlobal != null;
      if (_isGlobal) {
        _g.text = widget.initialItem!.precioGlobal!.toStringAsFixed(2);
      } else {
        _c.text = widget.initialItem!.cantidad.toString();
        _p.text = widget.initialItem!.precioUnitario!.toStringAsFixed(2);
        _u = widget.initialItem!.unidad;
      }
    }
  }

  @override
  void dispose() {
    _d.dispose();
    _c.dispose();
    _p.dispose();
    _g.dispose();
    super.dispose();
  }

  void _s() {
    if (_formKey.currentState!.validate()) {
      final item = ManoDeObraItem(
        descripcion: _d.text, 
        precioGlobal: _isGlobal ? double.tryParse(_g.text.replaceAll(',', '.')) : null, 
        cantidad: !_isGlobal ? double.tryParse(_c.text.replaceAll(',', '.')) : null, 
        precioUnitario: !_isGlobal ? double.tryParse(_p.text.replaceAll(',', '.')) : null, 
        unidad: !_isGlobal ? _u : null
      );
      Navigator.of(context).pop({'item': item, 'guardar': widget.esPlanConPrivilegios && _guardarItem});
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20.0), 
    child: Form(
      key: _formKey, 
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(widget.initialItem == null ? 'Añadir Mano de Obra' : 'Editar Mano de Obra', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextFormField(controller: _d, decoration: const InputDecoration(labelText: 'Descripción'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
          const SizedBox(height: 20),
          ToggleButtons(
            isSelected: [_isGlobal, !_isGlobal], 
            onPressed: (i) => setState(() => _isGlobal = i == 0), 
            borderRadius: BorderRadius.circular(8), 
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Precio Global')), 
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Detallado'))
            ]
          ),
          const SizedBox(height: 20),
          if (_isGlobal)
            TextFormField(controller: _g, decoration: const InputDecoration(labelText: 'Precio Global', prefixText: '\$'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,2}'))], validator: (v) => v!.isEmpty ? 'Requerido' : null)
          else
            Column(children: [
              Row(children: [
                Expanded(flex: 2, child: TextFormField(controller: _c, decoration: const InputDecoration(labelText: 'Cantidad'), keyboardType: TextInputType.number, inputFormatters: [FilteringTextInputFormatter.digitsOnly], validator: (v) => v!.isEmpty ? 'Requerido' : null)),
                const SizedBox(width: 10),
                Expanded(flex: 3, child: DropdownButtonFormField<String>(initialValue: _u, hint: const Text('Unidad'), items: ['m²', 'ml', 'hr', 'día', 'unidad'].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(), onChanged: (v) => setState(() => _u = v), validator: (v) => v == null ? 'Requerido' : null))
              ]),
              const SizedBox(height: 10),
              TextFormField(controller: _p, decoration: const InputDecoration(labelText: 'Precio Unitario', prefixText: '\$'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,2}'))], validator: (v) => v!.isEmpty ? 'Requerido' : null)
            ]),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: !widget.esPlanConPrivilegios ? widget.onUpgradeTap : null,
            child: AbsorbPointer(
              absorbing: !widget.esPlanConPrivilegios,
              child: CheckboxListTile(
                value: _guardarItem,
                title: Text('Guardar en "Mis Precios"', style: TextStyle(color: widget.esPlanConPrivilegios ? null : Colors.grey)),
                subtitle: widget.esPlanConPrivilegios ? null : const Text('Función Premium'),
                onChanged: (value) => setState(() => _guardarItem = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _s, child: Text(widget.initialItem == null ? 'Añadir' : 'Confirmar')))
        ]
      )
    )
  );
}

class _AddFleteForm extends StatefulWidget {
  final bool esPlanConPrivilegios;
  final VoidCallback onUpgradeTap;
  final FleteItem? initialItem;
  
  const _AddFleteForm({
    required this.esPlanConPrivilegios, 
    required this.onUpgradeTap, 
    this.initialItem
  });

  @override 
  State<_AddFleteForm> createState() => _AddFleteFormState();
}

class _AddFleteFormState extends State<_AddFleteForm> {
  final _formKey = GlobalKey<FormState>();
  final _d = TextEditingController(), _c = TextEditingController();
  bool _guardarItem = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialItem != null) {
      _d.text = widget.initialItem!.descripcion;
      _c.text = widget.initialItem!.costo.toStringAsFixed(2);
    }
  }
  
  @override
  void dispose() {
    _d.dispose();
    _c.dispose();
    super.dispose();
  }

  void _s() {
    if (_formKey.currentState!.validate()) {
      final item = FleteItem(descripcion: _d.text, costo: double.parse(_c.text.replaceAll(',', '.')));
      Navigator.of(context).pop({'item': item, 'guardar': widget.esPlanConPrivilegios && _guardarItem});
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(20.0), 
    child: Form(
      key: _formKey, 
      child: Column(
        mainAxisSize: MainAxisSize.min, 
        children: [
          Text(widget.initialItem == null ? 'Añadir Flete u Otro' : 'Editar Flete', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          TextFormField(controller: _d, decoration: const InputDecoration(labelText: 'Descripción'), validator: (v) => v!.isEmpty ? 'Requerido' : null),
          const SizedBox(height: 10),
          TextFormField(controller: _c, decoration: const InputDecoration(labelText: 'Costo Total', prefixText: '\$'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,2}'))], validator: (v) => v!.isEmpty ? 'Requerido' : null),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: !widget.esPlanConPrivilegios ? widget.onUpgradeTap : null,
            child: AbsorbPointer(
              absorbing: !widget.esPlanConPrivilegios,
              child: CheckboxListTile(
                value: _guardarItem,
                title: Text('Guardar en "Mis Precios"', style: TextStyle(color: widget.esPlanConPrivilegios ? null : Colors.grey)),
                subtitle: widget.esPlanConPrivilegios ? null : const Text('Función Premium'),
                onChanged: (value) => setState(() => _guardarItem = value ?? false),
                controlAffinity: ListTileControlAffinity.leading,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(width: double.infinity, child: FilledButton(onPressed: _s, child: Text(widget.initialItem == null ? 'Añadir' : 'Confirmar')))
        ]
      )
    )
  );
}

class _AddHitoForm extends StatefulWidget {
  final HitoDePago? hito;
  final double montoRestante;
  const _AddHitoForm({this.hito, required this.montoRestante});
  
  @override 
  State<_AddHitoForm> createState() => _AddHitoFormState();
}

class _AddHitoFormState extends State<_AddHitoForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _descripcionController;
  late TextEditingController _montoController;

  @override 
  void initState() { 
    super.initState(); 
    _descripcionController = TextEditingController(text: widget.hito?.descripcion ?? ''); 
    _montoController = TextEditingController(text: widget.hito != null ? widget.hito!.monto.toStringAsFixed(2) : ''); 
  }

  @override 
  void dispose() { 
    _descripcionController.dispose(); 
    _montoController.dispose(); 
    super.dispose(); 
  }

  void _submit() { 
    if (_formKey.currentState!.validate()) { 
      final monto = double.parse(_montoController.text.replaceAll(',', '.')); 
      final hito = HitoDePago(descripcion: _descripcionController.text, monto: monto); 
      Navigator.of(context).pop(hito); 
    } 
  }
  
  @override 
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(locale: 'es_AR', symbol: '\$');
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.hito == null ? 'Añadir Hito de Pago' : 'Editar Hito de Pago', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            Text('Monto restante por asignar: ${formatter.format(widget.montoRestante)}', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.secondary)),
            const SizedBox(height: 16),
            TextFormField(controller: _descripcionController, decoration: const InputDecoration(labelText: 'Descripción del Hito'), validator: (v) => (v == null || v.isEmpty) ? 'Campo requerido' : null),
            const SizedBox(height: 10),
            TextFormField(controller: _montoController, decoration: const InputDecoration(labelText: 'Monto a Pagar', prefixText: '\$'), keyboardType: const TextInputType.numberWithOptions(decimal: true), inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'^\d+\,?\d{0,2}'))], validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null),
            const SizedBox(height: 20),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _submit, child: Text(widget.hito == null ? 'Añadir' : 'Guardar Cambios')))
          ],
        ),
      ),
    );
  }
}

class _SeleccionarItemPage extends StatefulWidget {
  final String tipo;
  const _SeleccionarItemPage({required this.tipo});

  @override 
  State<_SeleccionarItemPage> createState() => _SeleccionarItemPageState();
}

class _SeleccionarItemPageState extends State<_SeleccionarItemPage> {
  final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override 
  void initState() { 
    super.initState(); 
    _searchController.addListener(() { 
      setState(() { _searchQuery = _searchController.text; }); 
    }); 
  }
  
  @override 
  void dispose() { 
    _searchController.dispose(); 
    super.dispose(); 
  }
  
  @override 
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = widget.tipo == 'mano_de_obra' ? 'Mano de Obra' : (widget.tipo == 'material' ? 'Material' : 'Flete');
    
    return Scaffold(
      appBar: AppBar(
        title: Text('Seleccionar $title'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60.0),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(controller: _searchController, decoration: InputDecoration(hintText: 'Buscar en mis precios...', prefixIcon: const Icon(Icons.search, size: 20), filled: true, fillColor: theme.colorScheme.surfaceContainerHighest, border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none))),
          ),
        ),
      ),
      body: currentUserId == null
          ? const Center(child: Text('Error: No se encontró el usuario.'))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('usuarios').doc(currentUserId).collection('precios_y_servicios').where('tipo', isEqualTo: widget.tipo).orderBy('descripcion').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) { return const Center(child: CircularProgressIndicator()); }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) { return Center(child: Padding(padding: const EdgeInsets.all(24.0), child: Text('No tienes ítems de tipo "$title" guardados en tu catálogo.', textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.grey)))); }
                
                final allItems = snapshot.data!.docs.map((doc) => ItemServicio.fromFirestore(doc)).toList();
                final filteredItems = allItems.where((item) { return item.descripcion.toLowerCase().contains(_searchQuery.toLowerCase()); }).toList();
                
                if (filteredItems.isEmpty) { return const Center(child: Text('No se encontraron resultados.')); }
                
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: filteredItems.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final item = filteredItems[index];
                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      title: Text(item.descripcion, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: Text(item.unidad),
                      trailing: Text(NumberFormat.currency(locale: 'es_AR', symbol: '\$').format(item.precio), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: theme.colorScheme.primary)),
                      onTap: () { Navigator.of(context).pop(item); },
                    );
                  },
                );
              },
            ),
    );
  }
}