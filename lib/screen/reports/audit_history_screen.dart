import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../providers/revision_provider.dart';
import '../../models/revision.dart';

class AuditHistoryScreen extends StatefulWidget {
  const AuditHistoryScreen({super.key});

  @override
  State<AuditHistoryScreen> createState() => _AuditHistoryScreenState();
}

class _AuditHistoryScreenState extends State<AuditHistoryScreen> {
  final int _selectedFilterIndex = 0;

  List<Revision> _revisiones = [];
  bool _cargando = false;

  @override
  void initState() {
    super.initState();
    _cargarHistorial();
  }

  Future<void> _cargarHistorial() async {
    setState(() => _cargando = true);

    final provider = context.read<RevisionProvider>();
    await provider.cargarHistorialRevisiones();

    if (mounted) {
      setState(() {
        _revisiones = provider.historialRevisiones;
        _cargando = false;
      });
    }
  }

  List<Revision> get _revisionesFiltradas {
    if (_revisiones.isEmpty) return [];

    switch (_selectedFilterIndex) {
      case 1: // Por departamento
        return _revisiones..sort(
          (a, b) => a.departamentoNombre.compareTo(b.departamentoNombre),
        );
      case 2: // Por fecha
        return _revisiones
          ..sort((a, b) => b.fechaRevision.compareTo(a.fechaRevision));
      case 3: // Por estado
        return _revisiones..sort((a, b) => a.estado.compareTo(b.estado));
      default: // Todo - por fecha descendente
        return _revisiones
          ..sort((a, b) => b.fechaRevision.compareTo(a.fechaRevision));
    }
  }

