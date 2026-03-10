import 'package:afit_prueba1/screen/inventory/assign_equipo_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../database/database_helper.dart';
import '../../models/departamento.dart';
import '../../models/equipo.dart';
import '../../models/trabajador.dart';
import '../../providers/equipo_provider.dart';
import '../inventory/add_asset_screen.dart';
import '../inventory/asset_details_screen.dart';
import '../scanner_screen.dart';
import '../inventory/transfer_screen.dart';
import '../workers/worker_details_screen.dart';
import '../../core/app_theme.dart';

class InventoryDepartments extends StatefulWidget {
  final Departamento departamento;

  const InventoryDepartments({super.key, required this.departamento});

  @override
  State<InventoryDepartments> createState() => _InventoryDepartmentsState();
}

class _InventoryDepartmentsState extends State<InventoryDepartments> {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final TextEditingController _searchController = TextEditingController();

  List<Equipo> _equipos = [];
  List<Equipo> _equiposFiltrados = [];
  List<Trabajador> _trabajadores = [];
  List<Trabajador> _trabajadoresFiltrados = [];

  bool _cargando = true;
  String? _error;

  final List<String> categories = ['Equipos', 'Trabajadores'];

  int selectedCategory = 0;

  @override
  void initState() {
    super.initState();
    _cargarEquiposDelDepartamento();
    _cargarTrabajadoresDelDepartamento(); // <-- añadir esto
    _searchController.addListener(() {
      if (selectedCategory == 0) {
        _filtrarEquipos();
      } else {
        _filtrarTrabajadores();
      }
    });
  }

  Future<void> _cargarEquiposDelDepartamento() async {
    try {
      setState(() {
        _cargando = true;
        _error = null;
      });

      final db = await _dbHelper.database;

      // Cargar equipos del departamento específico
      final resultados = await db.query(
        'equipos',
        where: 'departamento_id = ? AND activo = 1',
        whereArgs: [widget.departamento.id],
        orderBy: 'nombre ASC',
      );

      final lista = resultados.map((map) => Equipo.fromMap(map)).toList();

      setState(() {
        _equipos = lista;
        _equiposFiltrados = lista;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar equipos: $e';
        _cargando = false;
      });
    }
  }

  Future<void> _cargarTrabajadoresDelDepartamento() async {
    try {
      setState(() {
        _cargando = true;
        _error = null;
      });

      final db = await _dbHelper.database;

      // Cargar trabajadores del departamento específico
      final resultados = await db.query(
        'trabajadores',
        where: 'departamento_id = ?',
        whereArgs: [widget.departamento.id],
        orderBy: 'nombres ASC',
      );

      final lista = resultados.map((map) => Trabajador.fromMap(map)).toList();

      setState(() {
        _trabajadores = lista;
        _trabajadoresFiltrados = lista;
        _cargando = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error al cargar trabajadores: $e';
        _cargando = false;
      });
    }
  }

  void _filtrarEquipos() {
    final busqueda = _searchController.text.toLowerCase().trim();

    if (busqueda.isEmpty) {
      setState(() {
        _equiposFiltrados = _equipos;
      });
      return;
    }

    final filtrados = _equipos.where((equipo) {
      return equipo.nombre.toLowerCase().contains(busqueda) ||
          equipo.codigoQR.toLowerCase().contains(busqueda) ||
          equipo.numeroSerie.toLowerCase().contains(busqueda) ||
          (equipo.trabajadorNombre?.toLowerCase().contains(busqueda) ?? false);
    }).toList();

    setState(() {
      _equiposFiltrados = filtrados;
    });
  }

  void _filtrarTrabajadores() {
    final busqueda = _searchController.text.toLowerCase().trim();

    if (busqueda.isEmpty) {
      setState(() {
        _trabajadoresFiltrados = _trabajadores;
      });
      return;
    }

    final filtrados = _trabajadores.where((trabajador) {
      return trabajador.nombres.toLowerCase().contains(busqueda) ||
          trabajador.apellidos.toLowerCase().contains(busqueda) ||
          trabajador.dni.toLowerCase().contains(busqueda) ||
          trabajador.cargo.toLowerCase().contains(busqueda);
    }).toList();

    setState(() {
      _trabajadoresFiltrados = filtrados;
    });
  }

  void _filtrarPorCategoria() {
    if (selectedCategory == 0) {
      _filtrarEquipos();
    } else if (selectedCategory == 1) {
      _filtrarTrabajadores();
    }
  }

  // ============================================
  // DIÁLOGOS DE AGREGADO
  // ============================================

