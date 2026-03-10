import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../models/departamento.dart';
import '../../models/asignacion.dart';
import '../../models/traslado.dart';
import '../../models/revision.dart';
import '../../providers/departamento_provider.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/asignacion_provider.dart';
import '../../providers/traslado_provider.dart';
import '../../providers/revision_provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/excel_export_service.dart';
import '../../widgets/root_guard.dart';
import '../../mixins/root_aware_mixin.dart';
import '../auth/create_user_screen.dart';
import '../departments/inventorydepartemnt.dart';
import '../../core/app_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with RootAwareMixin {
  final bool _darkMode = false;
  final int _selectedNavIndex = 0;

  // Variables para animación de botones
  bool _importPressed = false;
  bool _exportPressed = false;

  // Variables para datos
  List<Departamento> _departamentos = [];
  List<Map<String, dynamic>> _actividadesRecientes = [];
  bool _cargando = true;

  // Métricas de equipos
  int _totalEquipos = 0;
  int _equiposAsignados = 0;
  int _equiposDisponibles = 0;

  // Métricas de revisiones
  int _totalRevisiones = 0;
  int _revisionesCompletadas = 0;
  int _departamentosAuditados = 0;
  List<Revision> revisionesRecientes = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos(context);
    });
  }

  Future<void> _cargarDatos(BuildContext context) async {
    try {
      if (context.mounted) {}
      // Cargar departamentos
      final deptoProvider = Provider.of<DepartamentoProvider>(
        context,
        listen: false,
      );
      await deptoProvider.cargarDepartamentos();
      if (!context.mounted) return;

      // Cargar equipos
      final equipoProvider = Provider.of<EquipoProvider>(
        context,
        listen: false,
      );
      await equipoProvider.cargarEquipos();
      if (!context.mounted) return;

      // Cargar asignaciones
      final asignacionProvider = Provider.of<AsignacionProvider>(
        context,
        listen: false,
      );
      await asignacionProvider.cargarHistorialAsignaciones();
      if (!context.mounted) return;

      // Cargar traslados
      final trasladoProvider = Provider.of<TrasladoProvider>(
        context,
        listen: false,
      );
      await trasladoProvider.cargarHistorialTraslados();
      if (!context.mounted) return;

      // Cargar revisiones
      final revisionProvider = Provider.of<RevisionProvider>(
        context,
        listen: false,
      );
      await revisionProvider.cargarHistorialRevisiones();

      if (mounted) {
        setState(() {
          _cargando = false;
          _departamentos = deptoProvider.departamentos;
          _totalEquipos = equipoProvider.equipos.length;
          _equiposAsignados = equipoProvider.equipos
              .where((e) => e.estaAsignado)
              .length;
          _equiposDisponibles = _totalEquipos - _equiposAsignados;

          // Métricas de revisiones
          _totalRevisiones = revisionProvider.historialRevisiones.length;
          _revisionesCompletadas = revisionProvider.historialRevisiones
              .where((r) => r.estaCompletada)
              .length;

          // Departamentos únicos auditados
          _departamentosAuditados = revisionProvider.historialRevisiones
              .map((r) => r.departamentoId)
              .toSet()
              .length;

          revisionesRecientes = revisionProvider.historialRevisiones
              .take(3)
              .toList();

          // Combinar actividades recientes
          _actividadesRecientes = _obtenerActividadesRecientes(
            asignacionProvider.historialAsignaciones,
            trasladoProvider.historialTraslados,
            revisionProvider.historialRevisiones,
          );
        });
      }
    } catch (e) {
      debugPrint('Error cargando dashboard: $e');
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Future<void> _exportarInventario() async {
    // Verificar permisos para root
    if (!verificarAccionRoot(context, 'exportar')) {
      return;
    }

    final provider = Provider.of<EquipoProvider>(context, listen: false);

    if (provider.equipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay equipos para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await ExcelExportService.exportarYCompartir(
      equipos: provider.equipos,
      context: context,
    );
  }

  List<Map<String, dynamic>> _obtenerActividadesRecientes(
    List<Asignacion> asignaciones,
    List<Traslado> traslados,
    List<Revision> revisiones,
  ) {
    final List<Map<String, dynamic>> actividades = [];

    // Agregar asignaciones
    for (var a in asignaciones) {
      actividades.add({
        'tipo': 'asignacion',
        'id': a.id,
        'fecha': a.fechaAsignacion,
        'titulo': 'Equipo asignado',
        'descripcion': '${a.equipoNombre} → ${a.trabajadorNombre}',
        'usuario': a.usuarioAsignadorNombre ?? a.usuarioAsignadorId,
        'icono': Icons.person_add,
        'color': Colors.green,
      });
    }

    // Agregar traslados
    for (var t in traslados) {
      actividades.add({
        'tipo': 'traslado',
        'id': t.id,
        'fecha': t.fechaTraslado,
        'titulo': 'Equipo trasladado',
        'descripcion':
            '${t.equipoNombre}: ${t.desdeDepartamentoNombre} → ${t.haciaDepartamentoNombre}',
        'usuario': t.usuarioRealizadorNombre ?? t.usuarioRealizadorId,
        'icono': Icons.swap_horiz,
        'color': AppTheme.primaryColor,
      });
    }

    // Agregar revisiones
    for (var r in revisiones) {
      String titulo;
      Color color;
      IconData icono;

      if (r.estaCompletada) {
        titulo = 'Revisión completada';
        color = Colors.green;
        icono = Icons.inventory;
      } else if (r.estaEnCurso) {
        titulo = 'Revisión en curso';
        color = AppTheme.warningColor;
        icono = Icons.pending;
      } else {
        titulo = 'Revisión cancelada';
        color = Colors.red;
        icono = Icons.cancel;
      }

      actividades.add({
        'tipo': 'revision',
        'id': r.id,
        'fecha': r.fechaRevision,
        'titulo': titulo,
        'descripcion':
            '${r.departamentoNombre}: ${r.equiposCorrectos}/${r.totalEquipos} correctos',
        'usuario': r.usuarioAuditorNombre ?? 'Administrador',
        'icono': icono,
        'color': color,
        'estado': r.estado,
      });
    }

    // Ordenar por fecha (más reciente primero)
    actividades.sort((a, b) {
      final fechaA = a['fecha'] as DateTime;
      final fechaB = b['fecha'] as DateTime;
      return fechaB.compareTo(fechaA);
    });

    // Devolver solo las 5 más recientes
    return actividades.take(5).toList();
  }

  String _formatoFecha(DateTime fecha) {
    final now = DateTime.now();
    final difference = now.difference(fecha);

    if (difference.inDays > 0) {
      return 'Hace ${difference.inDays} día${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return 'Hace ${difference.inHours} hora${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return 'Hace ${difference.inMinutes} min';
    } else {
      return 'Hace un momento';
    }
  }

  void _navegarConPermiso(
    String ruta, {
    String accion = 'navegar_sin_modificar',
    Departamento? departamento,
  }) {
    if (verificarAccionRoot(context, accion)) {
      switch (ruta) {
        case 'inventory':
          AppRoutes.goToInventory(context);
          break;
        case 'departments':
          AppRoutes.goToDepartments(context);
          break;
        case 'workers':
          AppRoutes.goToWorkers(context);
          break;
        case 'scanner':
          AppRoutes.goToScanner(context);
          break;
        case 'profile':
          AppRoutes.goToProfile(context);
          break;
        case 'import':
          AppRoutes.goToImportExcel(context);
          break;
        case 'inventoryDepartments':
          if (departamento == null) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  InventoryDepartments(departamento: departamento),
            ),
          );
          break;
        default:
          AppRoutes.goToDashboard(context);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final esRoot = authProvider.esUsuarioRoot;
    return RootGuard(
      child: Theme(
        data: _darkMode
            ? Theme.of(context).copyWith(brightness: Brightness.dark)
            : Theme.of(context).copyWith(brightness: Brightness.light),
        child: Scaffold(
          backgroundColor: AppTheme.backgroundColorLight,
          appBar: AppBar(
            backgroundColor: Colors.white.withValues(alpha: 0.8),
            leading: Container(
              margin: const EdgeInsets.all(8),
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.inventory_2,
                color: AppTheme.primaryColor,
                size: 24,
              ),
            ),
            title: Text(
              esRoot ? 'Configuración Inicial' : 'Panel de Activos',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: _darkMode ? Colors.white : Colors.black,
              ),
            ),
            actions: [
              GestureDetector(
                onTap: () =>
                    _navegarConPermiso('profile', accion: 'ver_perfil'),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: _darkMode
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFE2E8F0),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.account_circle, color: Colors.grey),
                ),
              ),
            ],
          ),
          body: SafeArea(
            child: _cargando
                ? const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        AppTheme.primaryColor,
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () => _cargarDatos(context),
                    color: AppTheme.primaryColor,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: esRoot
                          ? _buildRootDashboard(context)
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildSummarySection(),
                                const SizedBox(height: 16),
                                _buildAuditSummarySection(),
                                const SizedBox(height: 24),
                                _buildExcelActions(),
                                const SizedBox(height: 32),
                                _buildDepartmentsHeader(),
                                const SizedBox(height: 16),
                                _buildDepartmentGrid(),
                                const SizedBox(height: 32),
                                _buildActivitysHeader(),
                                const SizedBox(height: 16),
                                _buildRecentActivity(),
                              ],
                            ),
                    ),
                  ),
          ),
          bottomNavigationBar: _buildBottomNavBar(),
          floatingActionButton: esRoot
              ? null
              : FloatingActionButton(
                  onPressed: () async {
                    await AppRoutes.goToScanner(context);

                    if (!context.mounted) return;

                    final provider = context.read<EquipoProvider>();

                    provider.limpiarFiltros();
                    await provider.cargarEquipos();
                  },
                  backgroundColor: AppTheme.primaryColor,
                  elevation: 8,
                  shape: const CircleBorder(),
                  child: const Icon(
                    Icons.qr_code_scanner,
                    size: 30,
                    color: Colors.white,
                  ),
                ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
        ),
      ),
    );
  }

  // Dashboard especial para root
  Widget _buildRootDashboard(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final tieneUsuarios = (authProvider.usuarios?.length ?? 1) > 1;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.admin_panel_settings,
            size: 80,
            color: AppTheme.primaryColor,
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Configuración Inicial del Sistema',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            tieneUsuarios
                ? 'Ya existen usuarios en el sistema. Por seguridad, el usuario root debe cerrar sesión.'
                : 'Bienvenido al sistema de inventario. Como usuario root, solo puede crear el primer usuario administrador para configurar el sistema.',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6B7280),
              height: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 32),

        if (!tieneUsuarios) ...[
          ElevatedButton.icon(
            onPressed: () {
              if (verificarAccionRoot(context, 'crear_primer_usuario')) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        const CreateEditUserScreen(esModoEdicion: false),
                  ),
                ).then((_) {
                  if (!context.mounted) return;

                  _cargarDatos(context);
                });
              }
            },
            icon: const Icon(Icons.person_add),
            label: const Text('Crear Primer Administrador'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              minimumSize: const Size(250, 56),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        OutlinedButton.icon(
          onPressed: () {
            final authProvider = Provider.of<AuthProvider>(
              context,
              listen: false,
            );
            authProvider.logout();
            AppRoutes.goToLogin(context);
          },
          icon: const Icon(Icons.logout),
          label: const Text('Cerrar Sesión'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.red,
            side: const BorderSide(color: Colors.red),
            minimumSize: const Size(250, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),

        if (tieneUsuarios) ...[
          const SizedBox(height: 24),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.orange),
            ),
            child: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'El usuario root ha sido desactivado por seguridad. Inicie sesión con un administrador.',
                    style: TextStyle(color: Colors.orange),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSummarySection() {
    final double porcentaje = _totalEquipos > 0
        ? (_equiposAsignados / _totalEquipos) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _darkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Inventario de Equipos',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _darkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${porcentaje.toStringAsFixed(1)}% ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _darkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: 'Asignado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.successColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_equiposAsignados de $_totalEquipos',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: _darkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: porcentaje / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_equiposAsignados Asignados',
                    style: TextStyle(
                      fontSize: 12,
                      color: _darkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(Icons.pending, size: 14, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    '$_equiposDisponibles Disponibles',
                    style: TextStyle(
                      fontSize: 12,
                      color: _darkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAuditSummarySection() {
    final double porcentajeRevisiones = _totalRevisiones > 0
        ? (_revisionesCompletadas / _totalRevisiones) * 100
        : 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _darkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.inventory_2,
                        size: 18,
                        color: AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Revisiones Físicas',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: _darkMode
                              ? const Color(0xFF94A3B8)
                              : const Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${porcentajeRevisiones.toStringAsFixed(1)}% ',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _darkMode ? Colors.white : Colors.black,
                          ),
                        ),
                        TextSpan(
                          text: 'Completado',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.normal,
                            color: const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '$_revisionesCompletadas de $_totalRevisiones',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 8,
            decoration: BoxDecoration(
              color: _darkMode
                  ? const Color(0xFF1E293B)
                  : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: porcentajeRevisiones / 100,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                  const SizedBox(width: 4),
                  Text(
                    '$_revisionesCompletadas Completadas',
                    style: TextStyle(
                      fontSize: 12,
                      color: _darkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  const Icon(
                    Icons.account_balance,
                    size: 14,
                    color: AppTheme.primaryColor,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$_departamentosAuditados Departamentos',
                    style: TextStyle(
                      fontSize: 12,
                      color: _darkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildExcelActions() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () => _navegarConPermiso('import', accion: 'importar'),
            onTapDown: (_) => _scaleDownImport(),
            onTapUp: (_) => _scaleUpImport(),
            onTapCancel: _scaleUpImport,
            child: AnimatedScale(
              scale: _importPressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _darkMode
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.upload_file, color: AppTheme.primaryColor),
                    const SizedBox(width: 8),
                    Text(
                      'Importar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: GestureDetector(
            onTap: () {
              if (verificarAccionRoot(context, 'exportar')) {
                _showExportOptions(context);
              }
            },
            onTapDown: (_) => _scaleDownExport(),
            onTapUp: (_) => _scaleUpExport(),
            onTapCancel: _scaleUpExport,
            child: AnimatedScale(
              scale: _exportPressed ? 0.95 : 1.0,
              duration: const Duration(milliseconds: 100),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 16,
                ),
                decoration: BoxDecoration(
                  color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _darkMode
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.download_for_offline,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Exportar',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentsHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Departamentos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkMode ? Colors.white : Colors.black,
          ),
        ),
        TextButton(
          onPressed: () => _navegarConPermiso('departments'),
          child: Text(
            'VER TODOS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDepartmentGrid() {
    final departamentosMostrar = _departamentos.take(4).toList();

    if (departamentosMostrar.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _darkMode
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(
          child: Text(
            'No hay departamentos registrados',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.0,
      ),
      itemCount: departamentosMostrar.length,
      itemBuilder: (context, index) {
        final departamento = departamentosMostrar[index];
        return _buildDepartmentCard(departamento);
      },
    );
  }

  Widget _buildDepartmentCard(Departamento departamento) {
    IconData icono;
    Color colorIcono;

    final nombre = departamento.nombre.toLowerCase();

    if (nombre.contains('ti') ||
        nombre.contains('soporte') ||
        nombre.contains('tecnologia')) {
      icono = Icons.computer;
      colorIcono = AppTheme.primaryColor;
    } else if (nombre.contains('desarrollo') || nombre.contains('software')) {
      icono = Icons.code;
      colorIcono = const Color(0xFF8B5CF6);
    } else if (nombre.contains('rrhh') ||
        nombre.contains('recursos') ||
        nombre.contains('humanos')) {
      icono = Icons.groups;
      colorIcono = AppTheme.successColor;
    } else if (nombre.contains('ventas') || nombre.contains('marketing')) {
      icono = Icons.trending_up;
      colorIcono = AppTheme.warningColor;
    } else if (nombre.contains('finanzas') || nombre.contains('contabilidad')) {
      icono = Icons.attach_money;
      colorIcono = const Color(0xFF3B82F6);
    } else {
      icono = Icons.business;
      colorIcono = const Color(0xFF6B7280);
    }

    return GestureDetector(
      onTap: () => _navegarConPermiso(
        'inventoryDepartments',
        departamento: departamento,
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _darkMode
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: colorIcono.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icono, color: colorIcono),
            ),
            const SizedBox(height: 12),
            Text(
              departamento.nombre,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: _darkMode ? Colors.white : Colors.black,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${departamento.cantidadEquiposAsignados} activos',
              style: TextStyle(fontSize: 12, color: const Color(0xFF94A3B8)),
            ),
            const SizedBox(height: 2),
            Text(
              '${departamento.cantidadPersonal} personas',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: colorIcono,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivitysHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Actividad Reciente',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: _darkMode ? Colors.white : Colors.black,
          ),
        ),
        TextButton(
          onPressed: () {
            AppRoutes.goToHistoryActivity(context);
          },
          child: Text(
            'VER TODOS',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppTheme.primaryColor,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRecentActivity() {
    if (_actividadesRecientes.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _darkMode
                ? const Color(0xFF334155)
                : const Color(0xFFE2E8F0),
          ),
        ),
        child: const Center(
          child: Text(
            'No hay actividad reciente',
            style: TextStyle(color: Color(0xFF64748B)),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ..._actividadesRecientes.map((actividad) {
          return _buildActivityItem(actividad);
        }),
      ],
    );
  }

  Widget _buildActivityItem(Map<String, dynamic> actividad) {
    final fecha = actividad['fecha'] as DateTime;
    final color = actividad['color'] as Color;
    final icono = actividad['icono'] as IconData;
    final titulo = actividad['titulo'] as String;
    final descripcion = actividad['descripcion'] as String;
    final usuario = actividad['usuario'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: _darkMode ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icono, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _darkMode
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _formatoFecha(fecha),
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  descripcion,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 10,
                      color: Color(0xFF94A3B8),
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        'por $usuario',
                        style: const TextStyle(
                          fontSize: 10,
                          color: Color(0xFF94A3B8),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNavBar() {
    final authProvider = Provider.of<AuthProvider>(context);
    final esRoot = authProvider.esUsuarioRoot;

    return BottomAppBar(
      height: 60,
      padding: const EdgeInsets.only(top: 10),
      color: _darkMode
          ? const Color(0xFF101622).withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.95),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavButton(
            icon: Icons.dashboard,
            label: 'Inicio',
            isActive: _selectedNavIndex == 0,
            onTap: () => _navegarConPermiso('dashboard'),
            esRoot: esRoot,
          ),
          _buildNavButton(
            icon: Icons.list_alt,
            label: 'Inventario',
            isActive: _selectedNavIndex == 1,
            onTap: () => _navegarConPermiso('inventory'),
            esRoot: esRoot,
          ),
          _buildNavButton(
            icon: Icons.business,
            label: 'Departamentos',
            isActive: _selectedNavIndex == 2,
            onTap: () => _navegarConPermiso('departments'),
            esRoot: esRoot,
          ),
          _buildNavButton(
            icon: Icons.person_rounded,
            label: 'Trabajadores',
            isActive: _selectedNavIndex == 3,
            onTap: () => _navegarConPermiso('workers'),
            esRoot: esRoot,
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
    required bool esRoot,
  }) {
    return GestureDetector(
      onTap: esRoot ? null : onTap, // Root no puede navegar
      child: Opacity(
        opacity: esRoot ? 0.5 : 1.0,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isActive ? AppTheme.primaryColor : const Color(0xFF94A3B8),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
                color: isActive
                    ? AppTheme.primaryColor
                    : const Color(0xFF94A3B8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _scaleDownImport() {
    setState(() => _importPressed = true);
  }

  void _scaleUpImport() {
    setState(() => _importPressed = false);
  }

  void _scaleDownExport() {
    setState(() => _exportPressed = true);
  }

  void _scaleUpExport() {
    setState(() => _exportPressed = false);
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Exportar Inventario',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _darkMode ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 20),

              ListTile(
                leading: const Icon(
                  Icons.table_chart,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Exportar a Excel'),
                onTap: () {
                  Navigator.pop(context);
                  _exportarInventario();
                },
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        );
      },
    );
  }
}
