import 'dart:io';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../models/equipo.dart';
import 'storage_service.dart';
import '../core/app_theme.dart';

class ExcelExportService {
  // ============================================
  // 1️⃣ EXPORTAR INVENTARIO A EXCEL
  // ============================================
  static Future<File?> exportarInventario({
    required List<Equipo> equipos,
    required BuildContext context,
    bool guardarEnCarpeta = true,
  }) async {
    try {
      // Crear archivo Excel
      var excel = Excel.createExcel();

      // Configurar hoja
      String sheetName = 'Inventario';
      Sheet sheetObject = excel[sheetName];

      // Estilos
      CellStyle headerStyle = CellStyle(
        backgroundColorHex: ExcelColor.fromHexString("#135BEC"),
        fontFamily: getFontFamily(FontFamily.Calibri),
        fontSize: 12,
        bold: true,
        textWrapping: TextWrapping.WrapText,
        verticalAlign: VerticalAlign.Center,
        horizontalAlign: HorizontalAlign.Center,
      );

      // CellStyle dateStyle = CellStyle(
      //   fontFamily: getFontFamily(FontFamily.Calibri),
      //   fontSize: 11,
      // );

      // ============================================
      // ENCABEZADOS
      // ============================================
      List<String> headers = [
        'ID',
        'Código QR',
        'Nombre',
        'Tipo',
        'Marca',
        'Modelo',
        'N° Serie',
        'Estado',
        'Departamento',
        'Asignado a',
        'Proyecto',
        'Fecha Adquisición',
        'Fecha Asignación',
        'Costo (S/)',
        'Fecha Garantía',
        'Observaciones',
      ];

      // Aplicar encabezados
      for (int i = 0; i < headers.length; i++) {
        var cell = sheetObject.cell(
          CellIndex.indexByColumnRow(rowIndex: 0, columnIndex: i),
        );
        cell.value = TextCellValue(headers[i]);
        cell.cellStyle = headerStyle;
      }

      // Ajustar ancho de columnas
      for (int i = 0; i < headers.length; i++) {
        sheetObject.setColumnWidth(i, 18.0);
      }

      // ============================================
      // DATOS
      // ============================================
      for (int row = 0; row < equipos.length; row++) {
        final e = equipos[row];

        // Calcular fecha de garantía
        String fechaGarantia = '';
        if (e.fechaGarantia != null) {
          fechaGarantia =
              '${e.fechaGarantia!.day}/${e.fechaGarantia!.month}/${e.fechaGarantia!.year}';
        }

        List<dynamic> rowData = [
          e.id,
          e.codigoQR,
          e.nombre,
          e.tipo,
          e.marca,
          e.modelo,
          e.numeroSerie,
          e.estado.toUpperCase(),
          e.departamentoNombre ?? 'Sin departamento',
          e.trabajadorNombre ?? 'No asignado',
          e.proyectoNombre ?? 'Sin proyecto',
          '${e.fechaAdquisicion.day}/${e.fechaAdquisicion.month}/${e.fechaAdquisicion.year}',
          e.fechaAsignacion != null
              ? '${e.fechaAsignacion!.day}/${e.fechaAsignacion!.month}/${e.fechaAsignacion!.year}'
              : 'No asignado',
          e.costo != null ? 'S/ ${e.costo!.toStringAsFixed(2)}' : '-',
          fechaGarantia,
          e.observaciones ?? '',
        ];

        for (int col = 0; col < rowData.length; col++) {
          var cell = sheetObject.cell(
            CellIndex.indexByColumnRow(rowIndex: row + 1, columnIndex: col),
          );

          if (rowData[col] is String) {
            cell.value = TextCellValue(rowData[col] as String);
          } else {
            cell.value = TextCellValue(rowData[col].toString());
          }

          // Aplicar color según estado
          if (col == 7) {
            // Columna de estado
            switch (e.estado.toLowerCase()) {
              case 'activo':
                cell.cellStyle = CellStyle(
                  fontFamily: getFontFamily(FontFamily.Calibri),
                  backgroundColorHex: ExcelColor.fromHexString("#10B981"),
                  textWrapping: TextWrapping.WrapText,
                );
                break;
              case 'mantenimiento':
                cell.cellStyle = CellStyle(
                  fontFamily: getFontFamily(FontFamily.Calibri),
                  backgroundColorHex: ExcelColor.fromHexString("#F59E0B"),
                  textWrapping: TextWrapping.WrapText,
                );
                break;
              case 'baja':
                cell.cellStyle = CellStyle(
                  fontFamily: getFontFamily(FontFamily.Calibri),
                  backgroundColorHex: ExcelColor.fromHexString("#EF4444"),
                  textWrapping: TextWrapping.WrapText,
                );
                break;
            }
          }
        }
      }

      // ============================================
      // GUARDAR ARCHIVO
      // ============================================

      // Generar nombre de archivo
      // final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fecha = DateTime.now();
      final fechaStr = '${fecha.day}-${fecha.month}-${fecha.year}';
      final fileName = 'Inventario_$fechaStr.xlsx';

      File? file;

      if (guardarEnCarpeta) {
        // Guardar en carpeta de la app
        final exportFolder = await StorageService.getExportsFolder();
        file = File('${exportFolder.path}/$fileName');
      } else {
        // Dejar que el usuario elija dónde guardar
        String? outputFile = await FilePicker.platform.saveFile(
          dialogTitle: 'Guardar inventario como Excel',
          fileName: fileName,
          allowedExtensions: ['xlsx'],
          type: FileType.custom,
        );

        if (outputFile != null) {
          file = File(outputFile);
        }
      }

      if (file != null) {
        // Guardar archivo
        var fileBytes = excel.save();
        if (fileBytes != null) {
          await file.writeAsBytes(fileBytes);
          debugPrint('✅ Excel guardado en: ${file.path}');
          return file;
        }
      }

      return null;
    } catch (e) {
      debugPrint('❌ Error exportando Excel: $e');
      return null;
    }
  }

