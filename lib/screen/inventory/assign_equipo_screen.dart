import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../models/trabajador.dart';
import '../../providers/asignacion_provider.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/trabajador_provider.dart';
import '../../core/app_theme.dart';

class AssignEquipoScreen extends StatefulWidget {
  final String equipoId;
  final String equipoNombre;
  final String departamentoId;

  const AssignEquipoScreen({
    super.key,
    required this.equipoId,
    required this.equipoNombre,
    required this.departamentoId,
  });

  @override
  State<AssignEquipoScreen> createState() => _AssignEquipoScreenState();
}

class _AssignEquipoScreenState extends State<AssignEquipoScreen> {
  bool _cargando = false;
  Trabajador? _trabajadorSeleccionado;
  final TextEditingController _motivoController = TextEditingController();
  final TextEditingController _busquedaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatosIniciales();
    });
  }

  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;

    final trabajadorProvider = Provider.of<TrabajadorProvider>(
      context,
      listen: false,
    );

    await trabajadorProvider.cargarTrabajadores();

    if (!mounted) return;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        leading: IconButton(
          onPressed: () => AppRoutes.goBack(context),
          icon: Icon(Icons.arrow_back_ios_new, color: Colors.black),
        ),
        title: Text(
          'Asignar Equipo',
          style: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Info del equipo
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.devices,
                      color: AppTheme.primaryColor,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.equipoNombre,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'ID: ${widget.equipoId}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // Buscador de trabajadores
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _busquedaController,
                  onChanged: (value) => _buscarTrabajadores(value),
                  decoration: InputDecoration(
                    hintText: 'Buscar trabajador por nombre o DNI...',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    prefixIcon: const Icon(
                      Icons.search,
                      color: Color(0xFF94A3B8),
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Lista de trabajadores
            Expanded(
              child: Consumer<TrabajadorProvider>(
                builder: (context, provider, child) {
                  final trabajadores = provider.trabajadores
                      .where(
                        (t) =>
                            t.departamentoId == widget.departamentoId &&
                            t.activo,
                      )
                      .toList();

                  if (provider.cargando) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (trabajadores.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No hay trabajadores en este departamento',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Registra trabajadores para asignar equipos',
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return RadioGroup<String>(
                    groupValue: _trabajadorSeleccionado?.id,
                    onChanged: (value) {
                      if (value == null) return;
                      final seleccionado = trabajadores.firstWhere(
                        (t) => t.id == value,
                        orElse: () => trabajadores.first,
                      );
                      setState(() {
                        _trabajadorSeleccionado = seleccionado;
                      });
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: trabajadores.length,
                      itemBuilder: (context, index) {
                        final trabajador = trabajadores[index];
                        final isSelected =
                            _trabajadorSeleccionado?.id == trabajador.id;

                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _trabajadorSeleccionado = trabajador;
                            });
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? const Color(
                                      0xFF135BEC,
                                    ).withValues(alpha: 0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppTheme.primaryColor
                                    : const Color(0xFFE2E8F0),
                                width: isSelected ? 2 : 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 50,
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF1F5F9),
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      trabajador.nombres
                                          .substring(0, 1)
                                          .toUpperCase(),
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: AppTheme.primaryColor,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        trabajador.nombreCompleto,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${trabajador.cargo} • ${trabajador.area}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'DNI: ${trabajador.dni}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Radio<String>(
                                  value: trabajador.id,
                                  activeColor: AppTheme.primaryColor,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              ),
            ),

            // Campo de motivo (opcional)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: TextField(
                  controller: _motivoController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'Motivo de la asignación (opcional)',
                    hintStyle: TextStyle(color: Colors.grey[400]),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
              ),
            ),

            // Botones
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _cargando
                            ? null
                            : () => _asignarEquipo(context),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: _cargando
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Confirmar Asignación',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
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

  Future<void> _buscarTrabajadores(String query) async {
    if (query.isEmpty) {
      final provider = Provider.of<TrabajadorProvider>(context, listen: false);
      await provider.obtenerTrabajadoresPorDepartamento(widget.departamentoId);
    } else {
      final provider = Provider.of<TrabajadorProvider>(context, listen: false);
      final resultados = await provider.buscarTrabajadores(query);
      provider.setResultadosBusqueda(resultados);
    }
  }

  Future<void> _asignarEquipo(BuildContext context) async {
    // Validar que haya un trabajador seleccionado
    if (_trabajadorSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Debe seleccionar un trabajador'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    setState(() => _cargando = true);

    try {
      // ✅ USAR ASIGNACIONPROVIDER (NO EquipoProvider)
      final asignacionProvider = Provider.of<AsignacionProvider>(
        context,
        listen: false,
      );

      debugPrint('🔍 Asignando equipo: ${widget.equipoNombre}');
      debugPrint(
        '🔍 A trabajador: ${_trabajadorSeleccionado!.nombreCompleto} (ID: ${_trabajadorSeleccionado!.id})',
      );

      final success = await asignacionProvider.asignarEquipo(
        equipoId: widget.equipoId,
        equipoNombre: widget.equipoNombre,
        trabajadorId: _trabajadorSeleccionado!.id,
        trabajadorNombre: _trabajadorSeleccionado!.nombreCompleto,
        motivo: _motivoController.text.isNotEmpty
            ? _motivoController.text
            : null,
      );

      if (success) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Equipo asignado exitosamente'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // ✅ IMPORTANTE: Recargar equipos en EquipoProvider para actualizar UI
          final equipoProvider = Provider.of<EquipoProvider>(
            context,
            listen: false,
          );
          await equipoProvider.cargarEquipos();
          if (!context.mounted) return;

          // Cerrar pantalla y notificar éxito
          Navigator.pop(context, true);
        }
      } else {
        if (context.mounted) {
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
      }
    } catch (e) {
      debugPrint('❌ Excepción en asignación: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al asignar: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }
}
