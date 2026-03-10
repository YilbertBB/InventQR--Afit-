import 'dart:math' as math;
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../providers/revision_provider.dart';
import '../../models/equipo.dart';
import '../../models/equipo_revisado.dart';
import '../../services/pdf_report_service.dart';
import '../../services/storage_service.dart';
import '../../core/app_theme.dart';

class ReporteRevisionPage extends StatefulWidget {
  const ReporteRevisionPage({super.key});

  @override
  State<ReporteRevisionPage> createState() => _ReporteRevisionPageState();
}

class _ReporteRevisionPageState extends State<ReporteRevisionPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _selectedTabIndex = 0;

  // Listas para los datos procesados
  List<Map<String, dynamic>> _equiposFaltantes = [];
  List<Map<String, dynamic>> _equiposSobrantes = [];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });

    // Procesar los datos después del build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _procesarDatosReporte();
    });
  }

  void _procesarDatosReporte() {
    final provider = context.read<RevisionProvider>();
    final reporte = provider.obtenerReporteActual();

    if (reporte.isNotEmpty) {
      setState(() {
        // Equipos faltantes (en BD pero no escaneados)
        _equiposFaltantes = (reporte['faltantes'] as List<Equipo>).map((e) {
          return {
            'nombre': e.nombre,
            'id': e.numeroSerie.isNotEmpty ? e.numeroSerie : e.id,
            'tipo': _getTipoIcono(e.tipo),
            'estado': 'FALTANTE',
            'ultimaUbicacion':
                'Depto. ${e.departamentoNombre ?? "Desconocido"}',
            'perteneceA': null,
            'colorEstado': Colors.red,
            'equipo': e,
          };
        }).toList();

        // Equipos sobrantes (escaneados de otros deptos)
        _equiposSobrantes = (reporte['sobrantes'] as List<EquipoRevisado>).map((
          er,
        ) {
          return {
            'nombre': er.nombreEquipo,
            'id': er.codigoQR.length > 15
                ? '${er.codigoQR.substring(0, 12)}...'
                : er.codigoQR,
            'tipo': _getTipoIcono(er.nombreEquipo),
            'estado': 'SOBRANTE',
            'ultimaUbicacion': null,
            'perteneceA': 'Depto. Origen',
            'colorEstado': const Color(0xFFeca413),
            'equipoRevisado': er,
          };
        }).toList();
      });
    }
  }

  String _getTipoIcono(String nombre) {
    final nombreLower = nombre.toLowerCase();
    if (nombreLower.contains('laptop') || nombreLower.contains('mac')) {
      return 'laptop_mac';
    } else if (nombreLower.contains('monitor') ||
        nombreLower.contains('pantalla')) {
      return 'monitor';
    } else if (nombreLower.contains('impresora') ||
        nombreLower.contains('print')) {
      return 'print';
    } else if (nombreLower.contains('teclado')) {
      return 'keyboard';
    } else if (nombreLower.contains('mouse') || nombreLower.contains('ratón')) {
      return 'mouse';
    } else if (nombreLower.contains('silla')) {
      return 'chair';
    } else if (nombreLower.contains('mesa') ||
        nombreLower.contains('escritorio')) {
      return 'table';
    } else {
      return 'devices';
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<RevisionProvider>();
    final revision = provider.revisionActual;

    if (revision == null) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => AppRoutes.goBack(context),
            icon: const Icon(Icons.arrow_back),
          ),
          title: const Text('Reporte no disponible'),
        ),
        body: const Center(
          child: Text('No hay información de revisión disponible'),
        ),
      );
    }

    final primaryColor = const Color(0xFF135bec);
    final totalEquipos = revision.totalEquipos;
    // final encontrados = revision.equiposEncontrados;
    final faltantes = revision.equiposFaltantes;
    final sobrantes = revision.equiposSobrantes;
    final correctos = revision.equiposCorrectos;

    final porcentajeConciliado = totalEquipos == 0
        ? 0.0
        : (correctos / totalEquipos);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFf8f7f6),
        shape: Border(bottom: BorderSide(color: const Color(0xFFe5e7eb))),
        leading: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () {
              provider.limpiarRevisionActual();
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
          'Reporte de Revisión',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: _compartirReporte,
            icon: Icon(Icons.share, color: Colors.black),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          color: const Color(0xFFf8f7f6),
          child: Column(
            children: [
              // Contenido principal
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    children: [
                      // Stats Summary
                      SizedBox(
                        height: 140,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Row(
                            children: [
                              Expanded(
                                child: _buildStatCard(
                                  label: 'Correctos',
                                  valor: correctos.toString(),
                                  valorColor: Colors.green,
                                  tendencia:
                                      '${(porcentajeConciliado * 100).toStringAsFixed(1)}%',
                                  iconoTendencia: Icons.check_circle,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  label: 'Faltantes',
                                  valor: faltantes.toString(),
                                  valorColor: Colors.red,
                                  tendencia: '$faltantes equipos',
                                  iconoTendencia: Icons.error_outline,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildStatCard(
                                  label: 'Sobrantes',
                                  valor: sobrantes.toString(),
                                  valorColor: primaryColor,
                                  tendencia: '$sobrantes equipos',
                                  iconoTendencia: Icons.warning,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Donut Chart Section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Container(
                          constraints: const BoxConstraints(minHeight: 300),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: const Color(0xFFe5e7eb)),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              Text(
                                'Estado de Conciliación',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.black,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Donut Chart
                              SizedBox(
                                width: 180,
                                height: 180,
                                child: Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    // Fondo del círculo
                                    CircularProgressIndicator(
                                      value: 1.0,
                                      strokeWidth: 12,
                                      color: const Color(0xFFe5e7eb),
                                    ),

                                    // Segmento completado
                                    CustomPaint(
                                      painter: _CircularChartPainter(
                                        progress: porcentajeConciliado,
                                        color: Colors.green,
                                        backgroundColor: const Color(
                                          0xFFE2E8F0,
                                        ),
                                      ),
                                      size: const Size(180, 180),
                                    ),

                                    // Texto centrado
                                    Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          '${(porcentajeConciliado * 100).toStringAsFixed(1)}%',
                                          style: TextStyle(
                                            fontSize: 36,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.black,
                                          ),
                                        ),
                                        Text(
                                          'CONCILIADO',
                                          style: TextStyle(
                                            fontSize: 10,
                                            fontWeight: FontWeight.w500,
                                            color: const Color(0xFF6b7280),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),

                              const SizedBox(height: 24),

                              // Leyenda
                              Wrap(
                                spacing: 8,
                                alignment: WrapAlignment.center,
                                children: [
                                  _buildChip(
                                    color: Colors.green,
                                    label: 'Correctos',
                                    valor: correctos,
                                  ),
                                  _buildChip(
                                    color: Colors.red,
                                    label: 'Faltantes',
                                    valor: faltantes,
                                  ),
                                  _buildChip(
                                    color: primaryColor,
                                    label: 'Sobrantes',
                                    valor: sobrantes,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Tabs Section
                      SizedBox(
                        height: 120,
                        child: Column(
                          children: [
                            // Header
                            Padding(
                              padding: const EdgeInsets.only(
                                top: 24,
                                left: 16,
                                right: 16,
                              ),
                              child: Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Detalle de Activos',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Tabs
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                              ),
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(
                                      color: const Color(0xFFe5e7eb),
                                    ),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildTabItem(
                                        label:
                                            'Faltantes (${_equiposFaltantes.length})',
                                        isSelected: _selectedTabIndex == 0,
                                        onTap: () {
                                          _tabController.animateTo(0);
                                        },
                                      ),
                                    ),
                                    Expanded(
                                      child: _buildTabItem(
                                        label:
                                            'Sobrantes (${_equiposSobrantes.length})',
                                        isSelected: _selectedTabIndex == 1,
                                        onTap: () {
                                          _tabController.animateTo(1);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // TabBarView
                      SizedBox(
                        height: 400,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            // Tab 1: Faltantes
                            _equiposFaltantes.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 64,
                                          color: Colors.green[200],
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          '¡No hay equipos faltantes!',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _equiposFaltantes.length,
                                    itemBuilder: (context, index) {
                                      return _buildActivoCard(
                                        data: _equiposFaltantes[index],
                                        isExcedente: false,
                                      );
                                    },
                                  ),

                            // Tab 2: Sobrantes
                            _equiposSobrantes.isEmpty
                                ? Center(
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          Icons.check_circle,
                                          size: 64,
                                          color: Colors.green[200],
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          '¡No hay equipos sobrantes!',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ],
                                    ),
                                  )
                                : ListView.builder(
                                    padding: const EdgeInsets.all(16),
                                    itemCount: _equiposSobrantes.length,
                                    itemBuilder: (context, index) {
                                      return _buildActivoCard(
                                        data: _equiposSobrantes[index],
                                        isExcedente: true,
                                      );
                                    },
                                  ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),

      // Bottom Actions
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.9),
          border: Border(top: BorderSide(color: const Color(0xFFe5e7eb))),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Botón Exportar
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () => _exportarReportePDF(context),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: const Color(0xFFf3f4f6),
                      foregroundColor: Colors.black,
                      side: BorderSide(color: const Color(0xFFd1d5db)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    icon: const Icon(Icons.picture_as_pdf),
                    label: const Text('Exportar PDF'),
                  ),
                ),
                const SizedBox(height: 12),

                // Botón Finalizar
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _finalizarAuditoria,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: primaryColor,
                      foregroundColor: const Color(0xFFf3f4f6),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: primaryColor.withValues(alpha: 0.2),
                      textStyle: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    icon: const Icon(Icons.check_circle),
                    label: const Text('Finalizar Auditoría'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard({
    required String label,
    required String valor,
    required Color valorColor,
    required String tendencia,
    required IconData iconoTendencia,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe5e7eb)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6b7280),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            valor,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: valorColor,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(iconoTendencia, size: 14, color: valorColor),
              const SizedBox(width: 4),
              Text(
                tendencia,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: valorColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildChip({
    required Color color,
    required String label,
    required int valor,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$label $valor',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 12, top: 16),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected
                    ? const Color(0xFF135bec)
                    : (const Color(0xFF6b7280)),
              ),
            ),
          ),
          Container(
            height: 2,
            color: isSelected ? const Color(0xFF135bec) : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildActivoCard({
    required Map<String, dynamic> data,
    required bool isExcedente,
  }) {
    final backgroundColor = isExcedente
        ? const Color(0xFFfef3c7).withValues(alpha: 0.3)
        : const Color(0xFFfef2f2).withValues(alpha: 0.3);

    final borderColor = isExcedente
        ? const Color(0xFFeca413).withValues(alpha: 0.2)
        : Colors.red.withValues(alpha: 0.2);

    final iconColor = isExcedente ? const Color(0xFFeca413) : Colors.red;
    final icono = _getIconFromString(data['tipo'] ?? 'devices');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(minHeight: 100),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: ListTile(
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icono, color: iconColor),
        ),
        title: Text(
          data['nombre'] ?? 'Sin nombre',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'ID: ${data['id'] ?? 'N/A'}',
              style: TextStyle(fontSize: 12, color: const Color(0xFF6b7280)),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  isExcedente ? Icons.swap_calls : Icons.location_on,
                  size: 16,
                  color: data['colorEstado'],
                ),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    isExcedente
                        ? (data['perteneceA'] ?? 'Origen desconocido')
                        : (data['ultimaUbicacion'] ?? 'Ubicación desconocida'),
                    style: TextStyle(
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      fontWeight: FontWeight.w500,
                      color: data['colorEstado'],
                    ),
                    softWrap: true,
                    maxLines: 2,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: data['colorEstado'].withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            data['estado'] ?? '',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: data['colorEstado'],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getIconFromString(String tipo) {
    switch (tipo) {
      case 'laptop_mac':
        return Icons.laptop_mac;
      case 'print':
        return Icons.print;
      case 'monitor':
        return Icons.monitor;
      case 'keyboard':
        return Icons.keyboard;
      case 'mouse':
        return Icons.mouse;
      case 'chair':
        return Icons.chair;
      case 'table':
        return Icons.table_restaurant;
      default:
        return Icons.devices;
    }
  }

  // ============================================
  // ✅ NUEVO: Exportar Reporte a PDF
  // ============================================
  Future<void> _exportarReportePDF(BuildContext context) async {
    final provider = Provider.of<RevisionProvider>(context, listen: false);

    if (provider.revisionActual == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay una revisión activa para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Mostrar diálogo de carga
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      // Verificar permisos de almacenamiento
      final hasPermission =
          await StorageService.solicitarPermisosAlmacenamiento();

      if (!hasPermission) {
        if (context.mounted) {
          Navigator.pop(context); // Cerrar diálogo de carga
          _showPermissionDialog();
        }
        return;
      }

      // Asegurar que existen las carpetas
      await StorageService.inicializarCarpetas();

      // Obtener datos
      final revision = provider.revisionActual!;
      final equipos = provider.equiposDepartamento;
      final revisados = provider.equiposRevisados;
      if (!context.mounted) return;

      // Generar PDF
      final pdfFile = await PDFReportService.generarReporteRevision(
        revision: revision,
        equiposDepartamento: equipos,
        equiposRevisados: revisados,
        context: context,
      );

      // Cerrar diálogo de carga
      if (context.mounted) {
        Navigator.pop(context);
      }

      if (pdfFile != null) {
        _showPDFOptions(pdfFile);
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Error al generar el PDF'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // ============================================
  // ✅ NUEVO: Mostrar opciones del PDF
  // ============================================
  void _showPDFOptions(File pdfFile) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: const Color(0xFFE2E8F0),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const Center(
                child: Text(
                  'Reporte PDF Generado',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111318),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                pdfFile.path.split('/').last,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.share, color: AppTheme.primaryColor),
                ),
                title: const Text('Compartir Reporte'),
                subtitle: const Text('Compartir vía WhatsApp, Email, etc.'),
                onTap: () async {
                  Navigator.pop(context);
                  await PDFReportService.compartirReporte(pdfFile);
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_open, color: Colors.green),
                ),
                title: const Text('Abrir Carpeta'),
                subtitle: const Text('Ver archivo en el gestor de archivos'),
                onTap: () {
                  Navigator.pop(context);
                  _showFileLocation(pdfFile);
                },
              ),

              const SizedBox(height: 20),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Cerrar',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // ✅ NUEVO: Mostrar ubicación del archivo
  // ============================================
  void _showFileLocation(File file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅ PDF guardado en:'),
            const SizedBox(height: 4),
            Text(file.path, style: const TextStyle(fontSize: 11)),
          ],
        ),
        backgroundColor: AppTheme.primaryColor,
        duration: const Duration(seconds: 5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================
  // ✅ NUEVO: Diálogo de permisos
  // ============================================
  void _showPermissionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Permisos necesarios'),
        content: const Text(
          'Para guardar el reporte PDF, necesitamos permisos de almacenamiento.\n\n'
          'Por favor, concede los permisos desde la configuración de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // openAppSettings();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // ✅ ACTUALIZADO: Compartir reporte (usando PDF)
  // ============================================
  void _compartirReporte() {
    // Reutilizar la misma lógica de exportar pero sin guardar
    _exportarReportePDF(context);
  }

  // ============================================
  // Finalizar Auditoría (sin cambios)
  // ============================================
  void _finalizarAuditoria() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Finalizar Auditoría'),
        content: const Text(
          '¿Estás seguro de que quieres finalizar la auditoría?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () {
              final provider = context.read<RevisionProvider>();
              provider.limpiarRevisionActual();
              Navigator.pop(context);
              AppRoutes.goToDashboard(context);
            },
            child: const Text('Finalizar'),
          ),
        ],
      ),
    );
  }
}

class _CircularChartPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color backgroundColor;

  _CircularChartPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    const double strokeWidth = 12.0;

    // Background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, backgroundPaint);

    // Progress arc
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final double sweepAngle = 2 * math.pi * progress;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
