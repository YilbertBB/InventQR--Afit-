import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/equipo.dart';
import '../../models/traslado.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/traslado_provider.dart';
import 'asset_details_screen.dart';
import 'transfer_screen.dart';

class HistoryScreen extends StatefulWidget {
  final String? equipoId;

  const HistoryScreen({super.key, this.equipoId});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  Equipo? _equipo;
  List<Traslado> _traslados = [];
  List<dynamic> _todosMovimientos = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargarDatos();
    });
  }

  Future<void> _cargarDatos() async {
    if (!mounted) return;

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      // 1. Cargar equipo si tenemos ID
      if (widget.equipoId != null) {
        final equipoProvider = Provider.of<EquipoProvider>(
          context,
          listen: false,
        );
        _equipo = await equipoProvider.obtenerEquipoPorId(widget.equipoId!);
      }
      if (!mounted) return;
      final trasladoProvider = Provider.of<TrasladoProvider>(
        context,
        listen: false,
      );
      if (widget.equipoId != null) {
        _traslados = await trasladoProvider.obtenerHistorialPorEquipo(
          widget.equipoId!,
        );
      } else {
        await trasladoProvider.cargarHistorialTraslados();
        _traslados = trasladoProvider.historialTraslados;
      }

      // 3. Combinar y ordenar movimientos
      _combinarMovimientos();
    } catch (e) {
      setState(() {
        _error = 'Error al cargar el historial: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _cargando = false;
        });
      }
    }
  }

  void _combinarMovimientos() {
    _todosMovimientos = [
      ..._traslados.map(
        (t) => {'tipo': 'traslado', 'fecha': t.fechaTraslado, 'data': t},
      ),
    ];

    // Ordenar por fecha (más reciente primero)
    _todosMovimientos.sort((a, b) {
      final fechaA = a['fecha'] as DateTime;
      final fechaB = b['fecha'] as DateTime;
      return fechaB.compareTo(fechaA);
    });
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    const meses = [
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

    if (date.year == now.year &&
        date.month == now.month &&
        date.day == now.day) {
      return 'Hoy ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    } else if (date.year == now.year) {
      return '${date.day} ${meses[date.month - 1]}';
    } else {
      return '${date.day}/${date.month}/${date.year}';
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
        title: Text(
          _equipo != null
              ? 'Historial - ${_equipo!.nombre}'
              : 'Historial de Traslados',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: _cargando
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF135bec)),
                ),
              )
            : _error != null
            ? _buildErrorView()
            : _todosMovimientos.isEmpty
            ? _buildEmptyView(context)
            : Column(
                children: [
                  if (_equipo != null) _buildSummaryCard(),
                  _buildSectionHeader(),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _todosMovimientos.length,
                      itemBuilder: (context, index) {
                        final movimiento = _todosMovimientos[index];
                        if (movimiento['tipo'] == 'traslado') {
                          return _buildTransferTimelineEntry(
                            movimiento['data'] as Traslado,
                            isLast: index == _todosMovimientos.length - 1,
                          );
                        }
                        return const SizedBox.shrink();
                      },
                    ),
                  ),
                ],
              ),
      ),
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
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135bec),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView(BuildContext context) {
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
            'Sin movimientos registrados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Este equipo no tiene traslados en su historial',
            style: TextStyle(fontSize: 14, color: Color(0xFF6b7280)),
            textAlign: TextAlign.center,
          ),
          if (_equipo != null) ...[
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TransferScreen(
                      equipoId: _equipo!.id,
                      equipoNombre: _equipo!.nombre,
                      departamentoActualId: _equipo!.departamentoId,
                      departamentoActualNombre: _equipo!.departamentoNombre,
                    ),
                  ),
                ).then((result) {
                  if (result == true && context.mounted) {
                    _cargarDatos();
                  }
                });
              },
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Realizar traslado'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF135bec),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFf3f4f6)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(
                            _equipo!.estado,
                          ).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _getStatusColor(
                              _equipo!.estado,
                            ).withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          _equipo!.estado.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: _getStatusColor(_equipo!.estado),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _equipo!.nombre,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1f2937),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_equipo!.marca} ${_equipo!.modelo}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6b7280),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(
                        Icons.business,
                        size: 16,
                        color: const Color(0xFF6b7280),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _equipo!.departamentoNombre ?? 'Sin departamento',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF4b5563),
                        ),
                      ),
                    ],
                  ),
                  if (_equipo!.trabajadorNombre != null) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.person, size: 16, color: Colors.green[700]),
                        const SizedBox(width: 4),
                        Text(
                          'Asignado a: \n${_equipo!.trabajadorNombre}',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.green[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 16),
                  Container(
                    height: 36,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF135bec).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(8),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) =>
                                  AssetDetailScreen(equipoId: _equipo!.id),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.info_outline,
                              size: 18,
                              color: Color(0xFF135bec),
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Ver detalles',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF135bec),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: const Color(0xFFf1f5f9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Icon(
                  _getIconForType(_equipo!.tipo),
                  size: 48,
                  color: const Color(0xFF94a3b8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text(
            'Historial de Traslados',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1f2937),
            ),
          ),
          Text(
            '${_todosMovimientos.length} movimientos',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6b7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTransferTimelineEntry(
    Traslado traslado, {
    required bool isLast,
  }) {
    final fecha = traslado.fechaTraslado;
    final fechaStr = '${fecha.day}/${fecha.month}/${fecha.year}';
    final horaStr =
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    final timeDisplay = _formatDate(fecha);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline icon and line
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF135bec).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF135bec), width: 1.5),
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: Color(0xFF135bec),
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: const Color(0xFFe2e8f0),
                margin: const EdgeInsets.only(top: 8),
              ),
          ],
        ),
        const SizedBox(width: 12),

        // Content
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFf3f4f6)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: const Text(
                        'Traslado de Departamento',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1f2937),
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis, // 👈 Puntos suspensivos
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: timeDisplay.contains('Hoy')
                            ? const Color(0xFF135bec).withValues(alpha: 0.1)
                            : const Color(0xFFf1f5f9),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        timeDisplay,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: timeDisplay.contains('Hoy')
                              ? const Color(0xFF135bec)
                              : const Color(0xFF64748b),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Departamentos
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf8fafc),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Origen',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748b),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              traslado.desdeDepartamentoNombre,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF334155),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: const Color(0xFF135bec).withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.arrow_forward,
                          size: 16,
                          color: Color(0xFF135bec),
                        ),
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            const Text(
                              'Destino',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF64748b),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              traslado.haciaDepartamentoNombre,
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF135bec),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.right,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 12),

                // Usuario
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 14,
                      color: Color(0xFF64748b),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        traslado.usuarioRealizadorNombre != null
                            ? 'Realizado por: ${traslado.usuarioRealizadorNombre}'
                            : 'Realizado por: Usuario ${traslado.usuarioRealizadorId.substring(0, 8)}...',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4b5563),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // Fecha completa
                Row(
                  children: [
                    const Icon(
                      Icons.calendar_today,
                      size: 14,
                      color: Color(0xFF64748b),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$fechaStr • $horaStr',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6b7280),
                      ),
                    ),
                  ],
                ),

                // Motivo
                Container(
                  margin: const EdgeInsets.only(top: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFf8fafc),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFf1f5f9)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'MOTIVO',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF64748b),
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        traslado.motivo,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF1e293b),
                          height: 1.4,
                        ),
                      ),
                      if (traslado.observaciones != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          traslado.observaciones!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748b),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return Colors.green;
      case 'en espera':
        return Colors.blue;
      case 'mantenimiento':
        return Colors.orange;
      case 'baja':
        return Colors.red;
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
}
