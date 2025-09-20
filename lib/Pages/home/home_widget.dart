import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:servicly_app/Pages/PromocionesPage/promociones_y_referidos_page.dart';
import 'package:servicly_app/Pages/inicio/inicio_widget.dart';
import 'package:servicly_app/pages/Post.app/crear_post/crear_post_widget.dart';
import 'package:servicly_app/pages/chat/lista_chats_page.dart';
import 'package:servicly_app/new_solicitud_servicio/new_solicitud_servicio.dart';
import 'package:servicly_app/precios_y_servicios/mis_precios_servicios_page.dart';
import 'package:servicly_app/widgets/Top_Users_Row.dart';
import 'package:servicly_app/widgets/post_card_widget.dart';
import 'package:servicly_app/pages/perfil_pagina/perfil_pagina_widget.dart';
import 'package:servicly_app/Pages/Solicitudes/mis_solicitudes.dart';
import 'package:servicly_app/pages/pagos/verificacion_page.dart';
import 'package:servicly_app/pages/presupuesto/mis_presupuestos_page.dart';
import 'package:servicly_app/Pages/saved_posts/saved_posts_page.dart';
import 'package:servicly_app/Pages/planes/planes_page.dart';
import 'package:servicly_app/config/settings_page.dart';
import 'package:servicly_app/models/solicitud_model.dart';
import 'package:servicly_app/widgets/solicitud_card_widget.dart';
import 'package:servicly_app/pages/contrato/mis_contratos_page.dart';
import 'package:servicly_app/Pages/inicio/search_results_page.dart'; 
import 'package:servicly_app/widgets/agenda_drawer_tile.dart';

class HomeWidget extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  final String? userRol;

  const HomeWidget({
    super.key,
    required this.onThemeChanged,
    this.userRol,
  });

  @override
  State<HomeWidget> createState() => _HomeWidgetState();
}

