import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:path/path.dart' as p;
import 'package:intl/intl.dart';
import 'package:servicly_app/data/locations_data.dart';

class SolicitudServicioNewWidget extends StatefulWidget {
  const SolicitudServicioNewWidget({super.key});

  @override
  State<SolicitudServicioNewWidget> createState() =>
      _SolicitudServicioNewWidgetState();
}

class _SolicitudServicioNewWidgetState
    extends State<SolicitudServicioNewWidget> {
  
  final PageController _pageController = PageController();
  final _formKeyStep1 = GlobalKey<FormState>();
  final _formKeyStep2 = GlobalKey<FormState>();
  final _formKeyStep4 = GlobalKey<FormState>();

  final _tituloController = TextEditingController();
  final _descripcionController = TextEditingController();
  final _horarioController = TextEditingController();
  final _calleController = TextEditingController();
  final _numeroController = TextEditingController();
  final _detallesDirController = TextEditingController();
  
  final List<XFile> _archivosMedia = [];
  String _prioridad = 'Normal';
  DateTime? _fechaSeleccionada;
  bool _isLoading = false;
  String? _formaDePagoSeleccionada;
  final List<String> _opcionesPago = ['Efectivo', 'Transferencia', 'A convenir'];
  bool _requiereSeguro = false;

  String? _paisDelUsuario;
  String? _categoria;
  bool _isInitialDataLoading = true;
  
  String? _provinciaSeleccionada;
  String? _municipioSeleccionado;
  List<String> _listaProvincias = [];
  List<String> _listaMunicipios = [];
  
  int _currentStep = 0;
  final int _totalSteps = 4;

  final List<String> _categorias = [
    'Plomería', 'Gasista', 'Carpintería', 'Pintor', 'Albañil', 'Electricista',
    'Refrigeración', 'Arquitectura y construcción', 'Técnicos', 'Jardinería',
    'Seguridad', 'Mantenimiento', 'Transporte y logística', 'Herrería',
    'Cerrajero', 'Limpieza', 'Control de plagas', 'Soldador', 'Mecánico',
    'Cuidado de Mascotas', 'Cuidado de Niños', 'Cuidado de Adultos', 'Otros'
  ];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
      if (userDoc.exists && userDoc.data()!.containsKey('pais')) {
        if (mounted) {
          setState(() {
            _paisDelUsuario = userDoc.data()!['pais'];
            _listaProvincias = allLocationsData[_paisDelUsuario]?.keys.toList() ?? [];
          });
        }
      }
    }
    if (mounted) setState(() => _isInitialDataLoading = false);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _tituloController.dispose();
    _descripcionController.dispose();
    _horarioController.dispose();
    _calleController.dispose();
    _numeroController.dispose();
    _detallesDirController.dispose();
    super.dispose();
  }

  // --- LÓGICA DE NAVEGACIÓN Y VALIDACIÓN ---

  void _goToStep(int step) {
    if (_pageController.hasClients) {
      _pageController.animateToPage(
        step,
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  bool _validateCurrentStep() {
    switch (_currentStep) {
      case 0: return _formKeyStep1.currentState?.validate() ?? false;
      case 1: return _formKeyStep2.currentState?.validate() ?? false;
      case 2: return true;
      case 3: return _formKeyStep4.currentState?.validate() ?? false;
      default: return false;
    }
  }

  void _onStepContinue() {
    if (_validateCurrentStep()) {
      if (_currentStep < _totalSteps - 1) {
        _goToStep(_currentStep + 1);
      } else {
        _publicarSolicitud();
      }
    }
  }

  void _onStepCancel() {
    if (_currentStep > 0) {
      _goToStep(_currentStep - 1);
    } else {
      Navigator.of(context).pop();
    }
  }

  // --- LÓGICA DE PUBLICACIÓN Y SUBIDA DE ARCHIVOS ---

  Future<void> _publicarSolicitud() async {
    if (!_validateCurrentStep()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Por favor, completa todos los campos requeridos.'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => _isLoading = true);
    final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) {
        setState(() => _isLoading = false);
        return;
      }

    try {
      final List<Map<String, String>> mediaList = await _uploadMedia(currentUser.uid);

      await FirebaseFirestore.instance.collection('solicitudes').add({
        'titulo': _tituloController.text.trim(),
        'descripcion': _descripcionController.text.trim(),
        'user_id': currentUser.uid,
        'fechaCreacion': FieldValue.serverTimestamp(),
        'status': 'Activa',
        'presupuestosCount': 0,
        'media': mediaList,
        'prioridad': _prioridad,
        'formaPago': _formaDePagoSeleccionada,
        'horario': _horarioController.text.trim(),
        'fechaPreferida': _fechaSeleccionada != null ? Timestamp.fromDate(_fechaSeleccionada!) : null,
        'pais': _paisDelUsuario,
        'provincia': _provinciaSeleccionada,
        'municipio': _municipioSeleccionado,
        'categoria': _categoria,
        'requiereSeguro': _requiereSeguro,
        'direccionCompleta': '${_calleController.text.trim()} ${_numeroController.text.trim()}, $_municipioSeleccionado, $_provinciaSeleccionada',
        'proveedoresParticipantes': [],
      });
      await FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).update({
        'haCreadoSolicitudReciente': true
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('¡Solicitud publicada con éxito!'), backgroundColor: Colors.green));
        Navigator.of(context).pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al publicar la solicitud: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
  
  Future<List<Map<String, String>>> _uploadMedia(String userId) async {
    if (_archivosMedia.isEmpty) return [];
    
    final List<Map<String, String>> mediaList = [];
    final storageRef = FirebaseStorage.instance.ref();
    
    for (var xfile in _archivosMedia) {
      final file = File(xfile.path);
      final fileName = '${userId}_solicitud_${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';
      final fileRef = storageRef.child('solicitudes_media/$fileName');
      await fileRef.putFile(file);
      final url = await fileRef.getDownloadURL();
      final type = ['.mp4', '.mov', '.avi'].contains(p.extension(file.path).toLowerCase()) ? 'video' : 'image';
      mediaList.add({'type': type, 'url': url});
    }
    return mediaList;
  }

  // --- LÓGICA PARA SELECCIONAR MEDIA ---
  
  final ImagePicker _picker = ImagePicker();

  void _mostrarOpcionesMedia(BuildContext context) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext bc) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.photo_camera),
                  title: const Text('Tomar Foto'),
                  onTap: () {
                    _tomarFoto();
                    Navigator.of(context).pop();
                  }),
              ListTile(
                leading: const Icon(Icons.videocam),
                title: const Text('Grabar Video'),
                onTap: () {
                  _grabarVideo();
                  Navigator.of(context).pop();
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: const Text('Elegir de la Galería'),
                onTap: () {
                  _seleccionarDesdeGaleria();
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _tomarFoto() async {
    final XFile? foto = await _picker.pickImage(source: ImageSource.camera);
    if (foto != null) {
      setState(() => _archivosMedia.add(foto));
    }
  }

  Future<void> _grabarVideo() async {
    final XFile? video = await _picker.pickVideo(source: ImageSource.camera);
    if (video != null) {
      setState(() => _archivosMedia.add(video));
    }
  }
  
  Future<void> _seleccionarDesdeGaleria() async {
    final List<XFile> pickedFiles = await _picker.pickMultipleMedia();
    if (pickedFiles.isNotEmpty) {
      setState(() => _archivosMedia.addAll(pickedFiles));
    }
  }

  // --- CONSTRUCCIÓN DE LA UI ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Nueva Solicitud - Paso ${_currentStep + 1} de $_totalSteps')),
      bottomNavigationBar: _buildNavigationControls(),
      body: _isInitialDataLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildStepIndicator(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (index) => setState(() => _currentStep = index),
                    children: [
                      _buildStepWrapper(_step1Content()),
                      _buildStepWrapper(_step2Content()),
                      _buildStepWrapper(_step3Content()),
                      _buildStepWrapper(_step4Content()),
                    ],
                  ),
                ),
              ],
            ),
    );
  }

  // --- WIDGETS AUXILIARES (BUILDERS) ---

  Widget _buildStepWrapper(Widget child) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: child,
    );
  }

  Widget _step1Content() {
    return Form(
      key: _formKeyStep1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Describe el Trabajo', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          TextFormField(controller: _tituloController, decoration: _inputDecoration(labelText: 'Título *', hintText: 'Ej. Reparar aire acondicionado'), validator: (v) => v!.trim().isEmpty ? 'El título es requerido.' : null),
          const SizedBox(height: 16),
          TextFormField(controller: _descripcionController, decoration: _inputDecoration(labelText: 'Descripción detallada *', hintText: 'Describe el problema con detalles...'), maxLines: 5, validator: (v) => v!.trim().isEmpty ? 'La descripción es requerida.' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: _categoria, items: _categorias.map((String v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(), onChanged: (val) => setState(() => _categoria = val), decoration: _inputDecoration(labelText: 'Categoría del servicio *'), validator: (v) => v == null ? 'Selecciona una categoría.' : null),
        ],
      ),
    );
  }

  Widget _step2Content() {
    return Form(
      key: _formKeyStep2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Ubicación del Servicio', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          DropdownButtonFormField<String>(initialValue: _provinciaSeleccionada, items: _listaProvincias.map((v) => DropdownMenuItem<String>(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), onChanged: (val) { if (val != null) setState(() { _provinciaSeleccionada = val; _municipioSeleccionado = null; _listaMunicipios = allLocationsData[_paisDelUsuario]![val] ?? []; }); }, decoration: _inputDecoration(labelText: 'Provincia o Estado *'), validator: (v) => v == null ? 'Selecciona una provincia.' : null),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: _municipioSeleccionado, items: _listaMunicipios.map((v) => DropdownMenuItem<String>(value: v, child: Text(v, overflow: TextOverflow.ellipsis))).toList(), onChanged: (val) => setState(() => _municipioSeleccionado = val), decoration: _inputDecoration(labelText: 'Municipio / Partido *').copyWith(hintText: _provinciaSeleccionada == null ? 'Selecciona una provincia primero' : null), validator: (v) => v == null ? 'Selecciona un municipio.' : null, isExpanded: true),
          const SizedBox(height: 16),
          TextFormField(controller: _calleController, decoration: _inputDecoration(labelText: 'Calle o Avenida *'), validator: (v) => v!.trim().isEmpty ? 'La calle es requerida.' : null),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: TextFormField(controller: _numeroController, decoration: _inputDecoration(labelText: 'Número *'), keyboardType: TextInputType.number, validator: (v) => v!.trim().isEmpty ? 'El número es requerido.' : null)),
            const SizedBox(width: 16),
            Expanded(child: TextFormField(controller: _detallesDirController, decoration: _inputDecoration(labelText: 'Piso, Depto (Opcional)'))),
          ]),
          const SizedBox(height: 24),
          Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Theme.of(context).colorScheme.secondaryContainer.withAlpha(128), borderRadius: BorderRadius.circular(8)), child: const Row(children: [Icon(Icons.privacy_tip_outlined, size: 20), SizedBox(width: 10), Expanded(child: Text('Tu dirección exacta solo será visible para el proveedor una vez que aceptes un presupuesto.', style: TextStyle(fontSize: 12)))]))
        ],
      ),
    );
  }
  
  Widget _step3Content() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Fotos y Videos (Opcional)', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Un video o fotos claras ayudan a los profesionales a entender mejor tu necesidad.', style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        _buildMediaUploader(),
        if (_archivosMedia.isNotEmpty) _buildMediaPreview(),
      ],
    );
  }

  Widget _step4Content() {
    return Form(
      key: _formKeyStep4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Detalles Finales', style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 24),
          _buildPrioritySelector(),
          const SizedBox(height: 16),
          _buildDatePicker(context),
          const SizedBox(height: 16),
          TextFormField(controller: _horarioController, decoration: _inputDecoration(labelText: 'Horario preferido (ej. 9am - 12pm)')),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(initialValue: _formaDePagoSeleccionada, items: _opcionesPago.map((v) => DropdownMenuItem<String>(value: v, child: Text(v))).toList(), onChanged: (val) => setState(() => _formaDePagoSeleccionada = val), decoration: _inputDecoration(labelText: 'Forma de pago *'), validator: (v) => v == null ? 'Selecciona una forma de pago.' : null),
          const SizedBox(height: 16),
          _buildInsuranceSelector(),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: List.generate(_totalSteps, (index) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 2.0),
              decoration: BoxDecoration(
                color: _currentStep >= index ? Theme.of(context).colorScheme.primary : Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildNavigationControls() {
    final isLastStep = _currentStep == _totalSteps - 1;
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(top: BorderSide(color: Theme.of(context).dividerColor))
        ),
        child: Row(
          children: [
            OutlinedButton(
              onPressed: _currentStep == 0 ? null : _onStepCancel,
              child: const Text('Anterior'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _isLoading ? null : _onStepContinue,
                style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                child: _isLoading && isLastStep
                    ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                    : Text(isLastStep ? 'Publicar Solicitud' : 'Siguiente'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  InputDecoration _inputDecoration({required String labelText, String? hintText}) {
    final colorScheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      filled: true,
      fillColor: colorScheme.surface.withAlpha(150),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outline.withAlpha(128))),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.outline.withAlpha(128))),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: colorScheme.primary, width: 2)),
    );
  }
  
  Widget _buildInsuranceSelector() {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface.withAlpha(150),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha(128))
      ),
      child: SwitchListTile(
        title: const Text('¿Requiere seguro?'),
        subtitle: const Text('Marca si necesitas que el proveedor tenga seguro de trabajo.'),
        value: _requiereSeguro,
        onChanged: (bool value) => setState(() => _requiereSeguro = value),
        activeThumbColor: Theme.of(context).colorScheme.primary,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Future<void> _seleccionarFecha(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _fechaSeleccionada ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime(2101),
    );
    if (picked != null && picked != _fechaSeleccionada) {
      setState(() => _fechaSeleccionada = picked);
    }
  }

  Widget _buildPrioritySelector() {
    final priorities = ['Baja', 'Normal', 'Urgente'];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Prioridad', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          children: priorities.map((priority) {
            return ChoiceChip(
              label: Text(priority),
              selected: _prioridad == priority,
              onSelected: (selected) {
                if (selected) setState(() => _prioridad = priority);
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildDatePicker(BuildContext context) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface.withAlpha(150),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outline.withAlpha(128))
      ),
      child: ListTile(
        leading: Icon(Icons.calendar_today_outlined, color: Theme.of(context).colorScheme.primary),
        title: const Text('Fecha preferida para el trabajo'),
        subtitle: Text(_fechaSeleccionada == null ? 'No seleccionada' : DateFormat('dd/MM/yyyy').format(_fechaSeleccionada!)),
        onTap: () => _seleccionarFecha(context),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
  
  Widget _buildMediaUploader() {
    final colorScheme = Theme.of(context).colorScheme;
    return DottedBorder(
      color: colorScheme.primary.withOpacity(0.7),
      strokeWidth: 2,
      borderType: BorderType.RRect,
      radius: const Radius.circular(16),
      dashPattern: const [8, 4],
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _mostrarOpcionesMedia(context),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 40.0),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withAlpha(50),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(children: [
            Icon(Icons.add_photo_alternate_outlined, size: 48, color: colorScheme.primary),
            const SizedBox(height: 12),
            Text('Añadir Imágenes o Videos', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: colorScheme.primary)),
            const SizedBox(height: 4),
            Text('Cámara o Galería', style: TextStyle(fontSize: 12, color: colorScheme.primary.withAlpha(204))),
          ]),
        ),
      ),
    );
  }
  
  Widget _buildMediaPreview() {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: _archivosMedia.length,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
        ),
        itemBuilder: (context, index) {
          return _buildPreviewTile(_archivosMedia[index], index);
        },
      ),
    );
  }
  
  Widget _buildPreviewTile(XFile xfile, int index) {
    final file = File(xfile.path);
    final fileExtension = p.extension(file.path).toLowerCase();
    final esVideo = ['.mp4', '.mov', '.avi'].contains(fileExtension);
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Stack(
        fit: StackFit.expand,
        alignment: Alignment.center,
        children: [
          esVideo
              ? Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [colorScheme.secondary, colorScheme.primary],
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                    ),
                  ),
                  child: const Icon(Icons.videocam_outlined, color: Colors.white, size: 32),
                )
              : Image.file(file, fit: BoxFit.cover),
          Positioned(
            top: 4,
            right: 4,
            child: InkWell(
              onTap: () => setState(() => _archivosMedia.removeAt(index)),
              child: CircleAvatar(
                radius: 12,
                backgroundColor: colorScheme.errorContainer,
                child: Icon(Icons.close, size: 16, color: colorScheme.onErrorContainer),
              ),
            ),
          ),
        ],
      ),
    );
  }
}