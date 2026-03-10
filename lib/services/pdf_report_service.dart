import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/revision.dart';
import '../models/equipo.dart';
import '../models/equipo_revisado.dart';
import 'storage_service.dart';

class PDFReportService {
  // Fuentes estáticas para reutilizar
  static pw.Font? _regularFont;
  static pw.Font? _boldFont;
  static bool _fontsLoaded = false;

  // ============================================
  // CARGAR FUENTES PERSONALIZADAS
  // ============================================
  static Future<void> _loadFonts() async {
    if (_fontsLoaded) return;

    try {
      debugPrint('🔄 Cargando fuentes personalizadas...');

      // Cargar fuente Roboto desde assets
      final fontData = await rootBundle.load("assets/fonts/Roboto-Regular.ttf");
      final boldFontData = await rootBundle.load(
        "assets/fonts/Roboto-Bold.ttf",
      );

      _regularFont = pw.Font.ttf(fontData.buffer.asByteData());
      _boldFont = pw.Font.ttf(boldFontData.buffer.asByteData());

      _fontsLoaded = true;
      debugPrint('✅ Fuentes Roboto cargadas correctamente');
    } catch (e) {
      debugPrint('⚠️ Error cargando fuentes: $e');
      debugPrint('⚠️ Usando fuentes estándar del PDF');
      _fontsLoaded = false;
    }
  }

  // ============================================
  // OBTENER ESTILO DE TEXTO - AHORA SIEMPRE USA LAS FUENTES CARGADAS
  // ============================================
  static pw.TextStyle _getTextStyle({
    double fontSize = 12,
    bool isBold = false,
    PdfColor? color,
  }) {
    if (_fontsLoaded) {
      return pw.TextStyle(
        font: isBold ? _boldFont : _regularFont,
        fontSize: fontSize,
        color: color,
      );
    }

    // Fallback crítico: usar fuentes estándar pero limpiar texto
    return pw.TextStyle(
      font: isBold ? pw.Font.helveticaBold() : pw.Font.helvetica(),
      fontSize: fontSize,
      color: color,
    );
  }

  // ============================================
  // LIMPIAR TEXTO DE CARACTERES ESPECIALES (FALLBACK)
  // ============================================
  static String _cleanTextForFallback(String text) {
    if (_fontsLoaded) return text; // Si hay fuentes Unicode, no limpiar

    return text
        .replaceAll('✅', '[OK]')
        .replaceAll('❌', '[X]')
        .replaceAll('⚠️', '[!]')
        .replaceAll('✓', '[V]')
        .replaceAll('️', '')
        .replaceAll('•', '-')
        .replaceAll('→', '->')
        .replaceAll('←', '<-');
  }