class _HomeWidgetState extends State<HomeWidget> with TickerProviderStateMixin {
  late TabController _tabController;
  String? _currentUserRole;
  String? _currentUserCountry;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 1, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final userDoc = await FirebaseFirestore.instance.collection('usuarios').doc(user.uid).get();
        if (userDoc.exists && mounted) {
          final userData = userDoc.data()!;
          setState(() {
            _currentUserRole = widget.userRol ?? userData['rol_user'] as String?;
            _currentUserCountry = userData['pais'] as String?;
          });
          _updateTabControllerBasedOnRole();
        } else {
          _setDefaultValues();
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error al cargar datos del perfil: $e')),
          );
          _setDefaultValues();
        }
      }
    } else {
      _setDefaultValues();
    }
  }

  void _setDefaultValues() {
    if (mounted) {
      setState(() {
        _currentUserRole = 'Cliente';
        _currentUserCountry = null;
      });
      _updateTabControllerBasedOnRole();
    }
  }

  void _updateTabControllerBasedOnRole() {
    int newLength = 1;
    if (_currentUserRole == 'Proveedor' || _currentUserRole == 'Ambos') {
      newLength = 2;
    }

    if (_tabController.length != newLength) {
      final int oldIndex = _tabController.index;
      _tabController.dispose();
      _tabController = TabController(
          length: newLength,
          vsync: this,
          initialIndex: oldIndex.clamp(0, newLength - 1));
      setState(() {});
    }
  }

  void _showCreateOptions(BuildContext context) {
    List<Widget> options = [];

    if (_currentUserRole == 'Cliente' || _currentUserRole == 'Proveedor' || _currentUserRole == 'Ambos') {
      options.add(
        ListTile(
          leading: Icon(Icons.assignment, color: Theme.of(context).colorScheme.primary, size: 30),
          title: const Text('Nueva Solicitud de Servicio', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('¿Necesitas ayuda con un trabajo?'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const SolicitudServicioNewWidget()));
          },
        ),
      );
    }

    if (_currentUserRole == 'Proveedor' || _currentUserRole == 'Cliente' || _currentUserRole == 'Ambos') {
      options.add(
        ListTile(
          leading: Icon(Icons.campaign, color: Theme.of(context).colorScheme.secondary, size: 30),
          title: const Text('Crear Publicación', style: TextStyle(fontWeight: FontWeight.bold)),
          subtitle: const Text('Ofrece tus servicios a la comunidad'),
          onTap: () {
            Navigator.pop(context);
            Navigator.push(context, MaterialPageRoute(builder: (context) => const CrearPostWidget()));
          },
        ),
      );
    }

    if (options.isEmpty) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Wrap(
          children: options,
        ),
      ),
    );
  }

  Widget _buildPlanFundadorBanner(Map<String, dynamic> userData) {
  // La lógica para mostrar/ocultar no cambia
  if (userData['plan'] != 'fundador') {
    return const SizedBox.shrink();
  }

  // --- CAMBIOS DE COLOR AQUÍ ---
  final theme = Theme.of(context);
  // Cambiamos el color de fondo a una variante del color primario
  final Color backgroundColor = theme.colorScheme.primaryContainer; 
  // Y nos aseguramos de que el texto/ícono tengan el contraste correcto
  final Color contentColor = theme.colorScheme.onPrimaryContainer;

  return Card(
    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: backgroundColor, // <-- Se aplica el nuevo color de fondo
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: Padding(
      padding: const EdgeInsets.all(12.0),
      child: Row(
        children: [
          Icon(
            Icons.auto_awesome, 
            color: contentColor // <-- Se aplica el nuevo color de contenido
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "¡Estás disfrutando del Plan Fundador con todos los beneficios!",
              style: TextStyle(
                color: contentColor, // <-- Se aplica el nuevo color de contenido
                fontWeight: FontWeight.w500
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    if (_currentUserRole == null || _currentUserCountry == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    List<Tab> tabs = [const Tab(text: 'Para ti')];
    List<Widget> tabViews = [_InstagramLikeFeed(userCountry: _currentUserCountry!)];

    if (_currentUserRole == 'Proveedor' || _currentUserRole == 'Ambos') {
      tabs.add(const Tab(text: 'Solicitudes'));
      tabViews.add(_SolicitudesList(userRole: _currentUserRole, userCountry: _currentUserCountry!));
    }
    
    return Scaffold(
      endDrawer: _DrawerPerfil(
        onThemeChanged: widget.onThemeChanged,
        userRole: _currentUserRole!,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            _HomeAppBar(onThemeChanged: widget.onThemeChanged),
            SliverToBoxAdapter(
              child: StreamBuilder<DocumentSnapshot>(
                stream: FirebaseFirestore.instance.collection('usuarios').doc(FirebaseAuth.instance.currentUser?.uid).snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData || !snapshot.data!.exists) {
                    return const SizedBox.shrink();
                  }
                  final userData = snapshot.data!.data() as Map<String, dynamic>;
                  return _buildPlanFundadorBanner(userData);
                }
              ),
            ),
            SliverToBoxAdapter(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 8, bottom: 8),
                    child: Text("Profesionales Destacados", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  ),
                  TopUsersRow(searchQuery: '', userCountry: _currentUserCountry!),
                ],
              ),
            ),
            SliverPersistentHeader(
              delegate: _SliverTabBarDelegate(
                tabBar: TabBar(
                  controller: _tabController,
                  tabs: tabs,
                ),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              pinned: true,
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: tabViews,
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateOptions(context),
        shape: const CircleBorder(),
        child: const Icon(Icons.add),
      ),
    );
  }
}

// --- CLASES AUXILIARES QUE PERTENECEN A ESTE ARCHIVO ---

class _HomeAppBar extends StatefulWidget {
  final void Function(bool) onThemeChanged;
  const _HomeAppBar({required this.onThemeChanged});

  @override
  State<_HomeAppBar> createState() => _HomeAppBarState();
}

class _HomeAppBarState extends State<_HomeAppBar> {
  Stream<int> _unreadChatsStream() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return Stream.value(0);
    return FirebaseFirestore.instance.collection('chats').where('participantes', arrayContains: user.uid).snapshots().map((snapshot) {
      int unreadCount = 0;
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final ultimoMensaje = data['ultimoMensaje'] as Map<String, dynamic>?;
        if (ultimoMensaje != null) {
          final leidoPor = ultimoMensaje['leidoPor'] as List<dynamic>? ?? [];
          if (!leidoPor.contains(user.uid) && ultimoMensaje['idAutor'] != user.uid) {
            unreadCount++;
          }
        }
      }
      return unreadCount;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDarkMode = theme.brightness == Brightness.dark;
    return SliverAppBar(
      title: const Text('Servicly'),
      centerTitle: true,
      floating: true,
      pinned: false,
      actions: [
        IconButton(
          tooltip: 'Cambiar Tema',
          icon: Icon(isDarkMode ? Icons.light_mode : Icons.dark_mode),
          onPressed: () => widget.onThemeChanged(!isDarkMode),
        ),
        StreamBuilder<int>(
          stream: _unreadChatsStream(),
          builder: (context, snapshot) {
            final unreadCount = snapshot.data ?? 0;
            return Badge(
              backgroundColor: Colors.blue.shade700,
              label: Text('$unreadCount'),
              isLabelVisible: unreadCount > 0,
              alignment: Alignment.topRight,
              offset: const Offset(-4, 4),
              child: IconButton(
                icon: const Icon(Icons.chat_bubble_outline),
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ListaChatsPage())),
              ),
            );
          },
        ),
        const Padding(
          padding: EdgeInsets.only(right: 8.0),
          child: _UserAvatar(),
        ),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(60.0),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: TextField(
            onSubmitted: (query) {
              if (query.trim().isNotEmpty) {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => SearchResultsSheet(searchQuery: query),
                );
              }
            },
            decoration: InputDecoration(
              hintText: 'Buscar profesionales por nombre...',
              prefixIcon: const Icon(Icons.search, size: 20),
              filled: true,
              fillColor: theme.cardTheme.color,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(30),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UserAvatar extends StatelessWidget {
  const _UserAvatar();
  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => Scaffold.of(context).openEndDrawer(),
      child: StreamBuilder<DocumentSnapshot>(
        stream: currentUser != null ? FirebaseFirestore.instance.collection('usuarios').doc(currentUser.uid).snapshots() : null,
        builder: (context, snapshot) {
          String? photoUrl;
          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            photoUrl = userData['photo_url'];
          }
          final hasPhoto = photoUrl != null && photoUrl.isNotEmpty;
          return CircleAvatar(
            radius: 18,
            backgroundColor: theme.colorScheme.primary.withAlpha(25),
            backgroundImage: hasPhoto ? NetworkImage(photoUrl) : null,
            child: !hasPhoto ? Icon(Icons.person, size: 18, color: theme.colorScheme.primary) : null,
          );
        },
      ),
    );
  }
}

class _SliverTabBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverTabBarDelegate({required this.tabBar, required this.color});
  final TabBar tabBar;
  final Color color;

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: color,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(_SliverTabBarDelegate oldDelegate) {
    return color != oldDelegate.color || tabBar != oldDelegate.tabBar;
  }
}

class _SolicitudesList extends StatefulWidget {
  final String? userRole;
  final String userCountry;
  const _SolicitudesList({this.userRole, required this.userCountry});

  @override
  State<_SolicitudesList> createState() => _SolicitudesListState();
}

class _SolicitudesListState extends State<_SolicitudesList> {
  String? _selectedCategory;
  
  // Estas variables guardan el estado, por eso NO deben ser 'final'.
  List<String> _dbCategories = [];
  bool _isLoadingCategories = true;

  @override
  void initState() {
    super.initState();
    _fetchCategories(); // Esta llamada necesita la función de abajo.
  }

  // ✅ ESTA ES LA FUNCIÓN QUE FALTABA
  Future<void> _fetchCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance.collection('categorias').orderBy('nombre').get();
      final categoriesFromDb = snapshot.docs.map((doc) => doc.data()['nombre'] as String).toList();
      
      if (mounted) {
        setState(() {
          _dbCategories = categoriesFromDb;
          _isLoadingCategories = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() { _isLoadingCategories = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al cargar las categorías: ${e.toString()}')),
        );
      }
    }
  }

  // Función para mostrar un diálogo con las opciones de filtro.
  Future<void> _mostrarDialogoDeFiltros() async {
    final String? categoriaSeleccionada = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Filtrar por Categoría'),
          children: [
            SimpleDialogOption(
              onPressed: () {
                Navigator.pop(context, null); // Devuelve null para quitar el filtro
              },
              child: const Text('Mostrar Todas'),
            ),
            ..._dbCategories.map((category) => SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context, category);
                  },
                  child: Text(category),
                )),
          ],
        );
      },
    );

    if (categoriaSeleccionada != _selectedCategory) {
      setState(() {
        _selectedCategory = categoriaSeleccionada;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    Query solicitudesQuery = FirebaseFirestore.instance
        .collection('solicitudes')
        .where('pais', isEqualTo: widget.userCountry)
        .where('status', isEqualTo: 'Activa');

    if (_selectedCategory != null) {
      solicitudesQuery = solicitudesQuery.where('category', isEqualTo: _selectedCategory);
    }

    solicitudesQuery = solicitudesQuery.orderBy('fechaCreacion', descending: true);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _selectedCategory ?? 'Todas las solicitudes',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              TextButton.icon(
                icon: const Icon(Icons.filter_list),
                label: const Text('Filtrar'),
                onPressed: _isLoadingCategories ? null : _mostrarDialogoDeFiltros,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: solicitudesQuery.snapshots(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Error al cargar solicitudes: ${snapshot.error}'));
              }
              if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                return const Center(child: Text('No hay solicitudes que coincidan con el filtro.'));
              }

              final solicitudesDocs = snapshot.data!.docs;
              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: solicitudesDocs.length,
                itemBuilder: (context, index) {
                  final doc = solicitudesDocs[index] as DocumentSnapshot<Map<String, dynamic>>;
                  final solicitud = Solicitud.fromFirestore(doc);
                  final currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: SolicitudCardWidget(
                      solicitud: solicitud,
                      currentUserId: currentUserId,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InstagramLikeFeed extends StatefulWidget {
  final String userCountry;
  const _InstagramLikeFeed({required this.userCountry});

  @override
  State<_InstagramLikeFeed> createState() => _InstagramLikeFeedState();
}

class _InstagramLikeFeedState extends State<_InstagramLikeFeed> {
  late Future<List<Map<String, dynamic>>> _feedFuture;

  @override
  void initState() {
    super.initState();
    _feedFuture = _getFeedData();
  }

  // Se ha eliminado didUpdateWidget porque ya no depende de categoryFiltro

  Future<List<Map<String, dynamic>>> _getFeedData() async {
    // La consulta ahora es más simple, sin filtro de categoría
    Query postQuery = FirebaseFirestore.instance
        .collection('post')
        .where('pais', isEqualTo: widget.userCountry)
        .orderBy('timestamp', descending: true);

    final postsSnapshot = await postQuery.limit(20).get();
    if (postsSnapshot.docs.isEmpty) return [];

    final authorIds = postsSnapshot.docs
        .map((doc) => (doc.data() as Map<String, dynamic>?)?['user_id'] as String?)
        .where((id) => id != null)
        .toSet()
        .toList();

    Map<String, dynamic> authorsData = {};
    if (authorIds.isNotEmpty) {
      final authorsSnapshot = await FirebaseFirestore.instance.collection('usuarios').where(FieldPath.documentId, whereIn: authorIds).get();
      for (var doc in authorsSnapshot.docs) {
        authorsData[doc.id] = doc.data();
      }
    }

    List<Map<String, dynamic>> feedItems = [];
    for (var postDoc in postsSnapshot.docs) {
      final postData = postDoc.data() as Map<String, dynamic>? ?? {};
      final authorId = postData['user_id'];
      final authorData = authorsData[authorId] ?? {};
      
      // Doble chequeo por si acaso
      if (authorData['pais'] == widget.userCountry) {
        feedItems.add({
          'postId': postDoc.id,
          'postData': postData,
          'authorData': authorData,
        });
      }
    }
    return feedItems;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _feedFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error al cargar publicaciones: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('No hay publicaciones para mostrar en tu país.'));
        }

        final feedItems = snapshot.data!;

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {
              _feedFuture = _getFeedData();
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 80),
            itemCount: feedItems.length,
            itemBuilder: (context, index) {
              final item = feedItems[index];
              return PostCard(
                postId: item['postId'],
                postData: item['postData'],
                authorData: item['authorData'],
              );
            },
          ),
        );
      },
    );
  }
}