  Map<String, dynamic> _getEstadisticasMensuales() {
    final now = DateTime.now();
    final primerDiaMes = DateTime(now.year, now.month, 1);

    final revisionesEsteMes = _revisiones
        .where(
          (r) =>
              r.fechaRevision.isAfter(primerDiaMes) ||
              r.fechaRevision.isAtSameMomentAs(primerDiaMes),
        )
        .toList();

    final completadas = revisionesEsteMes.where((r) => r.estaCompletada).length;
    final totalDepartamentos = _revisiones
        .map((r) => r.departamentoId)
        .toSet()
        .length;

    final progreso = totalDepartamentos == 0
        ? 0.0
        : completadas / totalDepartamentos;

    return {
      'progreso': progreso,
      'completadas': completadas,
      'total': totalDepartamentos,
      'porcentaje': (progreso * 100).toStringAsFixed(0),
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.primaryColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final surfaceColor = isDark
        ? const Color(0xFF1E293B).withValues(alpha: 0.5)
        : Colors.white;
    final borderColor = isDark
        ? const Color(0xFF334155)
        : const Color(0xFFE5E7EB);
    final textColor = isDark
        ? const Color(0xFFF1F5F9)
        : const Color(0xFF111827);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
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
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 24),
          ),
        ),
        title: Text(
          'Historial de Revisiones',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFf6f6f8),
        actions: [
          IconButton(
            onPressed: _cargarHistorial,
            style: IconButton.styleFrom(
              backgroundColor: isDark ? Colors.white12 : Colors.black12,
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
            // Content Area
            Expanded(
              child: RefreshIndicator(
                onRefresh: _cargarHistorial,
                color: primaryColor,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // Summary Stats Card
                      _buildSummaryCard(primaryColor, isDark),

                      // Recent Header
                      _buildRecentHeader(isDark),

                      // Lista de revisiones
                      if (_cargando)
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(),
                          ),
                        )
                      else if (_revisionesFiltradas.isEmpty)
                        _buildEmptyState(primaryColor, isDark)
                      else
                        ..._buildRevisionListItems(
                          surfaceColor,
                          borderColor,
                          textColor,
                          isDark,
                        ),

                      const SizedBox(height: 80),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: const Color(0xFFe2e8f0))),
        ),
        child: BottomAppBar(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.white.withValues(alpha: 0.95),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.apartment,
                label: 'Departamentos',
                isActive: false,
                onTap: () => AppRoutes.goToSelectDepartments(context),
              ),

              _buildBottomNavItem(
                icon: Icons.history,
                label: 'Historial',
                isActive: true,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(48),
      child: Column(
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No hay revisiones',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Las revisiones que realices aparecerán aquí',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              AppRoutes.goToSelectDepartments(context);
            },
            icon: const Icon(Icons.add),
            label: const Text('Nueva Revisión'),
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(Color primaryColor, bool isDark) {
    final stats = _getEstadisticasMensuales();

    return Container(
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: primaryColor.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Progreso Mensual',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: primaryColor,
                ),
              ),
              Text(
                '${stats['porcentaje']}%',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: stats['progreso'],
              backgroundColor: primaryColor.withValues(alpha: 0.2),
              color: primaryColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${stats['completadas']} de ${stats['total']} departamentos auditados este mes.',
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentHeader(bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 12, left: 4),
      child: Text(
        'HISTORIAL',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          letterSpacing: 1.5,
        ),
      ),
    );
  }

  List<Widget> _buildRevisionListItems(
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    bool isDark,
  ) {
    return _revisionesFiltradas.map((revision) {
      final isCompletada = revision.estaCompletada;
      final isEnCurso = revision.estaEnCurso;
      // final isCancelada = revision.estaCancelada;

      String estado;
      Color estadoColor;
      IconData icono;
      Color iconoColor;

      if (isCompletada) {
        estado = 'Finalizado';
        estadoColor = AppTheme.successColor;
        icono = Icons.check_circle;
        iconoColor = AppTheme.successColor;
      } else if (isEnCurso) {
        estado = 'En Progreso';
        estadoColor = AppTheme.warningColor;
        icono = Icons.pending_actions;
        iconoColor = AppTheme.warningColor;
      } else {
        estado = 'Cancelado';
        estadoColor = AppTheme.errorColor;
        icono = Icons.cancel;
        iconoColor = AppTheme.errorColor;
      }

      String progresoText;
      if (isCompletada) {
        progresoText =
            '${revision.equiposCorrectos}/${revision.totalEquipos} equipos correctos';
      } else if (isEnCurso) {
        progresoText =
            '${revision.equiposEncontrados}/${revision.totalEquipos} escaneados';
      } else {
        progresoText = 'Revisión cancelada';
      }

      return GestureDetector(
        onTap: () {
          _mostrarDetalleRevision(revision, textColor);
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: surfaceColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: borderColor),
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
              onTap: () {
                _mostrarDetalleRevision(revision, textColor);
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    // Icon Container
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: iconoColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icono, color: iconoColor, size: 24),
                    ),
                    const SizedBox(width: 16),

                    // Content
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  revision.departamentoNombre,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: textColor,
                                  ),
                                  maxLines: 1,
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
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  estado,
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: estadoColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),

                          if (isEnCurso) ...[
                            const SizedBox(height: 8),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                value: revision.totalEquipos == 0
                                    ? 0
                                    : revision.equiposEncontrados /
                                          revision.totalEquipos,
                                backgroundColor: isDark
                                    ? const Color(0xFF374151)
                                    : const Color(0xFFE5E7EB),
                                color: estadoColor,
                                minHeight: 6,
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],

                          Text(
                            progresoText,
                            style: TextStyle(
                              fontSize: 14,
                              color: isDark
                                  ? const Color(0xFF9CA3AF)
                                  : const Color(0xFF6B7280),
                            ),
                          ),

                          const SizedBox(height: 8),

                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              Icon(
                                Icons.person_outline,
                                size: 14,
                                color: isDark
                                    ? const Color(0xFF9CA3AF)
                                    : const Color(0xFF6B7280),
                              ),
                              Text(
                                revision.usuarioAuditorNombre ??
                                    'Administrador',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              Text(
                                _formatearFecha(revision.fechaRevision),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark
                                      ? const Color(0xFF9CA3AF)
                                      : const Color(0xFF6B7280),
                                ),
                              ),
                            ],
                          ),

                          if (revision.equiposFaltantes > 0 ||
                              revision.equiposSobrantes > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  if (revision.equiposFaltantes > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.red.withValues(
                                          alpha: 0.1,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${revision.equiposFaltantes} faltantes',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: Colors.red,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  const SizedBox(width: 8),
                                  if (revision.equiposSobrantes > 0)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFFF59E0B,
                                        ).withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        '${revision.equiposSobrantes} sobrantes',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: AppTheme.warningColor,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Chevron
                    Icon(
                      Icons.chevron_right,
                      color: isDark
                          ? const Color(0xFF6B7280)
                          : const Color(0xFFD1D5DB),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }).toList();
  }

  String _formatearFecha(DateTime fecha) {
    final now = DateTime.now();
    final diff = now.difference(fecha).inDays;

    if (diff == 0) {
      return 'Hoy, ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (diff == 1) {
      return 'Ayer, ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else if (diff < 7) {
      return '${_diasSemana[fecha.weekday - 1]}, ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
    } else {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
  }

  final List<String> _diasSemana = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? const Color(0xFF135bec)
                : (const Color(0xFF64748b)),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? const Color(0xFF135bec)
                  : const Color(0xFF64748b),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  void _mostrarDetalleRevision(Revision revision, Color textColor) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            padding: const EdgeInsets.all(24),
            child: Column(
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
                Text(
                  'Detalles de Revisión',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    children: [
                      _buildDetalleItem(
                        'Departamento',
                        revision.departamentoNombre,
                      ),
                      _buildDetalleItem(
                        'Auditor',
                        revision.usuarioAuditorNombre ?? 'Administrador',
                      ),
                      _buildDetalleItem(
                        'Fecha',
                        _formatearFechaCompleta(revision.fechaRevision),
                      ),
                      if (revision.fechaFinalizacion != null)
                        _buildDetalleItem(
                          'Finalizado',
                          _formatearFechaCompleta(revision.fechaFinalizacion!),
                        ),
                      _buildDetalleItem('Estado', revision.estado),
                      const Divider(height: 32),
                      _buildDetalleItem(
                        'Total equipos',
                        revision.totalEquipos.toString(),
                      ),
                      _buildDetalleItem(
                        'Correctos',
                        revision.equiposCorrectos.toString(),
                      ),
                      _buildDetalleItem(
                        'Faltantes',
                        revision.equiposFaltantes.toString(),
                      ),
                      _buildDetalleItem(
                        'Sobrantes',
                        revision.equiposSobrantes.toString(),
                      ),
                      if (revision.observaciones != null) ...[
                        const Divider(height: 32),
                        _buildDetalleItem(
                          'Observaciones',
                          revision.observaciones!,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Column(
                  children: [
                    if (revision.estaEnCurso)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () async {
                            final provider =
                                context.read<RevisionProvider>();
                            final reanudado =
                                await provider.reanudarRevision(revision.id);
                            if (!context.mounted) return;
                            if (reanudado) {
                              Navigator.pop(context);
                              AppRoutes.goToProgresoReport(context);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    provider.error ??
                                        'No se pudo reanudar la revisión',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
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
                          backgroundColor: AppTheme.primaryColor,
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
        },
      ),
    );
  }

  Widget _buildDetalleItem(String label, String valor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              valor,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  String _formatearFechaCompleta(DateTime fecha) {
    return '${fecha.day}/${fecha.month}/${fecha.year} ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
  }
}
