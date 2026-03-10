import 'dart:async';

import 'package:afit_prueba1/core/app_routes.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/trabajador.dart';
import '../../providers/trabajador_provider.dart';
import '../../providers/departamento_provider.dart';
import 'worker_details_screen.dart';
import 'worker_registration_screen.dart';
import '../../core/app_theme.dart';

class WorkersScreen extends StatefulWidget {
  const WorkersScreen({super.key});

  @override
  State<WorkersScreen> createState() => _WorkersScreenState();
}

class _WorkersScreenState extends State<WorkersScreen>
    with AutomaticKeepAliveClientMixin {
  List<Map<String, dynamic>> _filtrosDepartamentos = [];
  int selectedFilter = 0;
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounceTimer;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatosIniciales();
    });
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) {
      _debounceTimer!.cancel();
    }
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      _buscarTrabajadores(_searchController.text);
    });
  }

  Future<void> _cargarDatosIniciales() async {
    await _cargarTrabajadores();
    await _cargarDepartamentos();
  }

  Future<void> _cargarTrabajadores() async {
    final provider = Provider.of<TrabajadorProvider>(context, listen: false);
    await provider.cargarTrabajadores();
  }

  Future<void> _cargarDepartamentos() async {
    final deptoProvider = Provider.of<DepartamentoProvider>(
      context,
      listen: false,
    );
    await deptoProvider.cargarDepartamentos();

    if (mounted) {
      setState(() {
        _filtrosDepartamentos = [
          {'id': 'todos', 'nombre': 'Todos', 'color': Colors.grey},
          ...deptoProvider.departamentos.map(
            (depto) => {
              'id': depto.id,
              'nombre': depto.nombre,
              'color': _getColorForDepartment(depto.nombre),
            },
          ),
        ];
      });
    }
  }

  Color _getColorForDepartment(String nombre) {
    final colors = {
      'Sistemas': AppTheme.primaryColor,
      'Tecnología de Información': AppTheme.primaryColor,
      'TI': AppTheme.primaryColor,
      'Recursos Humanos': AppTheme.successColor,
      'RRHH': AppTheme.successColor,
      'Finanzas': const Color(0xFF8B5CF6),
      'Marketing': const Color(0xFFEC4899),
      'Ventas': AppTheme.warningColor,
      'Operaciones': AppTheme.errorColor,
      'Logística': const Color(0xFF3B82F6),
      'Producción': const Color(0xFFF97316),
      'Creativo': const Color(0xFFA855F7),
      'Desarrollo': const Color(0xFF6366F1),
      'Soporte': AppTheme.primaryColor,
    };

    return colors[nombre] ?? const Color(0xFF6B7280);
  }

  void _filtrarPorDepartamento(int index) {
    setState(() {
      selectedFilter = index;
    });

    final trabajadorProvider = Provider.of<TrabajadorProvider>(
      context,
      listen: false,
    );

    if (index == 0) {
      trabajadorProvider.cargarTrabajadores();
    } else {
      final deptoId = _filtrosDepartamentos[index]['id'] as String;
      trabajadorProvider.obtenerTrabajadoresPorDepartamento(deptoId).then((
        resultados,
      ) {
        trabajadorProvider.setResultadosBusqueda(resultados);
      });
    }
  }

  void _buscarTrabajadores(String query) async {
    final trabajadorProvider = Provider.of<TrabajadorProvider>(
      context,
      listen: false,
    );

    if (query.isEmpty) {
      if (selectedFilter == 0) {
        await trabajadorProvider.cargarTrabajadores();
      } else {
        final deptoId = _filtrosDepartamentos[selectedFilter]['id'] as String;
        final resultados = await trabajadorProvider
            .obtenerTrabajadoresPorDepartamento(deptoId);
        trabajadorProvider.setResultadosBusqueda(resultados);
      }
    } else {
      final resultados = await trabajadorProvider.buscarTrabajadores(query);
      trabajadorProvider.setResultadosBusqueda(resultados);
    }
  }

  Future<void> _recargarDatos() async {
    await _cargarTrabajadores();
    await _cargarDepartamentos();
  }

  // Método para editar trabajador
  void _editarTrabajador(Trabajador trabajador) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => WorkerRegistrationScreen(trabajador: trabajador),
      ),
    );

    if (result == true && mounted) {
      await _cargarTrabajadores();
      _mostrarExito('Trabajador actualizado correctamente');
    }
  }

  // Método para eliminar trabajador
  void _eliminarTrabajador(BuildContext context, Trabajador trabajador) async {
    // Mostrar diálogo de confirmación
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Trabajador'),
        content: Text(
          '¿Estás seguro de eliminar a ${trabajador.nombres} ${trabajador.apellidos}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Colors.white,
              backgroundColor: AppTheme.errorColor,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmado != true) return;

    try {
      if (!context.mounted) return;

      final provider = Provider.of<TrabajadorProvider>(context, listen: false);
      final exito = await provider.eliminarTrabajador(trabajador.id);

      if (exito && mounted) {
        await _cargarTrabajadores();
        _mostrarExito('Trabajador eliminado correctamente');
      } else if (mounted) {
        _mostrarError(provider.error ?? 'Error al eliminar el trabajador');
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error: $e');
      }
    }
  }

  // Método para cambiar estado

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final primaryColor = AppTheme.primaryColor;
    final backgroundColor = Colors.white;
    final surfaceColor = Colors.white;
    final borderColor = const Color(0xFFE5E7EB);
    final textColor = const Color(0xFF111827);

    final trabajadorProvider = Provider.of<TrabajadorProvider>(context);
    final deptoProvider = Provider.of<DepartamentoProvider>(context);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        backgroundColor: backgroundColor.withValues(alpha: 0.8),
        leading: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () {
              AppRoutes.goBack(context);
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 24,
            ),
          ),
        ),
        title: Text(
          'Trabajadores',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: textColor,
            letterSpacing: -0.3,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _recargarDatos,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black12,
              shape: const CircleBorder(),
            ),
            icon: Icon(Icons.refresh, color: primaryColor, size: 24),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Search Bar
            _buildSearchBar(surfaceColor),

            // Filter Chips
            if (!deptoProvider.cargando && _filtrosDepartamentos.isNotEmpty)
              _buildFilterChips(),

            const SizedBox(height: 8),

            // Workers Header
            _buildWorkersHeader(primaryColor, trabajadorProvider),

            // Workers List
            Expanded(
              child: _buildWorkersContent(
                trabajadorProvider,
                surfaceColor,
                borderColor,
                textColor,
              ),
            ),
          ],
        ),
      ),

      // Floating Action Button
      floatingActionButton: _buildFloatingActionButton(primaryColor),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSearchBar(Color surfaceColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: const Color(0xFFe2e8f0).withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.transparent),
        ),
        child: TextField(
          controller: _searchController,
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search, color: Color(0xFF64748b)),
            hintText: 'Buscar por nombre, DNI o cargo...',
            hintStyle: TextStyle(color: Color(0xFF64748b)),
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 14, color: Colors.black),
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
        itemCount: _filtrosDepartamentos.length,
        itemBuilder: (context, index) {
          final filtro = _filtrosDepartamentos[index];
          final isSelected = selectedFilter == index;
          final color = filtro['color'] as Color;

          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(
                filtro['nombre'] as String,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : const Color(0xFF4B5563),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  _filtrarPorDepartamento(index);
                }
              },
              selectedColor: color,
              backgroundColor: Colors.white,
              elevation: isSelected ? 2 : 0,
              shadowColor: color.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? color : const Color(0xFFE5E7EB),
                  width: isSelected ? 0 : 1,
                ),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              labelStyle: const TextStyle(fontSize: 14),
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkersHeader(Color primaryColor, TrabajadorProvider provider) {
    final totalTrabajadores = provider.trabajadores.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'PERSONAL REGISTRADO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              letterSpacing: 1.0,
            ),
          ),
          Text(
            '$totalTrabajadores ${totalTrabajadores == 1 ? 'Trabajador' : 'Trabajadores'}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersContent(
    TrabajadorProvider provider,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    if (provider.cargando) {
      return const Center(
        child: CircularProgressIndicator(
          color: AppTheme.primaryColor,
          strokeWidth: 2,
        ),
      );
    }

    if (provider.trabajadores.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline,
              size: 64,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              _searchController.text.isEmpty
                  ? 'No hay trabajadores registrados'
                  : 'No se encontraron trabajadores',
              style: const TextStyle(
                fontSize: 16,
                color: Color(0xFF6B7280),
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            if (_searchController.text.isNotEmpty)
              TextButton(
                onPressed: () {
                  _searchController.clear();
                },
                child: const Text('Limpiar búsqueda'),
              ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: AppTheme.primaryColor,
      onRefresh: _recargarDatos,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: provider.trabajadores.length,
        itemBuilder: (context, index) {
          final trabajador = provider.trabajadores[index];
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildWorkerCard(
              trabajador,
              surfaceColor,
              borderColor,
              textColor,
            ),
          );
        },
      ),
    );
  }

  Widget _buildWorkerCard(
    Trabajador trabajador,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    final departmentColor = _getColorForDepartment(
      trabajador.departamentoNombre ?? '',
    );

    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor.withValues(alpha: 0.5), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Column(
        children: [
          // Main content - Clickeable
          GestureDetector(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) =>
                      WorkerDetailScreen(trabajador: trabajador),
                ),
              );
              if (result == true && mounted) {
                await _cargarTrabajadores();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar/Icon Container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: departmentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        trabajador.nombres.isNotEmpty &&
                                trabajador.apellidos.isNotEmpty
                            ? '${trabajador.nombres[0]}${trabajador.apellidos[0]}'
                                  .toUpperCase()
                            : '?',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: departmentColor,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Worker Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${trabajador.nombres} ${trabajador.apellidos}',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textColor,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: trabajador.activo
                                    ? Colors.green
                                    : Colors.red,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              trabajador.activo ? 'ACTIVO' : 'INACTIVO',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: trabajador.activo
                                    ? Colors.green
                                    : Colors.red,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          trabajador.cargo,
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF6B7280),
                          ),
                          maxLines: 1,
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
                                color: departmentColor.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                (trabajador.departamentoNombre ?? 'Sin depto')
                                    .toUpperCase(),
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: departmentColor,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'DNI: ${trabajador.dni}',
                              style: TextStyle(
                                fontSize: 10,
                                color: const Color(0xFF9CA3AF),
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  // Chevron
                  Icon(
                    Icons.chevron_right,
                    color: const Color(0xFF9CA3AF),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),

          // Divider
          Container(
            height: 1,
            color: borderColor.withValues(alpha: 0.5),
            margin: const EdgeInsets.symmetric(horizontal: 16),
          ),

          // Action Buttons - Igual que DepartmentsScreen
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Edit Button
                TextButton.icon(
                  onPressed: () {
                    _editarTrabajador(trabajador);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.primaryColor,
                    backgroundColor: const Color(
                      0xFF135BEC,
                    ).withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(
                    Icons.edit,
                    size: 18,
                    color: AppTheme.primaryColor,
                  ),
                  label: const Text(
                    'Editar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Delete Button
                TextButton.icon(
                  onPressed: () {
                    _eliminarTrabajador(context, trabajador);
                  },
                  style: TextButton.styleFrom(
                    foregroundColor: AppTheme.errorColor,
                    backgroundColor: const Color(
                      0xFFEF4444,
                    ).withValues(alpha: 0.05),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                  ),
                  icon: const Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: AppTheme.errorColor,
                  ),
                  label: const Text(
                    'Eliminar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppTheme.errorColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFloatingActionButton(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => const WorkerRegistrationScreen(),
            ),
          );
          if (result == true && mounted) {
            await _cargarTrabajadores();
            _mostrarExito('Trabajador creado correctamente');
          }
        },
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 8,
        icon: const Icon(Icons.person_add),
        label: const Text(
          'Nuevo Trabajador',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