  // ============================================
  // GENERAR REPORTE DE REVISIÓN
  // ============================================
  static Future<File?> generarReporteRevision({
    required Revision revision,
    required List<Equipo> equiposDepartamento,
    required List<EquipoRevisado> equiposRevisados,
    required BuildContext context,
  }) async {
    try {
      // Cargar fuentes primero
      await _loadFonts();

      final pdf = pw.Document();

      // Colores corporativos
      final primaryColor = PdfColor.fromInt(0xFF135BEC);
      final successColor = PdfColor.fromInt(0xFF10B981);
      final warningColor = PdfColor.fromInt(0xFFF59E0B);
      final dangerColor = PdfColor.fromInt(0xFFEF4444);

      // Calcular estadísticas
      final equiposCorrectos = equiposRevisados
          .where((e) => e.esEquipoCorrecto)
          .length;
      final equiposFaltantes =
          equiposDepartamento.length -
          equiposRevisados.where((e) => e.esEquipoCorrecto).length;
      final equiposSobrantes = equiposRevisados
          .where((e) => e.esEquipoSobrante)
          .length;

      // Página 1: Portada y resumen
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          header: (context) => _buildHeader(primaryColor),
          footer: (context) => _buildFooter(),
          build: (context) => [
            _buildTitle('Reporte de Revisión de Activos'),
            pw.SizedBox(height: 20),
            _buildInfoRow('Departamento', revision.departamentoNombre),
            _buildInfoRow('Fecha', _formatDate(revision.fechaRevision)),
            _buildInfoRow('Auditor', revision.usuarioAuditorNombre ?? 'N/A'),
            _buildInfoRow('Estado', revision.estado.toUpperCase()),
            pw.SizedBox(height: 30),

            // Resumen con _buildSectionTitle en borde no uniforme
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Total',
                    '${equiposDepartamento.length}',
                    primaryColor,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Correctos',
                    '$equiposCorrectos',
                    successColor,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Faltantes',
                    '$equiposFaltantes',
                    dangerColor,
                  ),
                ),
                pw.SizedBox(width: 10),
                pw.Expanded(
                  child: _buildSummaryCard(
                    'Sobrantes',
                    '$equiposSobrantes',
                    warningColor,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),

            // Porcentaje de completado
            _buildProgressBar(
              'Progreso',
              equiposDepartamento.isNotEmpty
                  ? equiposCorrectos / equiposDepartamento.length
                  : 0,
              primaryColor,
            ),
            pw.SizedBox(height: 30),

            pw.Divider(),
            pw.SizedBox(height: 20),

            // Tabla de equipos correctos
            _buildSectionTitle('EQUIPOS CORRECTOS', successColor),
            pw.SizedBox(height: 10),
            _buildEquiposTable(
              equiposRevisados.where((e) => e.esEquipoCorrecto).toList(),
              showTrabajador: true,
            ),
          ],
        ),
      );

      // Página 2: Equipos faltantes
      if (equiposFaltantes > 0) {
        final equiposFaltantesList = equiposDepartamento
            .where((e) => !equiposRevisados.any((r) => r.equipoId == e.id))
            .toList();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            header: (context) => _buildHeader(primaryColor),
            footer: (context) => _buildFooter(),
            build: (context) => [
              _buildSectionTitle('EQUIPOS FALTANTES', dangerColor),
              pw.SizedBox(height: 10),
              _buildEquiposFaltantesTable(equiposFaltantesList),
              pw.SizedBox(height: 20),
              pw.Paragraph(
                text: 'Total de equipos faltantes: $equiposFaltantes',
                style: _getTextStyle(
                  fontSize: 12,
                  isBold: true,
                  color: dangerColor,
                ),
              ),
            ],
          ),
        );
      }

      // Página 3: Equipos sobrantes
      if (equiposSobrantes > 0) {
        final equiposSobrantesList = equiposRevisados
            .where((e) => e.esEquipoSobrante)
            .toList();

        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            header: (context) => _buildHeader(primaryColor),
            footer: (context) => _buildFooter(),
            build: (context) => [
              _buildSectionTitle('EQUIPOS SOBRANTES', warningColor),
              pw.SizedBox(height: 10),
              _buildEquiposSobrantesTable(equiposSobrantesList),
              pw.SizedBox(height: 20),
              pw.Paragraph(
                text: 'Total de equipos sobrantes: $equiposSobrantes',
                style: _getTextStyle(
                  fontSize: 12,
                  isBold: true,
                  color: warningColor,
                ),
              ),
            ],
          ),
        );
      }

      // Guardar el PDF
      final bytes = await pdf.save();
      final reportsFolder = await StorageService.getReportsFolder();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName =
          'Reporte_${revision.departamentoNombre.replaceAll(' ', '_')}_$timestamp.pdf';
      final file = File('${reportsFolder.path}/$fileName');

      await file.writeAsBytes(bytes);
      debugPrint('✅ PDF generado: ${file.path}');
      return file;
    } catch (e) {
      debugPrint('❌ Error generando PDF: $e');
      return null;
    }
  }

  // ============================================
  // COMPARTIR REPORTE
  // ============================================
  static Future<void> compartirReporte(File file) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: 'Reporte de revisión de activos',
          files: [XFile(file.path)],
        ),
      );
    } catch (e) {
      debugPrint('Error compartiendo: $e');
    }
  }

  // ============================================
  // MÉTODOS PRIVADOS
  // ============================================

  static pw.Widget _buildHeader(PdfColor color) {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: [
        pw.Text(
          'Gestor Patrimonial',
          style: _getTextStyle(fontSize: 16, isBold: true, color: color),
        ),
        pw.Text(
          'Fecha: ${_formatDate(DateTime.now())}',
          style: _getTextStyle(fontSize: 10),
        ),
      ],
    );
  }

  static pw.Widget _buildFooter() {
    return pw.Container(
      alignment: pw.Alignment.center,
      margin: const pw.EdgeInsets.only(top: 20),
      child: pw.Text(
        'Documento generado por Gestor Patrimonial',
        style: _getTextStyle(fontSize: 8, color: PdfColors.grey600),
      ),
    );
  }

  static pw.Widget _buildTitle(String title) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: _getTextStyle(
            fontSize: 24,
            isBold: true,
            color: PdfColor.fromInt(0xFF111827),
          ),
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 3,
          width: 100,
          color: PdfColor.fromInt(0xFF135BEC),
        ),
      ],
    );
  }

  static pw.Widget _buildInfoRow(String label, String value) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        children: [
          pw.Container(
            width: 100,
            child: pw.Text(
              label,
              style: _getTextStyle(isBold: true, color: PdfColors.grey700),
            ),
          ),
          pw.Text(':  '),
          pw.Text(value, style: _getTextStyle()),
        ],
      ),
    );
  }

  // ⚠️ CORREGIDO: SummaryCard sin borderRadius en borde no uniforme
  static pw.Widget _buildSummaryCard(
    String label,
    String value,
    PdfColor color,
  ) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(12),
      decoration: pw.BoxDecoration(
        color: color,
        borderRadius: pw.BorderRadius.circular(8),
        border: pw.Border.all(color: color, width: 8), // Borde uniforme
      ),
      child: pw.Column(
        children: [
          pw.Text(
            value,
            style: _getTextStyle(fontSize: 24, isBold: true, color: color),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            label,
            style: _getTextStyle(
              fontSize: 10,
              isBold: true,
              color: PdfColors.grey700,
            ),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildProgressBar(
    String label,
    double progress,
    PdfColor color,
  ) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(label, style: _getTextStyle(isBold: true)),
            pw.Text(
              '${(progress * 100).toStringAsFixed(1)}%',
              style: _getTextStyle(),
            ),
          ],
        ),
        pw.SizedBox(height: 8),
        pw.Container(
          height: 8,
          decoration: pw.BoxDecoration(
            color: PdfColors.grey300,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Stack(
            children: [
              pw.Container(
                width: progress * 500,
                decoration: pw.BoxDecoration(
                  color: color,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ⚠️ CORREGIDO: SectionTitle con Border correcto
  static pw.Widget _buildSectionTitle(String title, PdfColor color) {
    return pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: pw.Row(
        children: [
          pw.Container(width: 4, height: 20, color: color),
          pw.SizedBox(width: 8),
          pw.Text(
            _cleanTextForFallback(title),
            style: _getTextStyle(fontSize: 16, isBold: true, color: color),
          ),
        ],
      ),
    );
  }

  static pw.Widget _buildEquiposTable(
    List<EquipoRevisado> equipos, {
    bool showTrabajador = false,
  }) {
    if (equipos.isEmpty) {
      return pw.Paragraph(
        text: 'No hay equipos en esta categoría',
        style: _getTextStyle(),
      );
    }

    final headers = ['Código QR', 'Nombre', 'Estado'];
    if (showTrabajador) headers.add('Asignado a');
    headers.add('Ubicación');

    final data = equipos.map((e) {
      final row = [
        e.codigoQR.length > 15
            ? '${e.codigoQR.substring(0, 12)}...'
            : e.codigoQR,
        e.nombreEquipo,
        '✓ Correcto',
      ];
      if (showTrabajador) row.add(e.trabajadorAsignado ?? 'No asignado');
      row.add(e.enAreaCorrecta ? 'Correcta' : 'Fuera de área');
      return row;
    }).toList();

    return pw.TableHelper.fromTextArray(
      headers: headers.map((h) => _cleanTextForFallback(h)).toList(),
      data: data
          .map((row) => row.map((cell) => _cleanTextForFallback(cell)).toList())
          .toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: _getTextStyle(isBold: true),
      cellStyle: _getTextStyle(fontSize: 9),
      headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
      cellHeight: 30,
    );
  }

  static pw.Widget _buildEquiposFaltantesTable(List<Equipo> equipos) {
    if (equipos.isEmpty) {
      return pw.Paragraph(
        text: 'No hay equipos faltantes',
        style: _getTextStyle(),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        'Código QR',
        'Nombre',
        'Tipo',
        'Última ubicación',
      ].map((h) => _cleanTextForFallback(h)).toList(),
      data: equipos
          .map(
            (e) => [
              e.codigoQR.length > 15
                  ? '${e.codigoQR.substring(0, 12)}...'
                  : e.codigoQR,
              _cleanTextForFallback(e.nombre),
              _cleanTextForFallback(e.tipo),
              _cleanTextForFallback(e.departamentoNombre ?? 'No especificado'),
            ],
          )
          .toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: _getTextStyle(isBold: true),
      cellStyle: _getTextStyle(fontSize: 9),
    );
  }

  static pw.Widget _buildEquiposSobrantesTable(List<EquipoRevisado> equipos) {
    if (equipos.isEmpty) {
      return pw.Paragraph(
        text: 'No hay equipos sobrantes',
        style: _getTextStyle(),
      );
    }

    return pw.TableHelper.fromTextArray(
      headers: [
        'Código QR',
        'Nombre',
        'Origen',
        'Observaciones',
      ].map((h) => _cleanTextForFallback(h)).toList(),
      data: equipos
          .map(
            (e) => [
              e.codigoQR.length > 15
                  ? '${e.codigoQR.substring(0, 12)}...'
                  : e.codigoQR,
              _cleanTextForFallback(e.nombreEquipo),
              'Otro departamento',
              _cleanTextForFallback(e.observaciones ?? 'Sin observaciones'),
            ],
          )
          .toList(),
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      headerStyle: _getTextStyle(isBold: true),
      cellStyle: _getTextStyle(fontSize: 9),
    );
  }

  static String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}
