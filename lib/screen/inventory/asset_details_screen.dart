import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../core/app_routes.dart';
import '../../database/database_helper.dart';
import '../../models/equipo.dart';
import '../../providers/asignacion_provider.dart';
import '../../providers/equipo_provider.dart';
import '../../services/app_storage_service.dart';
import 'add_asset_screen.dart';
import 'assign_equipo_screen.dart';
import 'history_traslado_screen.dart';
import 'transfer_screen.dart';
import '../../core/app_theme.dart';

class AssetDetailScreen extends StatefulWidget {
  final String equipoId;

  const AssetDetailScreen({super.key, required this.equipoId});

  @override
  State<AssetDetailScreen> createState() => _AssetDetailScreenState();
}

class _AssetDetailScreenState extends State<AssetDetailScreen> {
  late Future<Equipo?> _equipoFuture;
  List<Map<String, dynamic>> _historialAsignaciones = [];
  List<Map<String, dynamic>> _historialTraslados = [];
  bool _cargandoHistorial = false;

  @override
  void initState() {
    super.initState();
    _cargarDatosIniciales();
  }

  Future<void> _cargarDatosIniciales() async {
    _equipoFuture = _cargarEquipo();
    await _cargarHistorialCompleto();
  }

  Future<Equipo?> _cargarEquipo() async {
    final provider = Provider.of<EquipoProvider>(context, listen: false);
    return await provider.obtenerEquipoPorId(widget.equipoId);
  }

  Future<void> _cargarHistorialCompleto() async {
    setState(() => _cargandoHistorial = true);

    try {
      await Future.wait([
        _cargarHistorialAsignaciones(),
        _cargarHistorialTraslados(),
      ]);
    } catch (e) {
      debugPrint('Error cargando historial: $e');
    } finally {
      setState(() => _cargandoHistorial = false);
    }
  }

