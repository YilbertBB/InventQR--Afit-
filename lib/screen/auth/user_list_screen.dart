import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../providers/auth_provider.dart';
import '../../models/usuario.dart';
import 'create_user_screen.dart';
import '../../core/app_theme.dart';

class UserListScreen extends StatefulWidget {
  const UserListScreen({super.key});

  @override
  State<UserListScreen> createState() => _UserListScreenState();
}

class _UserListScreenState extends State<UserListScreen> {
  final List<Map<String, dynamic>> filters = [
    {'label': 'Todos', 'isSelected': true, 'filter': 'todos'},
    {'label': 'Administradores', 'isSelected': false, 'filter': 'admin'},
    {'label': 'Supervisores', 'isSelected': false, 'filter': 'supervisor'},
    {'label': 'Auditores', 'isSelected': false, 'filter': 'auditor'},
    {'label': 'Empleados', 'isSelected': false, 'filter': 'empleado'},
    {'label': 'Activos', 'isSelected': false, 'filter': 'activos'},
    {'label': 'Inactivos', 'isSelected': false, 'filter': 'inactivos'},
  ];

  String _searchQuery = '';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _cargarUsuarios();
  }

  Future<void> _cargarUsuarios() async {
    final authProvider = context.read<AuthProvider>();

    // Solo cargar si la lista está vacía
    if (authProvider.usuarios == null) {
      await authProvider.cargarUsuarios();
    }

    setState(() {
      _isLoading = false;
    });
  }

  List<Usuario> _filtrarUsuarios(List<Usuario> usuarios) {
    final filtroActivo =
        filters.firstWhere(
              (f) => f['isSelected'] == true,
              orElse: () => filters.first,
            )['filter']
            as String;

    var usuariosFiltrados = usuarios.where((usuario) {
      // Filtrar por búsqueda
      final coincideBusqueda =
          _searchQuery.isEmpty ||
          usuario.nombreCompleto.toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          usuario.email.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          usuario.username.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          usuario.rol.toLowerCase().contains(_searchQuery.toLowerCase());

      if (!coincideBusqueda) return false;

      // Filtrar por tipo
      switch (filtroActivo) {
        case 'todos':
          return true;
        case 'admin':
          return usuario.rol == 'admin';
        case 'supervisor':
          return usuario.rol == 'supervisor';
        case 'auditor':
          return usuario.rol == 'auditor';
        case 'empleado':
          return usuario.rol == 'empleado';
        case 'activos':
          return usuario.activo;
        case 'inactivos':
          return !usuario.activo;
        default:
          return true;
      }
    }).toList();

    // Ordenar por nombre
    usuariosFiltrados.sort(
      (a, b) => a.nombreCompleto.compareTo(b.nombreCompleto),
    );

    return usuariosFiltrados;
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'admin':
        return AppTheme.primaryColor;
      case 'supervisor':
        return AppTheme.successColor;
      case 'auditor':
        return AppTheme.warningColor;
      case 'empleado':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'auditor':
        return 'Auditor';
      case 'empleado':
        return 'Empleado';
      default:
        return 'Usuario';
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final usuarioActual = authProvider.usuarioActual;
    final usuarios = authProvider
        .usuarios; // Necesitarás agregar esta propiedad al AuthProvider

    // Si no hay usuarios en el provider, usar lista vacía temporalmente
    final listaUsuarios = usuarios ?? [];
    final usuariosFiltrados = _filtrarUsuarios(listaUsuarios);
    final usuarioActualId = usuarioActual?.id;

    // Verificar permisos - solo admin puede ver la lista de usuarios
    final puedeGestionarUsuarios =
        usuarioActual?.tienePermiso('gestion_usuarios') ?? false;

    if (!puedeGestionarUsuarios && usuarioActual != null) {
      // Redirigir si no tiene permisos
      Future.microtask(() {
        if (!context.mounted) return;
        AppRoutes.goBack(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No tiene permisos para ver usuarios')),
        );
      });
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white.withValues(alpha: 0.95),
        shape: const Border(bottom: BorderSide(color: Color(0xFFE5E7EB))),
        title: const Text(
          'Gestión de Usuarios',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
            letterSpacing: -0.015,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          onPressed: () => AppRoutes.goBack(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 24,
          ),
        ),
      ),
      body: Column(
        children: [
          // Search Bar
          _buildSearchBar(),

          // Filter Chips
          _buildFilterChips(),

          // Estadísticas
          _buildEstadisticas(usuariosFiltrados.length, listaUsuarios.length),

          // User List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : usuariosFiltrados.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    itemCount: usuariosFiltrados.length,
                    itemBuilder: (context, index) {
                      return _buildUserCard(
                        usuariosFiltrados[index],
                        usuarioActualId,
                        puedeGestionarUsuarios,
                        context,
                      );
                    },
                  ),
          ),
        ],
      ),

      // Floating Action Button
      floatingActionButton: puedeGestionarUsuarios
          ? FloatingActionButton(
              onPressed: () => _navegarACrearUsuario(context),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              elevation: 8,
              shape: const CircleBorder(),
              child: const Icon(Icons.add, size: 30),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB), width: 1),
        ),
        child: Row(
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.search, color: Color(0xFF9CA3AF), size: 20),
            ),
            Expanded(
              child: TextField(
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre, correo o rol...',
                  hintStyle: TextStyle(color: Color(0xFF9CA3AF)),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(vertical: 12),
                ),
                style: const TextStyle(color: Color(0xFF1F2937), fontSize: 14),
              ),
            ),
            if (_searchQuery.isNotEmpty)
              IconButton(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
                icon: const Icon(
                  Icons.clear,
                  color: Color(0xFF9CA3AF),
                  size: 20,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filters.length,
        itemBuilder: (context, index) {
          final filter = filters[index];
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                filter['label'] as String,
                style: TextStyle(
                  color: filter['isSelected'] as bool
                      ? Colors.white
                      : const Color(0xFF64748B),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              selected: filter['isSelected'] as bool,
              onSelected: (selected) {
                setState(() {
                  for (var f in filters) {
                    f['isSelected'] = false;
                  }
                  filters[index]['isSelected'] = selected;
                });
              },
              selectedColor: AppTheme.primaryColor,
              backgroundColor: const Color(0xFFF1F5F9),
              side: BorderSide.none,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEstadisticas(int filtrados, int total) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Usuarios encontrados: $filtrados',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1F2937),
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Total en sistema: $total',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 12),
              ),
            ],
          ),
          if (filtrados < total)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                'Filtrado',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserCard(
    Usuario usuario,
    String? usuarioActualId,
    bool puedeGestionarUsuarios,
    BuildContext context,
  ) {
    final esUsuarioActual = usuario.id == usuarioActualId;
    final puedeEditar = puedeGestionarUsuarios || esUsuarioActual;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: esUsuarioActual
              ? AppTheme.primaryColor
              : const Color(0xFFE5E7EB),
          width: esUsuarioActual ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Avatar
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _getRoleColor(usuario.rol).withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: _getRoleColor(usuario.rol).withValues(alpha: 0.3),
                  width: 2,
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.person,
                  color: _getRoleColor(usuario.rol),
                  size: 32,
                ),
              ),
            ),

            const SizedBox(width: 16),

            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          usuario.nombreCompleto,
                          style: const TextStyle(
                            color: Color(0xFF1F2937),
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (esUsuarioActual)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFF2B8CEE,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Tú',
                            style: TextStyle(
                              color: AppTheme.primaryColor,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 4),

                  Text(
                    usuario.email,
                    style: const TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),

                  const SizedBox(height: 8),

                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRoleColor(
                            usuario.rol,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          _getRoleName(usuario.rol),
                          style: TextStyle(
                            color: _getRoleColor(usuario.rol),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: usuario.activo
                              ? AppTheme.successColor.withValues(alpha: 0.1)
                              : AppTheme.errorColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          usuario.activo ? 'Activo' : 'Inactivo',
                          style: TextStyle(
                            color: usuario.activo
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),

                      // if (usuario.departamento != null &&
                      //     usuario.departamento!.isNotEmpty)
                      //   Padding(
                      //     padding: const EdgeInsets.only(left: 8),
                      //     child: Text(
                      //       '• ${usuario.departamento!}',
                      //       style: const TextStyle(
                      //         color: Color(0xFF6B7280),
                      //         fontSize: 12,
                      //       ),
                      //     ),
                      //   ),
                    ],
                  ),
                ],
              ),
            ),

            // Action buttons
            Column(
              children: [
                if (puedeEditar)
                  IconButton(
                    onPressed: () => _navegarAEditarUsuario(context, usuario),
                    icon: const Icon(Icons.edit, size: 20),
                    color: const Color(0xFF6B7280),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFF1F5F9),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                if (puedeGestionarUsuarios && !esUsuarioActual)
                  IconButton(
                    onPressed: () => _mostrarDialogoEliminar(context, usuario),
                    icon: const Icon(Icons.delete, size: 20),
                    color: AppTheme.errorColor,
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFFEE2E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.group_off, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text(
            'No se encontraron usuarios',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Intenta con otro filtro o agrega un nuevo usuario',
            style: TextStyle(color: Color(0xFF9CA3AF)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _navegarACrearUsuario(context),
            icon: const Icon(Icons.add),
            label: const Text('Agregar Primer Usuario'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  void _navegarACrearUsuario(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CreateEditUserScreen(esModoEdicion: false),
      ),
    );
  }

  void _navegarAEditarUsuario(BuildContext context, Usuario usuario) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            CreateEditUserScreen(esModoEdicion: true, usuarioAEditar: usuario),
      ),
    );
  }

  void _mostrarDialogoEliminar(BuildContext context, Usuario usuario) {
    // OBTENER LAS REFERENCIAS ANTES DEL DIÁLOGO
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Gestionar Usuario'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Qué acción desea realizar con este usuario?'),
            const SizedBox(height: 12),
            Text('Nombre: ${usuario.nombreCompleto}'),
            Text('Correo: ${usuario.email}'),
            Text('Rol: ${_getRoleName(usuario.rol)}'),
            const SizedBox(height: 16),
            const Text(
              'Seleccione una opción:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () async {
              Navigator.pop(context);
              await _desactivarUsuarioDirecto(
                authProvider,
                scaffoldMessenger,
                usuario,
              );
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
            child: const Text('Desactivar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.pop(context);
              await _eliminarUsuarioDirecto(
                authProvider,
                scaffoldMessenger,
                usuario,
              );
            },
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  // Métodos auxiliares que reciben las referencias como parámetros
  Future<void> _desactivarUsuarioDirecto(
    AuthProvider authProvider,
    ScaffoldMessengerState scaffoldMessenger,
    Usuario usuario,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Desactivar Usuario'),
        content: Text(
          '¿Está seguro de desactivar a ${usuario.nombreCompleto}? '
          'El usuario no podrá iniciar sesión hasta que sea reactivado.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final exitoso = await authProvider.desactivarUsuario(usuario.id);

      if (exitoso) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('${usuario.nombreCompleto} desactivado exitosamente'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              authProvider.errorMensaje ?? 'Error al desactivar usuario',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _eliminarUsuarioDirecto(
    AuthProvider authProvider,
    ScaffoldMessengerState scaffoldMessenger,
    Usuario usuario,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.dangerous, color: Colors.red),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Eliminar Usuario Permanente',
                maxLines: 2,
                softWrap: true,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '¿Está completamente seguro de ELIMINAR PERMANENTEMENTE este usuario?',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text('Nombre: ${usuario.nombreCompleto}'),
            Text('Correo: ${usuario.email}'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '⚠️ ADVERTENCIA CRÍTICA:',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '• Todos los datos del usuario serán eliminados permanentemente',
                    style: TextStyle(fontSize: 12),
                  ),
                  Text(
                    '• Esta acción NO se puede deshacer',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '• El usuario no podrá ser recuperado',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ELIMINAR PERMANENTEMENTE'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final exitoso = await authProvider.eliminarUsuario(usuario.id);

      if (exitoso) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              '${usuario.nombreCompleto} eliminado permanentemente',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text(
              authProvider.errorMensaje ?? 'Error al eliminar usuario',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }
}