class _DrawerPerfil extends StatelessWidget {
  final void Function(bool) onThemeChanged;
  final String userRole;

  const _DrawerPerfil({required this.onThemeChanged, required this.userRole});

  Stream<int> _getUnreadCountStream(String tipo, String userId) {
    return FirebaseFirestore.instance
        .collection('notificaciones')
        .where('destinatarioId', isEqualTo: userId)
        .where('leida', isEqualTo: false)
        .where('tipo', isEqualTo: tipo)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  Future<void> _showUpgradeDialog(BuildContext context) async {
    final navigator = Navigator.of(context);

    return showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: Icon(Icons.workspace_premium_outlined, color: Theme.of(context).colorScheme.primary, size: 32),
          title: const Text('Función Premium'),
          content: const Text('Guarda tus precios y servicios para crear presupuestos en segundos. ¡Actualiza tu plan para acceder a esta y otras funciones!'),
          actions: <Widget>[
            TextButton(
              child: const Text('Más Tarde'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            FilledButton(
              child: const Text('Suscribirse Ahora'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                navigator.push(MaterialPageRoute(builder: (context) => const PlanesPage()));
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> showLogoutConfirmationDialog(BuildContext context) async {
    final navigator = Navigator.of(context);
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Confirmar Salida'),
          content: const Text('¿Estás seguro de que quieres cerrar sesión?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancelar'),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
            TextButton(
  child: const Text('Salir'),
  onPressed: () async {
    // PASO 1: Cierra la sesión de Google para que pida la cuenta de nuevo.
    await GoogleSignIn().signOut();

    // PASO 2: Cierra la sesión de Firebase (esto ya lo tenías).
    await FirebaseAuth.instance.signOut();

    // PASO 3: Navega a la pantalla de inicio (esto ya lo tenías).
    navigator.pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (context) => InicioWidget(onThemeChanged: onThemeChanged),
      ),
      (Route<dynamic> route) => false,
    );
  },
),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentUser = FirebaseAuth.instance.currentUser;
    final String currentUserId = currentUser?.uid ?? '';

    return Drawer(
      backgroundColor: colorScheme.surfaceContainer,
      child: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: currentUserId.isNotEmpty ? FirebaseFirestore.instance.collection('usuarios').doc(currentUserId).snapshots() : null,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
            final displayName = userData['display_name'] ?? 'Usuario';
            final photoUrl = userData['photo_url'];
            final rating = (userData['rating'] ?? 0.0).toDouble();
            final ratingCount = userData['ratingCount'] ?? 0;
            final esVerificado = userData['esVerificado'] ?? false;
            final plan = userData['plan'] as String? ?? 'Free';

            Widget planChip;
            if (plan == 'Premium') {
              planChip = Chip(
                avatar: Icon(Icons.workspace_premium, size: 16, color: colorScheme.onPrimary),
                label: Text('Plan: $plan'),
                backgroundColor: colorScheme.primary,
                side: BorderSide.none,
                labelStyle: TextStyle(color: colorScheme.onPrimary, fontWeight: FontWeight.bold),
              );
            } else {
              planChip = Chip(
                avatar: Icon(Icons.person, size: 16, color: colorScheme.primary),
                label: Text('Plan: $plan'),
                backgroundColor: Colors.transparent,
                side: BorderSide(color: colorScheme.primary.withAlpha((255 * 0.5).round())),
                labelStyle: TextStyle(color: colorScheme.primary, fontWeight: FontWeight.w500),
              );
            }

            return ListView(
              padding: EdgeInsets.zero,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 24.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 45,
                        backgroundColor: colorScheme.primaryContainer,
                        backgroundImage: (photoUrl != null && photoUrl.isNotEmpty) ? NetworkImage(photoUrl) : null,
                        child: (photoUrl == null || photoUrl.isEmpty) ? const Icon(Icons.person, size: 45) : null,
                      ),
                      const SizedBox(height: 12),
                      Text(displayName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_rounded, color: Colors.amber.shade700, size: 20),
                          const SizedBox(width: 4),
                          Text('${rating.toStringAsFixed(1)} ($ratingCount reseñas)', style: theme.textTheme.bodyMedium),
                        ],
                      ),
                      const SizedBox(height: 8),
                      planChip,
                    ],
                  ),
                ),
                const Divider(indent: 16, endIndent: 16),
                _buildSectionHeader(context, 'Mi Cuenta'),
                if (!esVerificado) _buildVerificationCta(context),
                _buildDrawerItem(
                    context: context,
                    icon: Icons.settings_outlined,
                    title: 'Configuración',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => SettingsPage(onThemeChanged: onThemeChanged)));
                    }),
                _buildDrawerItem(
                    context: context,
                    icon: Icons.person_outline,
                    title: 'Mi Perfil',
                    onTap: () {
                      Navigator.pop(context);
                      if (currentUserId.isNotEmpty) Navigator.push(context, MaterialPageRoute(builder: (context) => PerfilPaginaWidget(user_id: currentUserId)));
                    }),
                const SizedBox(height: 16),
                _buildSectionHeader(context, 'Navegación'),
                StreamBuilder<int>(
                    stream: _getUnreadCountStream('nuevo_presupuesto', currentUserId),
                    builder: (context, snapshot) {
                      return _buildDrawerItem(
                        context: context,
                        icon: Icons.receipt_long_outlined,
                        title: 'Mis Presupuestos',
                        badgeCount: snapshot.data ?? 0,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MisPresupuestosPage()));
                        },
                      );
                    }),
                StreamBuilder<int>(
                    stream: _getUnreadCountStream('nuevo_contrato', currentUserId),
                    builder: (context, snapshot) {
                      return _buildDrawerItem(
                        context: context,
                        icon: Icons.handshake_outlined,
                        title: 'Mis Contratos',
                        badgeCount: snapshot.data ?? 0,
                        onTap: () {
                          Navigator.pop(context);
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const MisContratosPage()));
                        },
                      );
                    }),
                if (userRole != 'Proveedor')
                AgendaDrawerTile(currentUserId: currentUserId),
    
    if (userRole != 'Proveedor')
                  StreamBuilder<int>(
                      stream: _getUnreadCountStream('nueva_solicitud', currentUserId),
                      builder: (context, snapshot) {
                        return _buildDrawerItem(
                          context: context,
                          icon: Icons.assignment_turned_in_outlined,
                          title: 'Mis Solicitudes',
                          badgeCount: snapshot.data ?? 0,
                          onTap: () {
                            Navigator.pop(context);
                            Navigator.push(context, MaterialPageRoute(builder: (context) => const MisSolicitudesPage()));
                          },
                        );
                      }),
                if (userRole != 'Cliente')
                 /* _buildDrawerItem(
                      context: context,
                      icon: Icons.account_balance_wallet_outlined,
                      title: 'Mi Billetera',
                      onTap: () {
                        Navigator.pop(context);
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const BilleteraPage()));
                      }),*/
                if (userRole != 'Cliente')
                  _buildDrawerItem(
                    context: context,
                    icon: Icons.inventory_2_outlined,
                    title: 'Mis Precios y Servicios',
                    isPremium: true,
                    userPlan: plan,
                    onTap: () {
                      Navigator.pop(context);
                      if (plan == 'Premium'||plan == 'fundador') {
                        Navigator.push(context, MaterialPageRoute(builder: (context) => const MisPreciosServiciosPage()));
                      } else {
                        _showUpgradeDialog(context);
                      }
                    },
                  ),
                _buildDrawerItem(
                    context: context,
                    icon: Icons.bookmark_border_outlined,
                    title: 'Guardados',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedPostsPage()));
                    }),
                _buildDrawerItem(
                    context: context,
                    icon: Icons.workspace_premium_outlined,
                    title: 'Planes',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PlanesPage()));
                    }),
                _buildDrawerItem(
                    context: context,
                    icon: Icons.card_giftcard_outlined,
                    title: 'Promociones y Referidos',
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const PromocionesYReferidosPage()));
                    }),
                const Divider(indent: 16, endIndent: 16, height: 32),
                _buildDrawerItem(
                  context: context,
                  icon: Icons.logout,
                  title: 'Salir',
                  color: colorScheme.error,
                  onTap: () => showLogoutConfirmationDialog(context),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, letterSpacing: 1.5, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  Widget _buildVerificationCta(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
      child: ListTile(
        tileColor: colorScheme.primaryContainer.withAlpha(100),
        leading: Icon(Icons.verified_user_outlined, color: colorScheme.primary),
        title: Text('Verificar mi cuenta', style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.primary)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context);
          Navigator.push(context, MaterialPageRoute(builder: (context) => const VerificacionPage()));
        },
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildDrawerItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
    Color? color,
    int badgeCount = 0,
    bool isPremium = false,
    String? userPlan,
  }) {
    final bool isUserPremium = userPlan == 'Premium';
    return ListTile(
      leading: Badge(
        backgroundColor: Colors.blue.shade700,
        label: Text('$badgeCount'),
        isLabelVisible: badgeCount > 0,
        child: Icon(icon, color: color ?? Theme.of(context).colorScheme.onSurfaceVariant),
      ),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: (isPremium && !isUserPremium)
          ? Chip(
              label: const Text('Premium'),
              labelStyle: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.secondary),
              backgroundColor: Theme.of(context).colorScheme.secondaryContainer.withAlpha((255 * 0.5).round()),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
              side: BorderSide.none,
            )
          : null,
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0),
    );
  }
}

class _CategoryFilters extends StatelessWidget {
  // 1. Ahora recibe la lista de categorías desde afuera.
  final List<String> categories; 
  final String? selectedCategory;
  final Function(String?) onCategorySelected;

  // 2. El constructor se actualiza para requerir la nueva lista.
  const _CategoryFilters({
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // 3. Usa la lista de categorías que llega como parámetro.
        itemCount: categories.length, 
        itemBuilder: (context, index) {
          final category = categories[index];
          // La lógica para determinar si está seleccionado ahora usa el valor que llega de afuera
          final isSelected = category == (selectedCategory ?? 'Todos');
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (selected) {
                // Si se selecciona 'Todos', pasamos null para quitar el filtro.
                // Si se selecciona otra, pasamos esa categoría.
                onCategorySelected(category == 'Todos' ? null : category);
              },
            ),
          );
        },
      ),
    );
  }
}