  /// ✅ Diálogo de opciones (Agregar Manual o Escanear)
  Future<void> _mostrarDialogoOpcionesAgregado(BuildContext context) async {
    final opcion = await showDialog<int>(
      context: context,
      barrierDismissible: true,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icono y título
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(15),
                ),
                child: const Icon(
                  Icons.add_circle,
                  color: AppTheme.primaryColor,
                  size: 32,
                ),
              ),
              const SizedBox(height: 16),

              const Text(
                'Agregar Equipo',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 8),

              Text(
                'Seleccione cómo desea agregar el equipo a ${widget.departamento.nombre}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),

              const SizedBox(height: 24),

              // Opción 1: Manualmente
              _buildOpcionDialogo(
                icon: Icons.search,
                titulo: 'Buscar y Seleccionar',
                subtitulo: 'Buscar equipo existente en el inventario',
                color: AppTheme.successColor,
                onTap: () => Navigator.pop(context, 1),
              ),

              const SizedBox(height: 12),

              // Opción 2: Escanear QR
              _buildOpcionDialogo(
                icon: Icons.qr_code_scanner,
                titulo: 'Escanear Código QR',
                subtitulo: 'Escanea el código QR del equipo',
                color: AppTheme.primaryColor,
                onTap: () => Navigator.pop(context, 2),
              ),

              const SizedBox(height: 12),

              // Botón Cancelar
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.pop(context, 0),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[600],
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: const Text('Cancelar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Procesar la opción seleccionada
    if (opcion == 1) {
      _mostrarDialogoBusquedaManual();
    } else if (opcion == 2 && context.mounted) {
      _escanearCodigoQR(context);
    }
  }

  Widget _buildOpcionDialogo({
    required IconData icon,
    required String titulo,
    required String subtitulo,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      titulo,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitulo,
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: color, size: 20),
            ],
          ),
        ),
      ),
    );
  }

  /// ✅ Diálogo de búsqueda manual (CORREGIDO)
  void _mostrarDialogoBusquedaManual() {
    if (!mounted) return;

    // ✅ Guardar referencia al contexto de la pantalla principal
    final scaffoldContext = context;

    final TextEditingController searchController = TextEditingController();
    List<Equipo> resultadosBusqueda = [];
    bool buscando = false;

    showDialog(
      context: context,
      builder: (dialogContext) {
        final equipoProvider = Provider.of<EquipoProvider>(
          dialogContext,
          listen: false,
        );

        // Todos los equipos activos
        final todosLosEquipos = equipoProvider.equipos;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Seleccionar Equipo'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Campo de búsqueda
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre, serie o código QR...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() {
                                    resultadosBusqueda = [];
                                  });
                                },
                              )
                            : null,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onChanged: (value) {
                        setState(() => buscando = true);

                        final resultados = todosLosEquipos
                            .where(
                              (equipo) =>
                                  equipo.nombre.toLowerCase().contains(
                                    value.toLowerCase(),
                                  ) ||
                                  equipo.numeroSerie.toLowerCase().contains(
                                    value.toLowerCase(),
                                  ) ||
                                  equipo.codigoQR.toLowerCase().contains(
                                    value.toLowerCase(),
                                  ),
                            )
                            .toList();

                        setState(() {
                          resultadosBusqueda = resultados;
                          buscando = false;
                        });
                      },
                    ),

                    const SizedBox(height: 16),

                    // Resultados
                    Expanded(
                      child: buscando
                          ? const Center(child: CircularProgressIndicator())
                          : resultadosBusqueda.isEmpty &&
                                searchController.text.isNotEmpty
                          ? _buildSinResultados(searchController.text)
                          : resultadosBusqueda.isEmpty
                          ? _buildBusquedaInicial()
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: resultadosBusqueda.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final equipo = resultadosBusqueda[index];
                                final yaEstaEnDepto =
                                    equipo.departamentoId ==
                                    widget.departamento.id;

                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF135BEC,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _obtenerIconoTipo(equipo.tipo),
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  title: Text(
                                    equipo.nombre,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Serie: ${equipo.numeroSerie}'),
                                      Text(
                                        'Depto actual: ${equipo.departamentoNombre ?? "Sin departamento"}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: yaEstaEnDepto
                                              ? Colors.green[700]
                                              : Colors.orange[700],
                                        ),
                                      ),
                                      if (equipo.trabajadorNombre != null)
                                        Text(
                                          'Asignado a: ${equipo.trabajadorNombre}',
                                          style: const TextStyle(fontSize: 11),
                                        ),
                                    ],
                                  ),
                                  trailing: yaEstaEnDepto
                                      ? Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(
                                              alpha: 0.1,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                          ),
                                          child: const Text(
                                            'EN DEPTO',
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.green,
                                            ),
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_circle,
                                          color: AppTheme.primaryColor,
                                        ),
                                  onTap: () async {
                                    // Guardar datos
                                    final equipoSeleccionado = equipo;

                                    // Cerrar diálogo
                                    Navigator.pop(dialogContext);

                                    // Pequeña pausa
                                    await Future.delayed(
                                      const Duration(milliseconds: 100),
                                    );

                                    if (!scaffoldContext.mounted) return;

                                    if (yaEstaEnDepto) {
                                      // Si ya está en el departamento, mostrar opciones
                                      _mostrarOpcionesEquipoEnDepto(
                                        scaffoldContext,
                                        equipoSeleccionado,
                                      );
                                    } else {
                                      // Si está en otro departamento, preguntar por traslado
                                      _preguntarTraslado(
                                        scaffoldContext,
                                        equipoSeleccionado,
                                      );
                                    }
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('CANCELAR'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _mostrarOpcionesEquipoEnDepto(BuildContext context, Equipo equipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(equipo.nombre),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Este equipo ya está en este departamento.'),
            const SizedBox(height: 16),
            const Text('¿Qué deseas hacer?'),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.visibility, color: AppTheme.primaryColor),
              title: const Text('Ver detalles'),
              onTap: () {
                Navigator.pop(context);
                _navegarADetalleEquipo(context, equipo.id);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_add, color: AppTheme.primaryColor),
              title: const Text('Asignar a trabajador'),
              onTap: () {
                Navigator.pop(context);
                _navegarAAsignacion(context, equipo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit, color: AppTheme.primaryColor),
              title: const Text('Editar equipo'),
              onTap: () {
                Navigator.pop(context);
                _navegarAEdicion(context, equipo);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Preguntar si quiere trasladar el equipo
  void _preguntarTraslado(BuildContext context, Equipo equipo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Equipo de otro departamento'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'El equipo "${equipo.nombre}" pertenece a '
              '${equipo.departamentoNombre ?? "otro departamento"}.',
            ),
            const SizedBox(height: 16),
            const Text('¿Qué deseas hacer?'),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.swap_horiz, color: AppTheme.primaryColor),
              title: const Text('Trasladar a este departamento'),
              onTap: () {
                Navigator.pop(context);
                _navegarATraslado(context, equipo);
              },
            ),
            ListTile(
              leading: const Icon(Icons.visibility, color: AppTheme.primaryColor),
              title: const Text('Solo ver detalles'),
              onTap: () {
                Navigator.pop(context);
                _navegarADetalleEquipo(context, equipo.id);
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }

  void _navegarATraslado(BuildContext context, Equipo equipo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransferScreen(
          equipoId: equipo.id,
          equipoNombre: equipo.nombre,
          departamentoActualId: equipo.departamentoId,
          departamentoActualNombre: equipo.departamentoNombre,
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;

      _cargarEquiposDelDepartamento();
      Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
    });
  }

  // ✅ NUEVO: Navegar a edición
  void _navegarAEdicion(BuildContext context, Equipo equipo) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddAssetScreen(equipo: equipo)),
    ).then((result) {
      if (result == true && context.mounted) {
        _cargarEquiposDelDepartamento();
        Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
      }
    });
  }

  // ✅ NUEVO: Navegar a asignación
  void _navegarAAsignacion(BuildContext context, Equipo equipo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssignEquipoScreen(
          equipoId: equipo.id,
          equipoNombre: equipo.nombre,
          departamentoId: widget.departamento.id,
        ),
      ),
    ).then((_) {
      if (!context.mounted) return;

      _cargarEquiposDelDepartamento();
      Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
    });
  }

  // ✅ NUEVO: Sin resultados
  Widget _buildSinResultados(String query) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'No se encontraron resultados',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _crearNuevoEquipoConQR(context, query);
            },
            icon: const Icon(Icons.add),
            label: const Text('Crear nuevo equipo'),
          ),
        ],
      ),
    );
  }

  // ✅ NUEVO: Búsqueda inicial
  Widget _buildBusquedaInicial() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Escribe para buscar equipos',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// ✅ Crear nuevo equipo con código QR manual
  void _crearNuevoEquipoConQR(BuildContext context, String qrCode) {
    final equipoTemporal = Equipo(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      codigoQR: qrCode,
      nombre: '',
      tipo: 'Otro',
      marca: '',
      modelo: '',
      estado: 'en espera',
      numeroSerie: '',
      departamentoId: widget.departamento.id,
      departamentoNombre: widget.departamento.nombre,
      proyectoId: '',
      proyectoNombre: null,
      trabajadorId: null,
      trabajadorNombre: null,
      fechaAdquisicion: DateTime.now(),
      fechaAsignacion: null,
      usuarioCreacion: 'usuario_actual',
      fechaCreacion: DateTime.now(),
      activo: true,
      observaciones: null,
      costo: null,
      fechaGarantia: null,
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssetScreen(equipo: equipoTemporal),
      ),
    ).then((result) {
      if (result == true && context.mounted) {
        _cargarEquiposDelDepartamento();
        Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
      }
    });
  }

  // inventorydepartemnt.dart - Método _escanearCodigoQR

  void _escanearCodigoQR(BuildContext context) {
    // ✅ Ir directamente al escáner en modo traslado
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ScannerScreen(
          modoTraslado: true,
          departamentoDestinoId: widget.departamento.id,
          departamentoDestinoNombre: widget.departamento.nombre,
        ),
      ),
    ).then((_) {
      // Al volver, recargar equipos
      if (!context.mounted) return;

      _cargarEquiposDelDepartamento();
      Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
    });
  }

  /// ✅ Navegar al detalle del equipo
  void _navegarADetalleEquipo(BuildContext context, String equipoId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AssetDetailScreen(equipoId: equipoId),
      ),
    ).then((_) {
      if (!context.mounted) return;

      _cargarEquiposDelDepartamento();
      Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
    });
  }

  // ============================================
  // MÉTODOS AUXILIARES
  // ============================================

  Color _obtenerColorEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
      case 'en uso':
        return Colors.green;
      case 'en espera':
      case 'disponible':
        return AppTheme.primaryColor;
      case 'mantenimiento':
      case 'reparación':
        return Colors.amber;
      case 'baja':
      case 'dañado':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _obtenerTextoEstado(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return 'ACTIVO';
      case 'en espera':
        return 'ESPERA';
      case 'mantenimiento':
        return 'MANTENIMIENTO';
      case 'baja':
        return 'BAJA';
      default:
        return estado.toUpperCase();
    }
  }

  IconData _obtenerIconoTipo(String tipo) {
    final tipoLower = tipo.toLowerCase();

    if (tipoLower.contains('laptop') || tipoLower.contains('portátil')) {
      return Icons.laptop_mac;
    } else if (tipoLower.contains('computadora') || tipoLower.contains('pc')) {
      return Icons.computer;
    } else if (tipoLower.contains('monitor') ||
        tipoLower.contains('pantalla')) {
      return Icons.monitor;
    } else if (tipoLower.contains('teclado')) {
      return Icons.keyboard;
    } else if (tipoLower.contains('mouse') || tipoLower.contains('ratón')) {
      return Icons.mouse;
    } else if (tipoLower.contains('impresora')) {
      return Icons.print;
    } else if (tipoLower.contains('silla')) {
      return Icons.chair;
    } else if (tipoLower.contains('mesa') || tipoLower.contains('escritorio')) {
      return Icons.table_restaurant;
    } else {
      return Icons.device_unknown;
    }
  }

  Color _obtenerColorIcono(String tipo) {
    final tipoLower = tipo.toLowerCase();

    if (tipoLower.contains('laptop') || tipoLower.contains('portátil')) {
      return AppTheme.primaryColor;
    } else if (tipoLower.contains('computadora') || tipoLower.contains('pc')) {
      return const Color(0xFF6366F1);
    } else if (tipoLower.contains('monitor') ||
        tipoLower.contains('pantalla')) {
      return AppTheme.successColor;
    } else if (tipoLower.contains('teclado')) {
      return AppTheme.warningColor;
    } else if (tipoLower.contains('mouse') || tipoLower.contains('ratón')) {
      return const Color(0xFFEC4899);
    } else if (tipoLower.contains('impresora')) {
      return const Color(0xFF8B5CF6);
    } else if (tipoLower.contains('silla')) {
      return const Color(0xFFF97316);
    } else if (tipoLower.contains('mesa') || tipoLower.contains('escritorio')) {
      return const Color(0xFF0EA5E9);
    } else {
      return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF101922)
          : AppTheme.backgroundColorLight,
      appBar: AppBar(
        title: Text(
          widget.departamento.nombre,
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark
            ? const Color(0xFF101922)
            : AppTheme.backgroundColorLight,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          IconButton(
            onPressed: _cargarEquiposDelDepartamento,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(isDark),
            _buildCategoryFilters(isDark),
            const SizedBox(height: 8),
            Expanded(child: _buildMainContent(isDark)),
          ],
        ),
      ),

      floatingActionButton: selectedCategory == 0
          ? FloatingActionButton.extended(
              onPressed: () => _mostrarDialogoOpcionesAgregado(context),
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: const Text('AGREGAR EQUIPO'),
            )
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSearchBar(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          filled: true,
          fillColor: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.4)
              : Colors.grey[200]!.withValues(alpha: 0.5),
          hintText: 'Buscar por nombre, serie o código QR...',
          hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
          prefixIcon: Icon(Icons.search, color: Colors.grey[400]),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: AppTheme.primaryColor.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        style: TextStyle(
          fontSize: 14,
          color: isDark ? Colors.grey[300] : Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildCategoryFilters(bool isDark) {
    return SizedBox(
      height: 44,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: categories.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(right: 12),
            child: ChoiceChip(
              label: Text(
                categories[index],
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selectedCategory == index
                      ? FontWeight.w600
                      : FontWeight.w500,
                  color: selectedCategory == index
                      ? Colors.white
                      : (isDark ? Colors.grey[400] : Colors.grey[600]),
                ),
              ),
              selected: selectedCategory == index,
              onSelected: (selected) {
                setState(() {
                  selectedCategory = index;
                  _filtrarPorCategoria();
                });
              },
              selectedColor: AppTheme.primaryColor,
              backgroundColor: isDark
                  ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                  : Colors.grey[200]!.withValues(alpha: 0.5),
              elevation: selectedCategory == index ? 4 : 0,
              shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMainContent(bool isDark) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.red),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _cargarEquiposDelDepartamento,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('Reintentar'),
              ),
            ],
          ),
        ),
      );
    }
    if (selectedCategory == 0) {
      if (_equiposFiltrados.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, color: Colors.grey[400], size: 64),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty
                      ? 'No se encontraron equipos'
                      : 'Este departamento no tiene equipos',
                  style: const TextStyle(fontSize: 16),
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
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: _equiposFiltrados.length,
        itemBuilder: (context, index) {
          return _buildAssetCard(_equiposFiltrados[index], isDark);
        },
      );
    } else {
      if (_trabajadoresFiltrados.isEmpty) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory, color: Colors.grey[400], size: 64),
                const SizedBox(height: 16),
                Text(
                  _searchController.text.isNotEmpty
                      ? 'No se encontraron trabajdores'
                      : 'Este departamento no tiene trabajadores',
                  style: const TextStyle(fontSize: 16),
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
          ),
        );
      }
      return ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
        itemCount: _equiposFiltrados.length,
        itemBuilder: (context, index) {
          return _buildWorkerCard(_trabajadoresFiltrados[index]);
        },
      );
    }
  }

  Widget _buildAssetCard(Equipo equipo, bool isDark) {
    final estadoColor = _obtenerColorEstado(equipo.estado);
    final estadoTexto = _obtenerTextoEstado(equipo.estado);
    final icono = _obtenerIconoTipo(equipo.tipo);
    final iconoColor = _obtenerColorIcono(equipo.tipo);

    return GestureDetector(
      onTap: () => _navegarADetalleEquipo(context, equipo.id),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withValues(alpha: 0.5)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF334155).withValues(alpha: 0.5)
                : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Icono del equipo
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: iconoColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: iconoColor, size: 32),
              ),

              const SizedBox(width: 16),

              // Información del equipo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            equipo.nombre,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              height: 1.2,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: estadoColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            estadoTexto,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: estadoColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 4),

                    Text(
                      'S/N: ${equipo.numeroSerie}',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                    ),

                    Text(
                      'QR: ${equipo.codigoQR}',
                      style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                    ),

                    const SizedBox(height: 8),

                    // Detalles adicionales
                    Wrap(
                      spacing: 16,
                      children: [
                        if (equipo.trabajadorNombre != null)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.person,
                                size: 14,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(width: 4),
                              Text(
                                equipo.trabajadorNombre!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[400],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),

                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: Colors.grey[400],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${equipo.fechaAdquisicion.day}/${equipo.fechaAdquisicion.month}/${equipo.fechaAdquisicion.year}',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[400],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWorkerCard(Trabajador trabajador) {
    final departmentColor = _getColorForDepartment(widget.departamento.nombre);
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFE5E7EB).withValues(alpha: 0.5),
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
                await _cargarTrabajadoresDelDepartamento();
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
                      borderRadius: BorderRadius.circular(12),
                      color: departmentColor.withValues(alpha: 0.1),
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
                                  color: const Color(0xFF111827),
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
        ],
      ),
    );
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

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
