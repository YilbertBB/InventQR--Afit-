import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../models/traslado.dart';
import '../../models/asignacion.dart';
import '../../models/revision.dart';
import '../../providers/traslado_provider.dart';
import '../../providers/asignacion_provider.dart';
import '../../providers/revision_provider.dart';
import '../../core/app_theme.dart';

class AllActivitiesHistoryScreen extends StatefulWidget {
  const AllActivitiesHistoryScreen({super.key});

  @override
  State<AllActivitiesHistoryScreen> createState() =>
      _AllActivitiesHistoryScreenState();
}

class _AllActivitiesHistoryScreenState
    extends State<AllActivitiesHistoryScreen> {
  final List<String> _filterChips = [
    'Todo',
    'Asignaciones',
    'Traslados',
    'Revisiones',
  ];
  int _selectedFilterIndex = 0;

  List<Map<String, dynamic>> _todasActividades = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarActividades(context);
  }

  Future<void> _cargarActividades(BuildContext context) async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // Cargar traslados
      final trasladoProvider = Provider.of<TrasladoProvider>(
        context,
        listen: false,
      );
      await trasladoProvider.cargarHistorialTraslados();
      final traslados = trasladoProvider.historialTraslados;
      if (!context.mounted) return;

      // Cargar asignaciones
      final asignacionProvider = Provider.of<AsignacionProvider>(
        context,
        listen: false,
      );
      await asignacionProvider.cargarHistorialAsignaciones();
      final asignaciones = asignacionProvider.historialAsignaciones;
      if (!context.mounted) return;

      // Cargar revisiones
      final revisionProvider = Provider.of<RevisionProvider>(
        context,
        listen: false,
      );
      await revisionProvider.cargarHistorialRevisiones();
      final revisiones = revisionProvider.historialRevisiones;

      // Combinar todas las actividades
      final actividades = <Map<String, dynamic>>[];

      // Agregar traslados
      for (var t in traslados) {
        actividades.add({
          'tipo': 'traslado',
          'id': t.id,
          'fecha': t.fechaTraslado,
          'data': t,
          'titulo': 'Traslado de equipo',
          'subtitulo': '${t.equipoNombre} → ${t.haciaDepartamentoNombre}',
          'descripcion': 'Desde: ${t.desdeDepartamentoNombre}',
          'usuario': t.usuarioRealizadorNombre ?? t.usuarioRealizadorId,
          'icono': Icons.swap_horiz,
          'color': AppTheme.primaryColor,
          'estado': 'Completado',
        });
      }

      // Agregar asignaciones
      for (var a in asignaciones) {
        actividades.add({
          'tipo': 'asignacion',
          'id': a.id,
          'fecha': a.fechaAsignacion,
          'data': a,
          'titulo': 'Asignación de equipo',
          'subtitulo': '${a.equipoNombre} → ${a.trabajadorNombre}',
          'descripcion': a.motivoAsignacion ?? 'Sin motivo especificado',
          'usuario': a.usuarioAsignadorNombre ?? a.usuarioAsignadorId,
          'icono': Icons.person_add,
          'color': Colors.green,
          'estado': a.estado,
        });
      }

      // Agregar revisiones
      for (var r in revisiones) {
        String estado;
        Color color;
        if (r.estaCompletada) {
          estado = 'Completada';
          color = Colors.green;
        } else if (r.estaEnCurso) {
          estado = 'En curso';
          color = AppTheme.warningColor;
        } else {
          estado = 'Cancelada';
          color = Colors.red;
        }

        actividades.add({
          'tipo': 'revision',
          'id': r.id,
          'fecha': r.fechaRevision,
          'data': r,
          'titulo': 'Revisión de inventario',
          'subtitulo': r.departamentoNombre,
          'descripcion':
              '${r.equiposCorrectos}/${r.totalEquipos} correctos • ${r.equiposFaltantes} faltantes',
          'usuario': r.usuarioAuditorNombre ?? 'Administrador',
          'icono': Icons.inventory,
          'color': color,
          'estado': estado,
        });
      }

      // Ordenar por fecha (más reciente primero)
      actividades.sort((a, b) {
        final fechaA = a['fecha'] as DateTime;
        final fechaB = b['fecha'] as DateTime;
        return fechaB.compareTo(fechaA);
      });

      if (mounted) {
        setState(() {
          _todasActividades = actividades;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Error al cargar actividades: $e';
          _cargando = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> get _actividadesFiltradas {
    if (_selectedFilterIndex == 0) return _todasActividades;

    String tipoFiltro;
    switch (_selectedFilterIndex) {
      case 1:
        tipoFiltro = 'asignacion';
        break;
      case 2:
        tipoFiltro = 'traslado';
        break;
      case 3:
        tipoFiltro = 'revision';
        break;
      default:
        return _todasActividades;
    }

    return _todasActividades.where((a) => a['tipo'] == tipoFiltro).toList();
  }

  String _formatearFecha(DateTime fecha) {
    final now = DateTime.now();
    final diff = now.difference(fecha).inDays;

    if (diff == 0) {
      return 'Hoy ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (diff == 1) {
      return 'Ayer ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (diff < 7) {
      final dias = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];
      return dias[fecha.weekday - 1];
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf6f6f8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf6f6f8),
        elevation: 0,
        shape: Border(bottom: BorderSide(color: const Color(0xFFe5e7eb))),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 24,
          ),
        ),
        title: const Text(
          'Historial de Actividades',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748b)),
            onPressed: () => _cargarActividades,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => _cargarActividades(context),
        color: const Color(0xFF135bec),
        child: SafeArea(
          child: _cargando
              ? const Center(
                  child: CircularProgressIndicator(color: Color(0xFF135bec)),
                )
              : _error != null
              ? _buildErrorView()
              : _todasActividades.isEmpty
              ? _buildEmptyView()
              : Column(
                  children: [
                    // Filtros
                    _buildFilterChips(),

                    // Resumen rápido
                    _buildQuickStats(),

                    // Lista de actividades
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: _actividadesFiltradas.length,
                        itemBuilder: (context, index) {
                          final actividad = _actividadesFiltradas[index];
                          return _buildActivityCard(actividad);
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _filterChips.length,
        itemBuilder: (context, index) {
          final isSelected = index == _selectedFilterIndex;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                _filterChips[index],
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : const Color(0xFF64748b),
                ),
              ),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  _selectedFilterIndex = selected ? index : 0;
                });
              },
              backgroundColor: const Color(0xFFf1f5f9),
              selectedColor: const Color(0xFF135bec),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide.none,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickStats() {
    final asignaciones = _todasActividades
        .where((a) => a['tipo'] == 'asignacion')
        .length;
    final traslados = _todasActividades
        .where((a) => a['tipo'] == 'traslado')
        .length;
    final revisiones = _todasActividades
        .where((a) => a['tipo'] == 'revision')
        .length;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe5e7eb)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatColumn(
            'Asignaciones',
            asignaciones.toString(),
            Colors.green,
          ),
          _buildStatColumn(
            'Traslados',
            traslados.toString(),
            const Color(0xFF135bec),
          ),
          _buildStatColumn(
            'Revisiones',
            revisiones.toString(),
            AppTheme.warningColor,
          ),
        ],
      ),
    );
  }

  Widget _buildStatColumn(String label, String valor, Color color) {
    return Column(
      children: [
        Text(
          valor,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF64748b)),
        ),
      ],
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
          const SizedBox(height: 16),
          Text(
            _error!,
            style: TextStyle(color: Colors.red[700]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => _cargarActividades,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135bec),
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF135bec).withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history,
              size: 60,
              color: Color(0xFF135bec),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay actividades registradas',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Las asignaciones, traslados y revisiones\naparecerán aquí',
            style: TextStyle(fontSize: 14, color: Color(0xFF6b7280)),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(Map<String, dynamic> actividad) {
    // final tipo = actividad['tipo'] as String;
    final color = actividad['color'] as Color;
    final icono = actividad['icono'] as IconData;
    final titulo = actividad['titulo'] as String;
    final subtitulo = actividad['subtitulo'] as String;
    final descripcion = actividad['descripcion'] as String;
    final fecha = actividad['fecha'] as DateTime;
    final usuario = actividad['usuario'] as String;
    final estado = actividad['estado'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe5e7eb)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _mostrarDetalleActividad(actividad),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icono
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icono, color: color, size: 24),
                ),
                const SizedBox(width: 16),

                // Contenido
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              titulo,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1f2937),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              estado,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: color,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitulo,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF4b5563),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        descripcion,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6b7280),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 12,
                            color: const Color(0xFF9ca3af),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatearFecha(fecha),
                            style: const TextStyle(
                              fontSize: 11,
                              color: Color(0xFF9ca3af),
                            ),
                          ),
                          Container(
                            width: 4,
                            height: 4,
                            margin: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: const BoxDecoration(
                              color: Color(0xFF9ca3af),
                              shape: BoxShape.circle,
                            ),
                          ),
                          Expanded(
                            child: Text(
                              'por ${usuario.length > 15 ? '${usuario.substring(0, 12)}...' : usuario}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF9ca3af),
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
          ),
        ),
      ),
    );
  }

  void _mostrarDetalleActividad(Map<String, dynamic> actividad) {
    final tipo = actividad['tipo'] as String;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        if (tipo == 'traslado') {
          final traslado = actividad['data'] as Traslado;
          return _buildTrasladoDetail(traslado);
        } else if (tipo == 'asignacion') {
          final asignacion = actividad['data'] as Asignacion;
          return _buildAsignacionDetail(asignacion);
        } else {
          final revision = actividad['data'] as Revision;
          return _buildRevisionDetail(revision);
        }
      },
    );
  }

  Widget _buildTrasladoDetail(Traslado traslado) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Detalle del Traslado',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildDetailItem('Equipo', traslado.equipoNombre),
          _buildDetailItem('Desde', traslado.desdeDepartamentoNombre),
          _buildDetailItem('Hacia', traslado.haciaDepartamentoNombre),
          _buildDetailItem('Motivo', traslado.motivo),
          if (traslado.observaciones != null)
            _buildDetailItem('Observaciones', traslado.observaciones!),
          _buildDetailItem(
            'Realizado por',
            traslado.usuarioRealizadorNombre ?? traslado.usuarioRealizadorId,
          ),
          _buildDetailItem(
            'Fecha',
            '${traslado.fechaTraslado.day}/${traslado.fechaTraslado.month}/${traslado.fechaTraslado.year} ${traslado.fechaTraslado.hour}:${traslado.fechaTraslado.minute}',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135bec),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAsignacionDetail(Asignacion asignacion) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Detalle de Asignación',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildDetailItem('Equipo', asignacion.equipoNombre),
          _buildDetailItem('Trabajador', asignacion.trabajadorNombre),
          if (asignacion.motivoAsignacion != null)
            _buildDetailItem('Motivo', asignacion.motivoAsignacion!),
          _buildDetailItem(
            'Asignado por',
            asignacion.usuarioAsignadorNombre ?? asignacion.usuarioAsignadorId,
          ),
          if (asignacion.fechaDesasignacion != null)
            _buildDetailItem(
              'Desasignado',
              '${asignacion.fechaDesasignacion!.day}/${asignacion.fechaDesasignacion!.month}/${asignacion.fechaDesasignacion!.year}',
            ),
          _buildDetailItem(
            'Fecha',
            '${asignacion.fechaAsignacion.day}/${asignacion.fechaAsignacion.month}/${asignacion.fechaAsignacion.year} ${asignacion.fechaAsignacion.hour}:${asignacion.fechaAsignacion.minute}',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135bec),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Cerrar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionDetail(Revision revision) {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Detalle de Revisi?n',
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 24),
          _buildDetailItem('Departamento', revision.departamentoNombre),
          _buildDetailItem('Estado', revision.estado),
          _buildDetailItem(
            'Auditor',
            revision.usuarioAuditorNombre ?? 'Administrador',
          ),
          _buildDetailItem('Total equipos', '${revision.totalEquipos}'),
          _buildDetailItem('Correctos', '${revision.equiposCorrectos}'),
          _buildDetailItem('Faltantes', '${revision.equiposFaltantes}'),
          _buildDetailItem('Sobrantes', '${revision.equiposSobrantes}'),
          if (revision.observaciones != null)
            _buildDetailItem('Observaciones', revision.observaciones!),
          _buildDetailItem(
            'Fecha',
            '${revision.fechaRevision.day}/${revision.fechaRevision.month}/${revision.fechaRevision.year}',
          ),
          const SizedBox(height: 24),
          Column(
            children: [
              if (revision.estaEnCurso)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final provider = context.read<RevisionProvider>();
                      final reanudado = await provider.reanudarRevision(
                        revision.id,
                      );
                      if (!context.mounted) return;
                      if (reanudado) {
                        Navigator.pop(context);
                        AppRoutes.goToProgresoReport(context);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              provider.error ??
                                  'No se pudo reanudar la revisi?n',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF135bec),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Continuar'),
                  ),
                ),
              if (revision.estaEnCurso) const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF135bec),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Cerrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Color(0xFF64748b),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: Color(0xFF1f2937),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