  Future<void> _cargarHistorialAsignaciones() async {
    try {
      final asignacionProvider = Provider.of<AsignacionProvider>(
        context,
        listen: false,
      );

      final historial = await asignacionProvider.obtenerHistorialPorEquipo(
        widget.equipoId,
      );

      setState(() {
        _historialAsignaciones = historial.map((asignacion) {
          return {
            'id': asignacion.id,
            'trabajador_nombre': asignacion.trabajadorNombre,
            'fecha_asignacion': asignacion.fechaAsignacion,
            'fecha_desasignacion': asignacion.fechaDesasignacion,
            'motivo_asignacion': asignacion.motivoAsignacion,
            'motivo_desasignacion': asignacion.motivoDesasignacion,
            'usuario_asignador':
                asignacion.usuarioAsignadorNombre ??
                asignacion.usuarioAsignadorId,
            'estado': asignacion.estado,
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error cargando asignaciones: $e');
    }
  }

  // lib/screens/asset_detail_screen.dart

  Future<void> _cargarHistorialTraslados() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final resultados = await db.query(
        'traslados',
        where: 'equipo_id = ?',
        whereArgs: [widget.equipoId],
        orderBy: 'fecha_traslado DESC',
      );

      setState(() {
        _historialTraslados = resultados.map((map) {
          return {
            'id': map['id'],
            'desde_departamento': map['desde_departamento_nombre'],
            'hacia_departamento': map['hacia_departamento_nombre'],
            'fecha_traslado': DateTime.parse(map['fecha_traslado'] as String),
            'motivo': map['motivo'],
            'usuario_realizador':
                map['usuario_realizador'], // ✅ ID (para fallback)
            'usuario_realizador_nombre':
                map['usuario_realizador_nombre'], // ✅ NOMBRE (el que quieres mostrar)
            'observaciones': map['observaciones'],
          };
        }).toList();
      });
    } catch (e) {
      debugPrint('Error cargando traslados: $e');
    }
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
        centerTitle: true,
        backgroundColor: backgroundColor.withValues(alpha: 0.95),
        title: FutureBuilder<Equipo?>(
          future: _equipoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Text(
                'Cargando...',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              );
            }
            return Text(
              snapshot.data?.nombre ?? 'Detalle del Equipo',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
                letterSpacing: -0.3,
              ),
            );
          },
        ),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 24,
          ),
        ),
        actions: [
          // En AssetDetailScreen - botón de historial
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => HistoryScreen(
                    equipoId: widget.equipoId, // 👈 PASAR EL ID DEL EQUIPO
                  ),
                ),
              );
            },
            icon: const Icon(Icons.history),
          ),
        ],
        elevation: 0,
      ),
      body: SafeArea(
        child: FutureBuilder<Equipo?>(
          future: _equipoFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            if (snapshot.hasError || snapshot.data == null) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Error al cargar el equipo',
                      style: TextStyle(fontSize: 18, color: Colors.red),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _cargarDatosIniciales();
                        });
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                      ),
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              );
            }

            final equipo = snapshot.data!;
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildHeader(surfaceColor, borderColor, equipo),
                  const SizedBox(height: 16),
                  _buildQrSection(primaryColor, equipo),
                  const SizedBox(height: 24),
                  _buildInfoSection(
                    equipo,
                    surfaceColor,
                    borderColor,
                    textColor,
                  ),
                  const SizedBox(height: 24),
                  _buildStatusActions(equipo, primaryColor),
                  const SizedBox(height: 24),
                  _buildHistorySection(
                    primaryColor,
                    textColor,
                    borderColor,
                    surfaceColor,
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            );
          },
        ),
      ),
      bottomNavigationBar: FutureBuilder<Equipo?>(
        future: _equipoFuture,
        builder: (context, snapshot) {
          if (snapshot.data == null) return const SizedBox.shrink();
          return _buildBottomActions(
            primaryColor,
            surfaceColor,
            borderColor,
            snapshot.data!,
          );
        },
      ),
    );
  }

  // ============================================
  // HEADER SECTION
  // ============================================

  Widget _buildHeader(Color surfaceColor, Color borderColor, Equipo equipo) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: _getIconColor(equipo.tipo).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              _getIconForType(equipo.tipo),
              size: 40,
              color: _getIconColor(equipo.tipo),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  equipo.nombre,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111827),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: _getStatusColor(
                      equipo.estado,
                    ).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    equipo.estado.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(equipo.estado),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Código: ${equipo.codigoQR}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // QR SECTION
  // ============================================

  // ============================================
  // QR SECTION - VERSIÓN CORREGIDA CON QR REAL
  // ============================================

  Widget _buildQrSection(Color primaryColor, Equipo equipo) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // ✅ QR REAL usando qr_flutter
              Container(
                width: 200,
                height: 200,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: QrImageView(
                  data: equipo.codigoQR, // ✅ El código QR real del equipo
                  version: QrVersions.auto,
                  size: 184,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.M,
                  padding: const EdgeInsets.all(4),
                ),
              ),
              const SizedBox(height: 16),

              // Código QR en texto
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  equipo.codigoQR,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[800],
                    letterSpacing: 1,
                    fontFamily: 'RobotoMono',
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Botón para compartir/ampliar QR
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: () {
                      _showFullScreenQR(context, equipo.codigoQR);
                    },
                    icon: const Icon(Icons.zoom_out_map),
                    color: primaryColor,
                    tooltip: 'Ver QR ampliado',
                  ),
                  IconButton(
                    onPressed: () {
                      _copyQRCode(equipo.codigoQR);
                    },
                    icon: const Icon(Icons.copy),
                    color: primaryColor,
                    tooltip: 'Copiar código QR',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Escanea este código QR para auditoría rápida',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ✅ Mostrar QR en pantalla completa
  void _showFullScreenQR(BuildContext context, String qrData) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Código QR del Equipo',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                  ),
                ),
                child: QrImageView(
                  data: qrData,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              SelectableText(
                qrData,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  minimumSize: const Size(double.infinity, 45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ✅ Copiar código QR al portapapeles
  void _copyQRCode(String qrData) async {
    await Clipboard.setData(ClipboardData(text: qrData));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Código QR copiado al portapapeles'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================
  // INFO SECTION
  // ============================================

  Widget _buildInfoSection(
    Equipo equipo,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 16),
            child: Text(
              'Información General',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              children: [
                _buildInfoRow(
                  'Tipo',
                  equipo.tipo,
                  Icons.devices,
                  _getIconColor(equipo.tipo),
                ),
                _buildDivider(),
                _buildInfoRow(
                  'Marca',
                  equipo.marca,
                  Icons.business,
                  Colors.grey[600]!,
                ),
                _buildDivider(),
                _buildInfoRow(
                  'Modelo',
                  equipo.modelo,
                  Icons.model_training,
                  Colors.grey[600]!,
                ),
                _buildDivider(),
                _buildInfoRow(
                  'N° Serie',
                  equipo.numeroSerie,
                  Icons.qr_code,
                  Colors.grey[600]!,
                ),
                _buildDivider(),
                _buildInfoRow(
                  'Departamento',
                  // ✅ Si es "Sin departamento", mostrar vacío
                  equipo.departamentoNombre != null &&
                          equipo.departamentoNombre != 'Sin departamento'
                      ? equipo.departamentoNombre!
                      : '—',
                  Icons.apartment,
                  equipo.departamentoNombre != null &&
                          equipo.departamentoNombre != 'Sin departamento'
                      ? AppTheme.primaryColor
                      : Colors.grey,
                ),
                _buildDivider(),
                _buildInfoRow(
                  'Asignado a',
                  equipo.trabajadorNombre ?? 'No asignado',
                  Icons.person,
                  equipo.estaAsignado ? Colors.green : Colors.grey,
                ),
                if (equipo.proyectoNombre != null) ...[
                  _buildDivider(),
                  _buildInfoRow(
                    'Proyecto',
                    equipo.proyectoNombre!,
                    Icons.work,
                    Colors.grey[600]!,
                  ),
                ],
                if (equipo.costo != null) ...[
                  _buildDivider(),
                  _buildInfoRow(
                    'Costo',
                    'S/ ${equipo.costo!.toStringAsFixed(2)}',
                    Icons.attach_money,
                    Colors.grey[600]!,
                  ),
                ],
                _buildDivider(),
                _buildInfoRow(
                  'Adquisición',
                  '${equipo.fechaAdquisicion.day}/${equipo.fechaAdquisicion.month}/${equipo.fechaAdquisicion.year}',
                  Icons.calendar_today,
                  Colors.grey[600]!,
                ),
                if (equipo.fechaAsignacion != null) ...[
                  _buildDivider(),
                  _buildInfoRow(
                    'Última asignación',
                    '${equipo.fechaAsignacion!.day}/${equipo.fechaAsignacion!.month}/${equipo.fechaAsignacion!.year}',
                    Icons.event,
                    Colors.green[700]!,
                  ),
                ],
                if (equipo.observaciones != null &&
                    equipo.observaciones!.isNotEmpty) ...[
                  _buildDivider(),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.note, size: 20, color: Colors.grey[600]),
                            const SizedBox(width: 12),
                            Text(
                              'Observaciones',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey[700],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          equipo.observaciones!,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[800],
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value,
    IconData icon,
    Color iconColor,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF111827),
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      thickness: 1,
      color: Colors.grey[200],
      indent: 16,
      endIndent: 16,
    );
  }

  // ============================================
  // STATUS ACTIONS
  // ============================================

  Widget _buildStatusActions(Equipo equipo, Color primaryColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(
            child: _buildActionCard(
              icon: equipo.estaAsignado
                  ? Icons.person_remove
                  : Icons.person_add,
              label: equipo.estaAsignado ? 'Desasignar' : 'Asignar',
              color: equipo.estaAsignado ? Colors.orange : Colors.green,
              onTap: () => _handleAssignment(equipo),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.swap_horiz,
              label: 'Trasladar',
              color: primaryColor,
              onTap: () => _handleTransfer(context, equipo),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildActionCard(
              icon: Icons.warning,
              label: 'Incidencia',
              color: Colors.red,
              onTap: () => _reportIssue(equipo),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================
  // HISTORY SECTION
  // ============================================

  Widget _buildHistorySection(
    Color primaryColor,
    Color textColor,
    Color borderColor,
    Color surfaceColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Historial de Movimientos',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF111827),
                ),
              ),
              TextButton(
                onPressed: () {
                  AppRoutes.goToHistorialTraslado(context);
                },
                style: TextButton.styleFrom(foregroundColor: primaryColor),
                child: const Text('Ver todo'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _cargandoHistorial
              ? const Center(child: CircularProgressIndicator())
              : _historialAsignaciones.isEmpty && _historialTraslados.isEmpty
              ? _buildEmptyHistory()
              : _buildTimeline(),
        ],
      ),
    );
  }

  Widget _buildEmptyHistory() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Icon(Icons.history, size: 48, color: Colors.grey[400]),
          const SizedBox(height: 12),
          Text(
            'Sin movimientos registrados',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Los traslados y asignaciones aparecerán aquí',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeline() {
    final List<dynamic> allMovements = [
      ..._historialAsignaciones.map((a) => {...a, 'tipo': 'asignacion'}),
      ..._historialTraslados.map((t) => {...t, 'tipo': 'traslado'}),
    ];

    allMovements.sort((a, b) {
      final fechaA = a['tipo'] == 'asignacion'
          ? a['fecha_asignacion'] as DateTime
          : a['fecha_traslado'] as DateTime;
      final fechaB = b['tipo'] == 'asignacion'
          ? b['fecha_asignacion'] as DateTime
          : b['fecha_traslado'] as DateTime;
      return fechaB.compareTo(fechaA);
    });

    final limitedMovements = allMovements.take(3).toList();

    return Column(
      children: limitedMovements.map((movement) {
        return _buildTimelineEntry(
          movement: movement,
          isLast: movement == limitedMovements.last,
        );
      }).toList(),
    );
  }

  Widget _buildTimelineEntry({
    required Map<String, dynamic> movement,
    required bool isLast,
  }) {
    final bool isAsignacion = movement['tipo'] == 'asignacion';

    if (isAsignacion) {
      return _buildAssignmentTimelineEntry(movement, isLast);
    } else {
      return _buildTransferTimelineEntry(movement, isLast);
    }
  }

  Widget _buildAssignmentTimelineEntry(
    Map<String, dynamic> asignacion,
    bool isLast,
  ) {
    final fecha = asignacion['fecha_asignacion'] as DateTime;
    final fechaStr = '${fecha.day}/${fecha.month}/${fecha.year}';
    final horaStr =
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    final isActive = asignacion['estado'] == 'activa';
    final hasDesasignacion = asignacion['fecha_desasignacion'] != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: isActive
                    ? Colors.green.withValues(alpha: 0.1)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isActive ? Colors.green : Colors.grey,
                  width: 1.5,
                ),
              ),
              child: Icon(
                isActive ? Icons.person_add : Icons.person_remove,
                color: isActive ? Colors.green : Colors.grey,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
                margin: const EdgeInsets.only(top: 8),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Container(
            margin: EdgeInsets.only(bottom: isLast ? 0 : 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      isActive ? 'Asignación Activa' : 'Asignación Finalizada',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isActive ? Colors.green[700] : Colors.grey[700],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '$fechaStr $horaStr',
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.person,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Asignado a: ${asignacion['trabajador_nombre']}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Por: ${asignacion['usuario_asignador']}',
                      style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                    ),
                  ],
                ),
                if (asignacion['motivo_asignacion'] != null) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MOTIVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          asignacion['motivo_asignacion'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (hasDesasignacion) ...[
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.event_busy,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Desasignado: ${_formatDate(asignacion['fecha_desasignacion'])}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.orange,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  if (asignacion['motivo_desasignacion'] != null) ...[
                    const SizedBox(height: 4),
                    Padding(
                      padding: const EdgeInsets.only(left: 24),
                      child: Text(
                        asignacion['motivo_desasignacion'],
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTransferTimelineEntry(
    Map<String, dynamic> traslado,
    bool isLast,
  ) {
    final fecha = traslado['fecha_traslado'] as DateTime;
    final fechaStr = '${fecha.day}/${fecha.month}/${fecha.year}';
    final horaStr =
        '${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';

    // ✅ OBTENER NOMBRE DEL USUARIO (CON FALLBACK AL ID)
    final usuarioNombre = traslado['usuario_realizador_nombre'] as String?;
    final usuarioId = traslado['usuario_realizador'] as String;

    // ✅ MOSTRAR NOMBRE SI EXISTE, SINO MOSTRAR ID CORTO
    String displayUser;
    if (usuarioNombre != null && usuarioNombre.isNotEmpty) {
      displayUser = usuarioNombre;
    } else {
      // Si no hay nombre, mostrar ID abreviado
      displayUser = usuarioId.length > 8
          ? 'Usuario ${usuarioId.substring(0, 6)}...'
          : 'Usuario $usuarioId';
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Timeline icon...
        Column(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.primaryColor, width: 1.5),
              ),
              child: const Icon(
                Icons.swap_horiz,
                color: AppTheme.primaryColor,
                size: 20,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 60,
                color: Colors.grey[300],
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
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header - VERSIÓN CON PUNTOS SUSPENSIVOS
                Row(
                  children: [
                    // Título con puntos suspensivos
                    Expanded(
                      child: const Text(
                        'Traslado de Departamento',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                        maxLines: 1,
                        overflow:
                            TextOverflow.ellipsis, // 👈 PUNTOS SUSPENSIVOS
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Fecha - ahora con ancho fijo mínimo para que no se encoja demasiado
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        fechaStr,
                        style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                        maxLines: 1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Departamentos - VERSIÓN CON WRAP PARA RESPONSIVE
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        traslado['desde_departamento'] ?? 'Sin departamento',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Icon(
                      Icons.arrow_forward,
                      size: 16,
                      color: AppTheme.primaryColor,
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        traslado['hacia_departamento'] ?? 'Sin departamento',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // USUARIO
                Row(
                  children: [
                    const Icon(
                      Icons.admin_panel_settings,
                      size: 16,
                      color: Colors.grey,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Por: $displayUser',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),

                // Fecha y hora completa
                Row(
                  children: [
                    const Icon(Icons.access_time, size: 16, color: Colors.grey),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$fechaStr • $horaStr',
                        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),

                // Motivo
                if (traslado['motivo'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'MOTIVO',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          traslado['motivo'],
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (traslado['observaciones'] != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            traslado['observaciones'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomActions(
    Color primaryColor,
    Color surfaceColor,
    Color borderColor,
    Equipo equipo,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      child: Row(
        children: [
          // Botón EDITAR (izquierda)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _editAsset(equipo),
              style: ElevatedButton.styleFrom(
                backgroundColor: surfaceColor,
                foregroundColor: primaryColor,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.edit, size: 20),
              label: const Text(
                'Editar',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // ✅ NUEVO: Botón EXPORTAR QR (derecha)
          Expanded(
            child: ElevatedButton.icon(
              onPressed: () => _exportarQR(equipo),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              icon: const Icon(Icons.qr_code_2, size: 20),
              label: const Text(
                'Exportar QR',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // MÉTODOS PARA EXPORTAR QR
  // ============================================

  // AÑADE ESTA DEPENDENCIA EN pubspec.yaml:
  // qr: ^3.0.1
  // o usa el paquete: qr_flutter ya lo tienes

  // ============================================
  // MÉTODOS CORREGIDOS PARA EXPORTAR QR
  // ============================================

  Future<void> _exportarQR(Equipo equipo) async {
    // Mostrar diálogo con opciones de exportación
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // ✅ Importante para contenido largo
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildExportOptions(equipo),
    );
  }

  Widget _buildExportOptions(Equipo equipo) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Center(
            child: Text(
              'Exportar Código QR',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111827),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Center(
            child: Text(
              'Selecciona el formato para exportar',
              style: TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),
          const SizedBox(height: 16),

          // ✅ VISTA PREVIA DEL QR - SIN ScreenshotController
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFE5E7EB),
                          width: 2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(
                              0xFF135BEC,
                            ).withValues(alpha: 0.1),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        color: Colors.white,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // ✅ QR NORMAL - solo para vista previa
                            QrImageView(
                              data: equipo.codigoQR,
                              version: QrVersions.auto,
                              size: 180,
                              backgroundColor: Colors.white,
                              eyeStyle: const QrEyeStyle(
                                eyeShape: QrEyeShape.square,
                                color: Colors.black,
                              ),
                              dataModuleStyle: const QrDataModuleStyle(
                                dataModuleShape: QrDataModuleShape.square,
                                color: Colors.black,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              equipo.codigoQR,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF374151),
                                fontFamily: 'RobotoMono',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              equipo.nombre,
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Opciones de exportación
                  Row(
                    children: [
                      Expanded(
                        child: _buildExportOption(
                          icon: Icons.download,
                          label: 'Guardar PNG',
                          color: const Color.fromARGB(255, 74, 101, 155),
                          onTap: () => _guardarQRComoPNG(equipo),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildExportOption(
                          icon: Icons.share,
                          label: 'Compartir',
                          color: Colors.green,
                          onTap: () => _compartirQR(equipo),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  _buildExportOption(
                    icon: Icons.copy,
                    label: 'Copiar código',
                    color: Colors.purple,
                    onTap: () => _copiarCodigoQR(equipo),
                    isFullWidth: true,
                  ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),

          // Botón cerrar
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
    bool isFullWidth = false,
  }) {
    return GestureDetector(
      onTap: () {
        Navigator.pop(context); // ✅ Cerrar bottom sheet
        onTap(); // ✅ Ejecutar acción
      },
      child: Container(
        width: isFullWidth ? double.infinity : null,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: isFullWidth
              ? MainAxisAlignment.center
              : MainAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _guardarQRComoPNG(Equipo equipo) async {
    debugPrint('🔄 Generando QR como imagen...');

    try {
      // Generar QR
      final qrValidationResult = QrValidator.validate(
        data: equipo.codigoQR,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
      );

      if (qrValidationResult.status != QrValidationStatus.valid) {
        throw Exception('QR inválido');
      }

      // final qrCode = qrValidationResult.qrCode;
      final painter = QrPainter(
        data: equipo.codigoQR,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: false,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      const size = Size(600, 600);

      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(Offset.zero & size, backgroundPaint);
      painter.paint(canvas, size);
      final picture = pictureRecorder.endRecording();
      final img = await picture.toImage(600, 600);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List imageData = byteData!.buffer.asUint8List();

      // ✅ GUARDAR EN CARPETA QR_CODES DE LA APP
      final qrFolder = await AppStorageService.getQRFolder();
      final fileName = 'QR_${equipo.codigoQR.replaceAll('-', '_')}.png';
      final file = File('${qrFolder.path}/$fileName');
      await file.writeAsBytes(imageData);

      debugPrint('✅ QR guardado en: ${file.path}');

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('✅ QR guardado exitosamente'),
              Text('📁 ${file.path}', style: const TextStyle(fontSize: 11)),
            ],
          ),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      debugPrint('❌ Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ✅ Compartir QR (generado directamente)
  Future<void> _compartirQR(Equipo equipo) async {
    try {
      // Crear painter con los parámetros correctos
      final painter = QrPainter(
        data: equipo.codigoQR,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.M,
        gapless: false,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      final pictureRecorder = ui.PictureRecorder();
      final canvas = Canvas(pictureRecorder);
      final size = Size(600, 600);

      final backgroundPaint = Paint()..color = Colors.white;
      canvas.drawRect(Offset.zero & size, backgroundPaint);
      painter.paint(canvas, size);
      final picture = pictureRecorder.endRecording();
      final img = await picture.toImage(600, 600);
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List imageData = byteData!.buffer.asUint8List();

      // Guardar temporal
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(
        '${tempDir.path}/qr_${DateTime.now().millisecondsSinceEpoch}.png',
      );
      await tempFile.writeAsBytes(imageData);

      // Compartir
      await SharePlus.instance.share(
        ShareParams(
          text: '📱 Código QR: ${equipo.codigoQR}\n📦 Equipo: ${equipo.nombre}',
          files: [XFile(tempFile.path)],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error al compartir: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // ✅ Imprimir QR
  // Future<void> _imprimirQR(Equipo equipo) async {
  //   // Usar el mismo método de compartir
  //   await _compartirQR(equipo);
  // }

  // ✅ 4. COPIAR CÓDIGO QR (TEXTO)
  Future<void> _copiarCodigoQR(Equipo equipo) async {
    await Clipboard.setData(ClipboardData(text: equipo.codigoQR));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Código QR copiado al portapapeles'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  // ============================================
  // ACCIONES
  // ============================================

  void _handleAssignment(Equipo equipo) async {
    if (equipo.estaAsignado) {
      _showDesasignarDialog(equipo);
    } else {
      // Navegar a pantalla de asignación
      final result = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssignEquipoScreen(
            equipoId: equipo.id,
            equipoNombre: equipo.nombre,
            departamentoId: equipo.departamentoId,
          ),
        ),
      );

      if (result == true && mounted) {
        // ✅ Recargar equipo y equipos
        setState(() {
          _cargarDatosIniciales();
        });

        // También recargar en el provider global
        Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
      }
    }
  }

  void _showDesasignarDialog(Equipo equipo) {
    final screenContext = context;
    final motivoController = TextEditingController();

    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Desasignar Equipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Desasignar ${equipo.nombre} de ${equipo.trabajadorNombre}?'),
            const SizedBox(height: 16),
            TextField(
              controller: motivoController,
              decoration: const InputDecoration(
                labelText: 'Motivo de desasignación',
                hintText: 'Ej. Cambio de equipo, devolución, mantenimiento',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              motivoController.dispose(); // ✅ DISPOSE AL CANCELAR
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              final motivo = motivoController.text;

              // ✅ 1. DISPOSE CONTROLADOR
              motivoController.dispose();

              // ✅ 2. CERRAR DIÁLOGO
              Navigator.pop(dialogContext);

              // ✅ 3. DESASIGNAR
              if (screenContext.mounted) {
                try {
                  final asignacionProvider = Provider.of<AsignacionProvider>(
                    screenContext,
                    listen: false,
                  );

                  final success = await asignacionProvider.desasignarEquipo(
                    equipoId: equipo.id,
                    motivo: motivo.isNotEmpty ? motivo : 'Desasignación manual',
                  );

                  if (success && screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Equipo desasignado exitosamente'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    setState(() {
                      _cargarDatosIniciales();
                    });

                    Provider.of<EquipoProvider>(
                      screenContext,
                      listen: false,
                    ).cargarEquipos();
                  }
                } catch (e) {
                  if (screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Desasignar'),
          ),
        ],
      ),
    );
  }

  // En AssetDetailScreen
  void _handleTransfer(BuildContext context, Equipo equipo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => TransferScreen(
          equipoId: equipo.id,
          equipoNombre: equipo.nombre,
          departamentoActualId: equipo.departamentoId,
          departamentoActualNombre: equipo.departamentoNombre,
        ),
      ),
    );

    if (result == true && context.mounted) {
      await _cargarDatosIniciales();
      if (context.mounted) {
        setState(() {});
      }
      if (context.mounted) {
        Provider.of<EquipoProvider>(context, listen: false).cargarEquipos();
      }
    }
  }

  void _reportIssue(Equipo equipo) {
    showDialog(
      context: context,
      builder: (context) {
        final descripcionController = TextEditingController();
        String? tipoIncidencia = 'hardware';

        return StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: const Text('Reportar Incidencia'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Equipo: ${equipo.nombre}'),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: tipoIncidencia,
                  decoration: const InputDecoration(
                    labelText: 'Tipo de incidencia',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'hardware',
                      child: Text('Hardware'),
                    ),
                    DropdownMenuItem(
                      value: 'software',
                      child: Text('Software'),
                    ),
                    DropdownMenuItem(
                      value: 'fisico',
                      child: Text('Daño Físico'),
                    ),
                    DropdownMenuItem(
                      value: 'conectividad',
                      child: Text('Conectividad'),
                    ),
                    DropdownMenuItem(value: 'other', child: Text('Otro')),
                  ],
                  onChanged: (value) => setState(() => tipoIncidencia = value),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descripcionController,
                  decoration: const InputDecoration(
                    labelText: 'Descripción del problema',
                    hintText: 'Describe detalladamente la incidencia...',
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Incidencia reportada para ${equipo.nombre}',
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                child: const Text('Reportar'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _editAsset(Equipo equipo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddAssetScreen(equipo: equipo)),
    );

    if (result == true && mounted) {
      setState(() {
        _cargarDatosIniciales();
      });
    }
  }

  // ============================================
  // MÉTODOS AUXILIARES
  // ============================================

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    return '${date.day}/${date.month}/${date.year}';
  }

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
}