  // ============================================
  // 2️⃣ EXPORTAR Y COMPARTIR
  // ============================================
  static Future<void> exportarYCompartir({
    required List<Equipo> equipos,
    required BuildContext context,
  }) async {
    try {
      // Verificar permisos
      final hasPermission =
          await StorageService.solicitarPermisosAlmacenamiento();
      if (!hasPermission) {
        if (context.mounted) {
          _showSnackBar(
            context,
            '❌ Permisos de almacenamiento denegados',
            Colors.red,
          );
        }

        return;
      }

      // Mostrar indicador de carga
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Exportar
      final file = await exportarInventario(
        equipos: equipos,
        context: context,
        guardarEnCarpeta: true,
      );

      // Cerrar indicador
      if (context.mounted) {
        Navigator.pop(context);
      }
      if (!context.mounted) return;
      if (file != null) {
        _showExportOptions(context, file);
      } else {
        _showSnackBar(context, '❌ Error al generar el archivo', Colors.red);
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        _showSnackBar(context, '❌ Error: $e', Colors.red);
      }
    }
  }

  // ============================================
  // 3️⃣ MOSTRAR OPCIONES DE EXPORTACIÓN
  // ============================================
  static void _showExportOptions(BuildContext context, File file) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      builder: (context) {
        return SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
            ),
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
                  'Exportación Exitosa',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111318),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                file.path.split('/').last,
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
                title: const Text('Compartir archivo'),
                subtitle: const Text('Enviar por WhatsApp, Email, etc.'),
                onTap: () async {
                  Navigator.pop(context);
                  await SharePlus.instance.share(
                    ShareParams(
                      text: '📊 Inventario de activos',
                      files: [XFile(file.path)],
                    ),
                  );
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
                title: const Text('Abrir carpeta'),
                subtitle: const Text('Ver archivo en el gestor de archivos'),
                onTap: () {
                  Navigator.pop(context);
                  _showFileLocation(context, file);
                },
              ),

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.email, color: Colors.orange),
                ),
                title: const Text('Enviar por correo'),
                subtitle: const Text('Abrir cliente de correo'),
                onTap: () async {
                  Navigator.pop(context);
                  await SharePlus.instance.share(
                    ShareParams(
                      text: '📊 Inventario de activos',
                      files: [XFile(file.path)],
                    ),
                  );
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
          ),
        );
      },
    );
  }

  // ============================================
  // 4️⃣ MOSTRAR UBICACIÓN DEL ARCHIVO
  // ============================================
  static void _showFileLocation(BuildContext context, File file) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅ Archivo guardado en:'),
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
  // 5️⃣ SNACKBAR HELPER
  // ============================================
  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}
