import 'package:afit_prueba1/screen/inventory/add_asset_screen.dart';
import 'package:afit_prueba1/screen/scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/equipo.dart';
import '../../models/trabajador.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/asignacion_provider.dart';
import '../../providers/trabajador_provider.dart';
import '../inventory/asset_details_screen.dart';
import 'worker_registration_screen.dart';
import '../../core/app_theme.dart';

class WorkerDetailScreen extends StatefulWidget {
  final Trabajador trabajador;

  const WorkerDetailScreen({super.key, required this.trabajador});

  @override
  State<WorkerDetailScreen> createState() => _WorkerDetailScreenState();
}

class _WorkerDetailScreenState extends State<WorkerDetailScreen> {
  late Trabajador _trabajadorActual;
  List<Equipo> _equiposAsignados = [];
  bool _cargandoEquipos = false;

  @override
  void initState() {
    super.initState();
    _trabajadorActual = widget.trabajador;

    // ✅ Ejecutar después de que el widget esté montado
    Future.microtask(() {
      if (mounted) {
        _cargarEquiposAsignados();
      }
    });
  }

  Future<void> _cargarEquiposAsignados() async {
    if (!mounted) return;

    // ✅ Usar _cargandoEquipos sin setState directo
    _cargandoEquipos = true;

    try {
      final equipoProvider = Provider.of<EquipoProvider>(
        context,
        listen: false,
      );
      await equipoProvider.cargarEquipos();

      if (!mounted) return;

      final todosLosEquipos = equipoProvider.equipos;
      final asignados = todosLosEquipos
          .where((equipo) => equipo.trabajadorId == _trabajadorActual.id)
          .toList();

      // ✅ Usar setState SOLO si está montado
      setState(() {
        _cargandoEquipos = false;
        _equiposAsignados = asignados;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _cargandoEquipos = false;
        });
      }
      debugPrint('❌ Error cargando equipos asignados: $e');
    }
  }

  String formatDate(DateTime date) {
    final meses = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return '${date.day} ${meses[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final trabajador = _trabajadorActual;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0A0F14) : Colors.white,
      appBar: AppBar(
        title: Text(
          'Detalle del Trabajador',
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
            onPressed: () => _editarTrabajador,
            icon: Icon(Icons.edit),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Content
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarEquiposAsignados,
                color: AppTheme.primaryColor,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 24,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Profile Section
                      Row(
                        children: [
                          Stack(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF2B8CEE,
                                    ).withValues(alpha: 0.3),
                                    width: 2,
                                  ),
                                  color: isDark
                                      ? const Color(0xFF374151)
                                      : Colors.grey[200],
                                ),
                                child: Center(
                                  child: Text(
                                    trabajador.nombres.isNotEmpty &&
                                            trabajador.apellidos.isNotEmpty
                                        ? '${trabajador.nombres[0]}${trabajador.apellidos[0]}'
                                              .toUpperCase()
                                        : '?',
                                    style: TextStyle(
                                      fontSize: 28,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[500],
                                    ),
                                  ),
                                ),
                              ),
                              Positioned(
                                bottom: -2,
                                right: -2,
                                child: Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    color: trabajador.activo
                                        ? Colors.green
                                        : Colors.red,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: isDark
                                          ? const Color(0xFF0A0F14)
                                          : Colors.white,
                                      width: 3,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  trabajador.nombreCompleto,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  trabajador.cargo,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppTheme.primaryColor,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
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
                                    const SizedBox(width: 6),
                                    Text(
                                      trabajador.activo ? 'ACTIVO' : 'INACTIVO',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: trabajador.activo
                                            ? Colors.green
                                            : Colors.red,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: -0.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 32),

                      // Información Personal
                      _buildSection('Información Personal', [
                        _buildInfoRow(
                          'Nombres y Apellidos',
                          trabajador.nombreCompleto,
                        ),
                        _buildInfoRow('DNI', trabajador.dni),
                        _buildInfoRow(
                          'Fecha de Ingreso',
                          formatDate(trabajador.fechaIngreso),
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Información Corporativa
                      _buildSection('Información Corporativa', [
                        _buildInfoRow('Cargo', trabajador.cargo),
                        _buildInfoRow(
                          'Departamento',
                          // ✅ Si el trabajador tiene departamento y no es el especial
                          trabajador.departamentoNombre != null &&
                                  trabajador.departamentoNombre !=
                                      'Sin departamento'
                              ? trabajador.departamentoNombre!
                              : 'No asignado',
                          isPrimary: false,
                        ),
                        _buildInfoRow('Área', trabajador.area),
                        _buildInfoRow(
                          'Usuario Creación',
                          trabajador.usuarioCreacion ?? 'Sistema',
                          isPrimary: true,
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // Contacto
                      _buildSection('Contacto', [
                        _buildInfoRow(
                          'Email Corporativo',
                          trabajador.emailCorporativo ?? 'No registrado',
                        ),
                        _buildInfoRow(
                          'Teléfono',
                          trabajador.telefono ?? 'No registrado',
                        ),
                      ]),

                      const SizedBox(height: 24),

                      // ✅ NUEVA SECCIÓN: UTENSILIOS ASIGNADOS
                      _buildEquiposAsignadosSection(),

                      const SizedBox(height: 24),

                      // Información del Sistema
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'INFORMACIÓN DEL SISTEMA',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.grey[500],
                                  letterSpacing: 1,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF1C2632)
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(
                                    color: isDark
                                        ? const Color(0xFF2D3A4B)
                                        : Colors.grey[300]!,
                                  ),
                                ),
                                child: Text(
                                  'ID: ${trabajador.id}',
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: Colors.grey[500],
                                    fontFamily: 'RobotoMono',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildAssetCard(
                            icon: Icons.calendar_today,
                            title: 'Fecha de Registro',
                            value: formatDate(trabajador.fechaCreacion),
                          ),
                          const SizedBox(height: 12),
                          _buildAssetCard(
                            icon: Icons.person,
                            title: 'Registrado por',
                            value: trabajador.usuarioCreacion ?? 'Sistema',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Buttons
      // lib/screens/worker_detail_screen.dart
      // Reemplaza la sección de bottomSheet con esto:

      // Bottom Buttons - VERSIÓN MEJORADA
      bottomSheet: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              isDark
                  ? const Color(0xFF0A0F14).withValues(alpha: 0.95)
                  : Colors.white.withValues(alpha: 0.95),
            ],
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            // Botón principal: ASIGNAR/TRASLADAR
            Expanded(
              child: ElevatedButton.icon(
                onPressed: trabajador.activo
                    ? () => _mostrarOpcionesAsignacion()
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: trabajador.activo
                      ? AppTheme.primaryColor
                      : Colors.grey[400]!,
                  foregroundColor: Colors.white,
                  elevation: 8,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                icon: const Icon(Icons.add_link, size: 24),
                label: Text(
                  trabajador.activo ? 'ASIGNAR EQUIPO' : 'TRABAJADOR INACTIVO',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Botón de opciones (igual)
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2632) : Colors.grey[100],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF2D3A4B) : Colors.grey[300]!,
                ),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                onSelected: (value) async {
                  if (value == 'editar') {
                    await _editarTrabajador(context);
                  } else if (value == 'cambiar_estado') {
                    _mostrarDialogoCambiarEstado();
                  } else if (value == 'eliminar') {
                    _mostrarDialogoEliminar();
                  }
                },
                itemBuilder: (BuildContext context) {
                  return [
                    const PopupMenuItem<String>(
                      value: 'editar',
                      child: Row(
                        children: [
                          Icon(
                            Icons.edit,
                            size: 20,
                            color: AppTheme.primaryColor,
                          ),
                          SizedBox(width: 8),
                          Text('Editar'),
                        ],
                      ),
                    ),
                    PopupMenuItem<String>(
                      value: 'cambiar_estado',
                      child: Row(
                        children: [
                          Icon(
                            _trabajadorActual.activo
                                ? Icons.toggle_off
                                : Icons.toggle_on,
                            size: 20,
                            color: _trabajadorActual.activo
                                ? Colors.red
                                : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _trabajadorActual.activo ? 'Desactivar' : 'Activar',
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuItem<String>(
                      value: 'eliminar',
                      child: Row(
                        children: [
                          Icon(Icons.delete, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Eliminar'),
                        ],
                      ),
                    ),
                  ];
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // MÉTODOS PARA ASIGNACIÓN DE EQUIPOS
  // ============================================

  /// ✅ Mostrar diálogo de opciones para asignar equipo
  void _mostrarOpcionesAsignacion() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Asignar Equipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Selecciona cómo deseas asignar un equipo a ${_trabajadorActual.nombreCompleto}:',
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(
                Icons.qr_code_scanner,
                color: AppTheme.primaryColor,
              ),
              title: const Text('Escanear QR'),
              subtitle: const Text('Escanea el código QR del equipo'),
              onTap: () {
                Navigator.pop(context);
                _escanearQRParaAsignar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.search, color: AppTheme.primaryColor),
              title: const Text('Buscar equipo'),
              subtitle: const Text('Buscar en el inventario'),
              onTap: () {
                Navigator.pop(context);
                _buscarEquipoParaAsignar();
              },
            ),
            ListTile(
              leading: const Icon(Icons.add, color: AppTheme.primaryColor),
              title: const Text('Crear nuevo'),
              subtitle: const Text('Registrar un equipo nuevo'),
              onTap: () {
                Navigator.pop(context);
                _crearNuevoEquipoParaAsignar(context);
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

  void _escanearQRParaAsignar() {
    if (!mounted) return;
    Navigator.push<Equipo>(
      context,
      MaterialPageRoute(
        builder: (context) => const ScannerScreen(
          modoAsignacion: true, // ← AHORA FUNCIONA
        ),
      ),
    ).then((equipo) {
      if (equipo != null && mounted) {
        _asignarEquipoATrabajador(context, equipo);
      }
    });
  }

  /// ✅ Buscar equipo para asignar
  void _buscarEquipoParaAsignar() {
    showDialog(
      context: context,
      builder: (dialogContext) {
        final equipoProvider = Provider.of<EquipoProvider>(
          dialogContext,
          listen: false,
        );

        final TextEditingController searchController = TextEditingController();
        List<Equipo> resultadosBusqueda = [];
        bool buscando = false;

        return StatefulBuilder(
          builder: (context, setState) {
            final todosLosEquipos = equipoProvider.equipos
                .where((e) => !e.estaAsignado) // Solo no asignados
                .toList();

            return AlertDialog(
              title: const Text('Buscar Equipo'),
              content: Container(
                width: double.maxFinite,
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.6,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: searchController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Buscar por nombre o código QR...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  searchController.clear();
                                  setState(() => resultadosBusqueda = []);
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
                    Expanded(
                      child: buscando
                          ? const Center(child: CircularProgressIndicator())
                          : resultadosBusqueda.isEmpty &&
                                searchController.text.isNotEmpty
                          ? _buildSinResultadosAsignacion(searchController.text)
                          : resultadosBusqueda.isEmpty
                          ? _buildBusquedaInicialAsignacion()
                          : ListView.separated(
                              shrinkWrap: true,
                              itemCount: resultadosBusqueda.length,
                              separatorBuilder: (context, index) =>
                                  const Divider(),
                              itemBuilder: (context, index) {
                                final equipo = resultadosBusqueda[index];
                                return ListTile(
                                  leading: Container(
                                    width: 40,
                                    height: 40,
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2B8CEE,
                                      ).withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _getIconForType(equipo.tipo),
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                  title: Text(equipo.nombre),
                                  subtitle: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Código: ${equipo.codigoQR}',
                                        style: const TextStyle(fontSize: 11),
                                      ),
                                      Text(
                                        'Depto: ${equipo.departamentoNombre ?? "Sin departamento"}',
                                        style: const TextStyle(fontSize: 10),
                                      ),
                                    ],
                                  ),
                                  onTap: () {
                                    Navigator.pop(dialogContext);
                                    _asignarEquipoATrabajador(context, equipo);
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

  /// ✅ Crear nuevo equipo y asignarlo
  void _crearNuevoEquipoParaAsignar(BuildContext context) {
    final equipoTemporal = Equipo(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      codigoQR: 'QR-${DateTime.now().millisecondsSinceEpoch}',
      nombre: '',
      tipo: 'Otro',
      marca: '',
      modelo: '',
      estado: 'en espera',
      numeroSerie: '',
      departamentoId: _trabajadorActual.departamentoId,
      departamentoNombre: _trabajadorActual.departamentoNombre,
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
        // Buscar el equipo recién creado
        final equipoProvider = Provider.of<EquipoProvider>(
          context,
          listen: false,
        );
        final nuevoEquipo = equipoProvider.equipos.firstWhere(
          (e) => e.codigoQR == equipoTemporal.codigoQR,
          orElse: () => throw Exception('Equipo no encontrado'),
        );
        _asignarEquipoATrabajador(context, nuevoEquipo);
      }
    });
  }

  /// ✅ Asignar equipo al trabajador
  void _asignarEquipoATrabajador(BuildContext context, Equipo equipo) {
    _mostrarDialogoConfirmarAsignacion(equipo);
  }

  void _mostrarDialogoConfirmarAsignacion(Equipo equipo) {
    final motivoController = TextEditingController();
    bool guardando = false;

    showDialog(
      context: context,
      barrierDismissible: !guardando,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Confirmar asignación'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Equipo: ${equipo.nombre}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text('Trabajador: ${_trabajadorActual.nombreCompleto}'),
                  const SizedBox(height: 12),
                  TextField(
                    controller: motivoController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Motivo (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: guardando
                      ? null
                      : () => Navigator.pop(dialogContext),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  onPressed: guardando
                      ? null
                      : () async {
                          setDialogState(() => guardando = true);

                          final asignacionProvider =
                              Provider.of<AsignacionProvider>(
                                context,
                                listen: false,
                              );

                          final ok = await asignacionProvider.asignarEquipo(
                            equipoId: equipo.id,
                            equipoNombre: equipo.nombre,
                            trabajadorId: _trabajadorActual.id,
                            trabajadorNombre: _trabajadorActual.nombreCompleto,
                            motivo: motivoController.text.trim().isEmpty
                                ? null
                                : motivoController.text.trim(),
                          );

                          if (!mounted || !dialogContext.mounted) return;

                          setDialogState(() => guardando = false);

                          if (ok) {
                            Navigator.pop(dialogContext);
                            await Provider.of<EquipoProvider>(
                              context,
                              listen: false,
                            ).cargarEquipos();
                            if (!mounted) return;
                            await _cargarEquiposAsignados();

                            if (!context.mounted) return;

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '✅ Equipo asignado a ${_trabajadorActual.nombreCompleto}',
                                ),
                                backgroundColor: Colors.green,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '❌ Error: ${asignacionProvider.error ?? "No se pudo asignar"}',
                                ),
                                backgroundColor: Colors.red,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                  child: guardando
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Confirmar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  /// ✅ Widget para cuando no hay resultados
  Widget _buildSinResultadosAsignacion(String query) {
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

  /// ✅ Widget para búsqueda inicial
  Widget _buildBusquedaInicialAsignacion() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text(
            'Escribe para buscar equipos disponibles',
            style: TextStyle(color: Colors.grey[600]),
          ),
        ],
      ),
    );
  }

  /// ✅ Crear equipo con código QR manual
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
      departamentoId: _trabajadorActual.departamentoId,
      departamentoNombre: _trabajadorActual.departamentoNombre,
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
        final equipoProvider = Provider.of<EquipoProvider>(
          context,
          listen: false,
        );
        final nuevoEquipo = equipoProvider.equipos.firstWhere(
          (e) => e.codigoQR == equipoTemporal.codigoQR,
          orElse: () => throw Exception('Equipo no encontrado'),
        );
        _asignarEquipoATrabajador(context, nuevoEquipo);
      }
    });
  }

  // ✅ NUEVA SECCIÓN: Utensilios Asignados
  Widget _buildEquiposAsignadosSection() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'UTENSILIOS ASIGNADOS (${_equiposAsignados.length})',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.grey[500],
                letterSpacing: 1,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_cargandoEquipos)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            alignment: Alignment.center,
            child: const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.primaryColor),
            ),
          )
        else if (_equiposAsignados.isEmpty)
          Center(
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1C2632) : Colors.grey[50],
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF2D3A4B).withValues(alpha: 0.4)
                      : Colors.grey[200]!,
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Sin utensilios asignados',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[500],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Los equipos asignados aparecerán aquí',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _equiposAsignados.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final equipo = _equiposAsignados[index];
              return _buildEquipoCard(equipo);
            },
          ),
      ],
    );
  }

  Widget _buildEquipoCard(Equipo equipo) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AssetDetailScreen(equipoId: equipo.id),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2632) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark
                ? const Color(0xFF2D3A4B).withValues(alpha: 0.4)
                : Colors.grey[200]!,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icono según tipo
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: _getIconColor(equipo.tipo).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getIconForType(equipo.tipo),
                color: _getIconColor(equipo.tipo),
                size: 24,
              ),
            ),
            const SizedBox(width: 16),

            // Información del equipo
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    equipo.nombre,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            equipo.estado,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(
                              equipo.estado,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          equipo.estado,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(equipo.estado),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Fecha de asignación
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  'ENTREGA',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[500],
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  equipo.fechaAsignacion != null
                      ? formatDate(equipo.fechaAsignacion!)
                      : 'No asignado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // MÉTODOS AUXILIARES PARA ÍCONOS Y COLORES
  // ============================================

  Color _getIconColor(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'computadora':
        return AppTheme.primaryColor;
      case 'silla':
        return AppTheme.warningColor;
      case 'mesa':
        return const Color(0xFF8B5CF6);
      case 'teclado':
        return AppTheme.successColor;
      case 'monitor':
        return AppTheme.errorColor;
      case 'mouse':
        return const Color(0xFF6B7280);
      default:
        return AppTheme.primaryColor;
    }
  }

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return AppTheme.successColor;
      case 'en espera':
        return const Color(0xFF3B82F6);
      case 'mantenimiento':
        return AppTheme.warningColor;
      case 'baja':
        return AppTheme.errorColor;
      default:
        return Colors.grey;
    }
  }

  IconData _getIconForType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'computadora':
        return Icons.computer;
      case 'silla':
        return Icons.chair;
      case 'mesa':
        return Icons.table_chart;
      case 'teclado':
        return Icons.keyboard;
      case 'monitor':
        return Icons.monitor;
      case 'mouse':
        return Icons.mouse;
      default:
        return Icons.devices_other;
    }
  }

  // ============================================
  // MÉTODOS EXISTENTES (SIN CAMBIOS)
  // ============================================

  Future<void> _editarTrabajador(BuildContext context) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            WorkerRegistrationScreen(trabajador: _trabajadorActual),
      ),
    );

    if (result == true && context.mounted) {
      final provider = Provider.of<TrabajadorProvider>(context, listen: false);
      final trabajadorActualizado = await provider.obtenerTrabajadorPorId(
        _trabajadorActual.id,
      );

      if (trabajadorActualizado != null) {
        setState(() {
          _trabajadorActual = trabajadorActualizado;
        });

        await _cargarEquiposAsignados();
        if (!context.mounted) return;

        Navigator.pop(context, true);
      }
    }
  }

  Widget _buildSection(String title, List<Widget> children) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C2632) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark
                  ? const Color(0xFF2D3A4B).withValues(alpha: 0.4)
                  : Colors.grey[300]!,
            ),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {bool isPrimary = false}) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 14, color: Colors.grey[400])),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                color: isPrimary
                    ? AppTheme.primaryColor
                    : (isDark ? Colors.grey[300] : Colors.grey[800]),
                fontWeight: isPrimary ? FontWeight.w600 : FontWeight.w500,
              ),
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssetCard({
    required IconData icon,
    required String title,
    required String value,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C2632) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? const Color(0xFF2D3A4B).withValues(alpha: 0.4)
              : Colors.grey[300]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primaryColor, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoEliminar() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Trabajador'),
        content: Text(
          '¿Estás seguro de eliminar a ${_trabajadorActual.nombres} ${_trabajadorActual.apellidos}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _eliminarTrabajador();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoCambiarEstado() {
    final nuevoEstado = !_trabajadorActual.activo;
    final estadoTexto = nuevoEstado ? 'ACTIVAR' : 'DESACTIVAR';
    final color = nuevoEstado ? Colors.green : Colors.red;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('$estadoTexto Trabajador'),
        content: Text(
          '¿${nuevoEstado ? 'Activar' : 'Desactivar'} a '
          '${_trabajadorActual.nombres} ${_trabajadorActual.apellidos}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _cambiarEstadoTrabajador(context, nuevoEstado);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
            ),
            child: Text(nuevoEstado ? 'Activar' : 'Desactivar'),
          ),
        ],
      ),
    );
  }

  void _eliminarTrabajador() async {
    try {
      final provider = Provider.of<TrabajadorProvider>(context, listen: false);
      final exito = await provider.eliminarTrabajador(_trabajadorActual.id);

      if (exito && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_trabajadorActual.nombres} ${_trabajadorActual.apellidos} eliminado correctamente',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Error al eliminar el trabajador'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _cambiarEstadoTrabajador(BuildContext context, bool nuevoEstado) async {
    try {
      final provider = Provider.of<TrabajadorProvider>(context, listen: false);
      final exito = await provider.cambiarEstadoTrabajador(
        _trabajadorActual.id,
        nuevoEstado,
      );

      if (exito && context.mounted) {
        final trabajadorActualizado = await provider.obtenerTrabajadorPorId(
          _trabajadorActual.id,
        );

        if (trabajadorActualizado != null && context.mounted) {
          setState(() {
            _trabajadorActual = trabajadorActualizado;
          });
        }
        if (!context.mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${_trabajadorActual.nombres} ${_trabajadorActual.apellidos} '
              '${nuevoEstado ? "activado" : "desactivado"} correctamente',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.pop(context, true);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(provider.error ?? 'Error al cambiar el estado'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}
