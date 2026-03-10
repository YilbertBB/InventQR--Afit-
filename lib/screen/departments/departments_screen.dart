import 'package:afit_prueba1/screen/departments/inventorydepartemnt.dart';
import 'package:provider/provider.dart';

import '../../core/app_routes.dart';
import 'package:flutter/material.dart';
import '../../models/departamento.dart';
import '../../providers/departamento_provider.dart';
import '../../core/app_theme.dart';

class DepartmentsScreen extends StatefulWidget {
  const DepartmentsScreen({super.key});

  @override
  State<DepartmentsScreen> createState() => _DepartmentsScreenState();
}

class _DepartmentsScreenState extends State<DepartmentsScreen> {
  final TextEditingController _searchController = TextEditingController();

  List<Departamento> _departamentos = [];
  List<Departamento> _departamentosFiltrados = [];
  bool cargando = true;
  String? error;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDepartamentos();
    });

    _searchController.addListener(_filtrarDepartamentos);
  }

  Future<void> _cargarDepartamentos() async {
    try {
      setState(() {
        cargando = true;
        error = null;
      });

      // ✅ USAR EL PROVIDER
      final provider = Provider.of<DepartamentoProvider>(
        context,
        listen: false,
      );

      await provider.cargarDepartamentos();

      if (mounted) {
        setState(() {
          // ✅ provider.departamentos YA FILTRA 'sin-departamento'
          _departamentos = provider.departamentos;
          _departamentosFiltrados = provider.departamentos;
          cargando = false;
        });
      }
    } catch (e) {
      setState(() {
        error = 'Error al cargar departamentos: $e';
        cargando = false;
      });
    }
  }

  void _filtrarDepartamentos() {
    final busqueda = _searchController.text.toLowerCase().trim();

    if (busqueda.isEmpty) {
      setState(() {
        _departamentosFiltrados = _departamentos;
      });
      return;
    }

    final filtrados = _departamentos.where((departamento) {
      return departamento.nombre.toLowerCase().contains(busqueda);
    }).toList();

    setState(() {
      _departamentosFiltrados = filtrados;
    });
  }

  Future<void> _eliminarDepartamento(
    BuildContext context,
    Departamento departamento,
  ) async {
    // Mostrar diálogo de confirmación
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Departamento'),
        content: Text(
          '¿Estás seguro de eliminar el departamento "${departamento.nombre}"?\n\n'
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
      // ✅ USAR EL PROVIDER EN VEZ DE DB DIRECTA
      if (!context.mounted) return;

      final provider = Provider.of<DepartamentoProvider>(
        context,
        listen: false,
      );

      final exito = await provider.eliminarDepartamento(departamento.id);

      if (exito) {
        _mostrarExito('Departamento eliminado exitosamente');
        // La lista ya se recarga automáticamente en el provider
      } else {
        _mostrarError('Error al eliminar departamento');
      }
    } catch (e) {
      _mostrarError('Error al eliminar departamento: $e');
    }
  }

  void _editarDepartamento(Departamento departamento) {
    _mostrarModalDepartamento(departamento: departamento);
  }

  // Crear nuevo departamento con BottomSheet
  void _crearNuevoDepartamento() {
    _mostrarModalDepartamento();
  }

  void _mostrarModalDepartamento({Departamento? departamento}) {
    final nombreController = TextEditingController();
    bool guardando = false;
    final esEdicion = departamento != null;
    if (esEdicion) {
      nombreController.text = departamento.nombre;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            left: 16,
            right: 16,
            top: 16,
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
          ),
          child: StatefulBuilder(
            builder: (context, setModalState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.apartment, color: AppTheme.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        esEdicion
                            ? 'Editar Departamento'
                            : 'Nuevo Departamento',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        onPressed: guardando
                            ? null
                            : () => Navigator.pop(sheetContext),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nombreController,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Nombre del departamento',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      onPressed: guardando
                          ? null
                          : () async {
                              final nombre = nombreController.text.trim();

                              if (nombre.isEmpty) {
                                _mostrarError(
                                  'El nombre del departamento es obligatorio',
                                );
                                return;
                              }
                              if (nombre.length < 3) {
                                _mostrarError(
                                  'El nombre debe tener al menos 3 caracteres',
                                );
                                return;
                              }
                              if (nombre.length > 50) {
                                _mostrarError(
                                  'El nombre no puede exceder los 50 caracteres',
                                );
                                return;
                              }

                              setModalState(() => guardando = true);

                              final provider =
                                  Provider.of<DepartamentoProvider>(
                                    context,
                                    listen: false,
                                  );

                              final ok = esEdicion
                                  ? await provider.actualizarDepartamento(
                                      departamento.copyWith(nombre: nombre),
                                    )
                                  : await provider.crearDepartamento(nombre);

                              if (!mounted) return;
                              if (!sheetContext.mounted) return;

                              setModalState(() => guardando = false);

                              if (ok) {
                                Navigator.pop(sheetContext);
                                _mostrarExito(
                                  esEdicion
                                      ? 'Departamento actualizado'
                                      : 'Departamento creado',
                                );
                                _cargarDepartamentos();
                              } else {
                                _mostrarError(
                                  provider.error ??
                                      (esEdicion
                                          ? 'No se pudo actualizar el departamento'
                                          : 'No se pudo crear el departamento'),
                                );
                              }
                            },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: guardando
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : Text(
                              esEdicion
                                  ? 'Guardar cambios'
                                  : 'Crear departamento',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  void _mostrarExito(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.green),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final backgroundColor = Colors.white;
    final surfaceColor = Colors.white;
    final borderColor = const Color(0xFFE5E7EB);
    final textColor = const Color(0xFF111827);

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
          'Departamentos',
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
            onPressed: _cargarDepartamentos,
            style: IconButton.styleFrom(
              backgroundColor: Colors.black12,
              shape: const CircleBorder(),
              padding: const EdgeInsets.all(8),
            ),
            icon: Icon(Icons.refresh, color: textColor, size: 20),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(surfaceColor),
            _buildDepartmentsHeader(primaryColor),
            Expanded(
              child: Consumer<DepartamentoProvider>(
                builder: (context, provider, child) {
                  if (provider.cargando) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (provider.error != null) {
                    return _buildErrorView(provider.error!);
                  }

                  // Filtrar por búsqueda
                  final busqueda = _searchController.text.toLowerCase().trim();
                  final departamentosFiltrados = busqueda.isEmpty
                      ? provider.departamentos
                      : provider.departamentos
                            .where(
                              (d) => d.nombre.toLowerCase().contains(busqueda),
                            )
                            .toList();

                  if (departamentosFiltrados.isEmpty) {
                    return _buildEmptyView(busqueda.isNotEmpty);
                  }

                  return _buildDepartmentsList(
                    surfaceColor,
                    borderColor,
                    textColor,
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _buildFloatingActionButton(primaryColor),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  // Agrega estos métodos después de _buildDepartmentsHeader

  Widget _buildEmptyView(bool busquedaActiva) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              busquedaActiva ? Icons.search_off : Icons.work_off,
              size: 64,
              color: const Color(0xFF9CA3AF),
            ),
            const SizedBox(height: 16),
            Text(
              busquedaActiva
                  ? 'No se encontraron departamentos'
                  : 'No hay departamentos registrados',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Color(0xFF4B5563),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              busquedaActiva
                  ? 'Intenta con otros términos de búsqueda'
                  : 'Crea tu primer departamento con el botón +',
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            if (busquedaActiva) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () {
                  _searchController.clear();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Limpiar búsqueda'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView(String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            const Text(
              'Error al cargar departamentos',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _cargarDepartamentos,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
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
            hintText: 'Buscar departamento...',
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

  Widget _buildDepartmentsHeader(Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'DEPARTAMENTOS ACTUALES',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF6B7280),
              letterSpacing: 1.0,
            ),
          ),
          Text(
            '${_departamentosFiltrados.length} Total',
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

  Widget _buildDepartmentsList(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        itemCount: _departamentosFiltrados.length,
        itemBuilder: (context, index) {
          final departamento = _departamentosFiltrados[index];
          return _buildDepartmentCard(
            departamento,
            surfaceColor,
            borderColor,
            textColor,
            () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return InventoryDepartments(departamento: departamento);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  // Solo la parte del método _buildDepartmentCard que muestra la información
  Widget _buildDepartmentCard(
    Departamento departamento,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    VoidCallback ontap,
  ) {
    return GestureDetector(
      onTap: ontap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: borderColor.withValues(alpha: 0.5),
            width: 1,
          ),
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
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon Container
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _obtenerColorFondoPorDepartamento(departamento),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _obtenerIconoPorDepartamento(departamento),
                      color: _obtenerColorIconoPorDepartamento(departamento),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),

                  // Department Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          departamento.nombre,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),

                        // Información de equipos y personal
                        if (departamento.cantidadEquiposAsignados > 0 ||
                            departamento.cantidadPersonal > 0)
                          Text(
                            '${departamento.cantidadEquiposAsignados} equipos • ${departamento.cantidadPersonal} personas',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF6B7280),
                            ),
                          )
                        else
                          Text(
                            'Sin asignaciones',
                            style: TextStyle(
                              fontSize: 13,
                              color: const Color(
                                0xFF6B7280,
                              ).withValues(alpha: 0.6),
                              fontStyle: FontStyle.italic,
                            ),
                          ),

                        // ID del departamento (pequeño)
                        const SizedBox(height: 2),
                        Text(
                          'ID: ${departamento.id.substring(0, 12)}...',
                          style: TextStyle(
                            fontSize: 10,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Badge de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color:
                          departamento.tieneEquipos ||
                              departamento.tienePersonal
                          ? AppTheme.successColor.withValues(alpha: 0.1)
                          : const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      departamento.tieneEquipos || departamento.tienePersonal
                          ? 'Activo'
                          : 'Vacío',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color:
                            departamento.tieneEquipos ||
                                departamento.tienePersonal
                            ? AppTheme.successColor
                            : const Color(0xFF9CA3AF),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Resto del código se mantiene igual...
            // Divider
            Container(
              height: 1,
              color: borderColor.withValues(alpha: 0.5),
              margin: const EdgeInsets.symmetric(horizontal: 16),
            ),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Edit Button
                  TextButton.icon(
                    onPressed: () {
                      _editarDepartamento(departamento);
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
                    icon: Icon(
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

                  // Delete Button (solo si no tiene asignaciones)
                  if (!departamento.tieneEquipos && !departamento.tienePersonal)
                    TextButton.icon(
                      onPressed: () {
                        _eliminarDepartamento(context, departamento);
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
                    )
                  else
                    Tooltip(
                      message: 'No se puede eliminar porque tiene asignaciones',
                      child: Opacity(
                        opacity: 0.5,
                        child: TextButton.icon(
                          onPressed: null,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF9CA3AF),
                            backgroundColor: const Color(0xFFF3F4F6),
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
                            color: Color(0xFF9CA3AF),
                          ),
                          label: const Text(
                            'Eliminar',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF9CA3AF),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Métodos auxiliares para iconos y colores
  Color _obtenerColorFondoPorDepartamento(Departamento departamento) {
    final nombre = departamento.nombre.toLowerCase();

    if (nombre.contains('desarrollo') || nombre.contains('software')) {
      return const Color(0xFF6366F1).withValues(alpha: 0.1);
    } else if (nombre.contains('soporte') || nombre.contains('técnico')) {
      return AppTheme.primaryColor.withValues(alpha: 0.1);
    } else if (nombre.contains('recursos') || nombre.contains('humanos')) {
      return AppTheme.successColor.withValues(alpha: 0.1);
    } else if (nombre.contains('ventas') || nombre.contains('marketing')) {
      return AppTheme.warningColor.withValues(alpha: 0.1);
    } else if (nombre.contains('administración') ||
        nombre.contains('administracion')) {
      return const Color(0xFFEC4899).withValues(alpha: 0.1);
    } else {
      return const Color(0xFF6B7280).withValues(alpha: 0.1);
    }
  }

  Color _obtenerColorIconoPorDepartamento(Departamento departamento) {
    final nombre = departamento.nombre.toLowerCase();

    if (nombre.contains('desarrollo') || nombre.contains('software')) {
      return const Color(0xFF6366F1);
    } else if (nombre.contains('soporte') || nombre.contains('técnico')) {
      return AppTheme.primaryColor;
    } else if (nombre.contains('recursos') || nombre.contains('humanos')) {
      return AppTheme.successColor;
    } else if (nombre.contains('ventas') || nombre.contains('marketing')) {
      return AppTheme.warningColor;
    } else if (nombre.contains('administración') ||
        nombre.contains('administracion')) {
      return const Color(0xFFEC4899);
    } else {
      return const Color(0xFF6B7280);
    }
  }

  IconData _obtenerIconoPorDepartamento(Departamento departamento) {
    final nombre = departamento.nombre.toLowerCase();

    if (nombre.contains('desarrollo') || nombre.contains('software')) {
      return Icons.code;
    } else if (nombre.contains('soporte') || nombre.contains('técnico')) {
      return Icons.support_agent;
    } else if (nombre.contains('recursos') || nombre.contains('humanos')) {
      return Icons.groups;
    } else if (nombre.contains('ventas') || nombre.contains('marketing')) {
      return Icons.trending_up;
    } else if (nombre.contains('administración') ||
        nombre.contains('administracion')) {
      return Icons.business;
    } else if (nombre.contains('finanzas') || nombre.contains('contabilidad')) {
      return Icons.payments;
    } else {
      return Icons.business_center;
    }
  }

  Widget _buildFloatingActionButton(Color primaryColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: FloatingActionButton.extended(
        onPressed: _crearNuevoDepartamento, // Cambia esta línea
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        elevation: 8,
        icon: const Icon(Icons.add),
        label: const Text(
          'Nuevo Departamento',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }
}
