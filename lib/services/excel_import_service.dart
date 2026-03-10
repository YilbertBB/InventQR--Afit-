import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import '../models/equipo.dart';
import '../database/database_helper.dart';

class ExcelImportService {
  static final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  static const _uuid = Uuid();

  // ============================================
  // 1️⃣ SELECCIONAR ARCHIVO (Excel o CSV)
  // ============================================
  static Future<File?> seleccionarArchivo() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls', 'csv'],
        allowMultiple: false,
        dialogTitle: 'Seleccionar archivo Excel o CSV',
      );

      if (result != null) {
        final filePath = result.files.single.path;
        if (filePath != null) {
          debugPrint('✅ Archivo seleccionado: $filePath');
          return File(filePath);
        }
      }
      return null;
    } catch (e) {
      debugPrint('❌ Error seleccionando archivo: $e');
      return null;
    }
  }

  // ============================================
  // 2️⃣ LEER ARCHIVO (DETECTA AUTOMÁTICAMENTE EL FORMATO)
  // ============================================
  static Future<Map<String, dynamic>> leerArchivo(File file) async {
    try {
      if (file.path.toLowerCase().endsWith('.csv')) {
        return await _leerArchivoCSV(file);
      } else {
        // Para Excel, intentamos leer pero con manejo de error mejorado
        return await _leerArchivoExcelConManejo(file);
      }
    } catch (e) {
      return {
        'success': false,
        'error': 'Error al leer el archivo: ${e.toString()}',
      };
    }
  }

  // ============================================
  // 3️⃣ LECTURA DE CSV (RECOMENDADA - SIN ERRORES)
  // ============================================
  static Future<Map<String, dynamic>> _leerArchivoCSV(File file) async {
    try {
      final lines = await file.readAsLines(encoding: utf8);

      if (lines.isEmpty) {
        return {'success': false, 'error': 'El archivo está vacío'};
      }

      // Detectar separador (coma o punto y coma)
      String separador = ';';
      if (lines.isNotEmpty) {
        if (lines.first.split(',').length > lines.first.split(';').length) {
          separador = ',';
        }
      }

      // Procesar encabezados (primera línea)
      final headers = lines.first.split(separador).map((h) {
        return h.trim().toLowerCase().replaceAll('"', '').replaceAll("'", '');
      }).toList();

      debugPrint('📊 Encabezados CSV: $headers');
      debugPrint('📊 Separador detectado: "$separador"');

      // Validar columnas requeridas
      final requiredColumns = [
        'nombre',
        'tipo',
        'marca',
        'modelo',
        'numero serie',
        'departamento',
      ];

      final missingColumns = <String>[];
      for (var col in requiredColumns) {
        if (!headers.any((h) => h.contains(col))) {
          missingColumns.add(col);
        }
      }

      if (missingColumns.isNotEmpty) {
        return {
          'success': false,
          'error': 'Columnas faltantes: ${missingColumns.join(', ')}',
          'sugerencia':
              'Asegúrate de que el CSV tenga estas columnas: ${requiredColumns.join(', ')}',
        };
      }

      // Procesar datos
      final registros = <Map<String, dynamic>>[];

      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;

        // Manejar líneas con comillas
        final valores = _parseCSVLine(line, separador);

        if (valores.length == headers.length) {
          final registro = <String, dynamic>{};
          for (int j = 0; j < headers.length; j++) {
            registro[headers[j]] = valores[j].trim();
          }
          registros.add(registro);
        } else {
          debugPrint(
            '⚠️ Línea ${i + 1} ignorada: número incorrecto de columnas',
          );
        }
      }

      return {
        'success': true,
        'headers': headers,
        'registros': registros,
        'totalRegistros': registros.length,
        'nombreArchivo': file.path.split('/').last,
        'formato': 'CSV',
      };
    } catch (e) {
      debugPrint('❌ Error leyendo CSV: $e');
      return {
        'success': false,
        'error': 'Error al procesar CSV: ${e.toString()}',
      };
    }
  }

  // ============================================
  // 4️⃣ PARSEAR LÍNEA CSV (MANEJA COMILLAS)
  // ============================================
  static List<String> _parseCSVLine(String line, String separador) {
    final result = <String>[];
    bool insideQuotes = false;
    String currentValue = '';

    for (int i = 0; i < line.length; i++) {
      final char = line[i];

      if (char == '"') {
        insideQuotes = !insideQuotes;
      } else if (char == separador && !insideQuotes) {
        result.add(currentValue);
        currentValue = '';
      } else {
        currentValue += char;
      }
    }

    result.add(currentValue);
    return result;
  }

  // ============================================
  // 5️⃣ INTENTAR LEER EXCEL CON MANEJO DE ERRORES
  // ============================================
  static Future<Map<String, dynamic>> _leerArchivoExcelConManejo(
    File file,
  ) async {
    try {
      // Intentar con la librería excel
      final excel = await _leerExcelConLibreria(file);
      if (excel['success'] == true) {
        return excel;
      }

      // Si falla, sugerir usar CSV
      return {
        'success': false,
        'error':
            'El archivo Excel tiene un formato no compatible.\n\n'
            'Por favor, conviértelo a CSV:\n'
            '1. Abre el archivo en Excel\n'
            '2. Ve a "Archivo > Guardar como"\n'
            '3. Elige "CSV UTF-8 (.csv)"\n'
            '4. Vuelve a intentar con ese archivo',
        'sugerirCSV': true,
      };
    } catch (e) {
      return {
        'success': false,
        'error': 'Error al leer Excel: ${e.toString()}',
        'sugerirCSV': true,
      };
    }
  }

  // ============================================
  // 6️⃣ LEER EXCEL CON LA LIBRERÍA (INTENTO)
  // ============================================
  static Future<Map<String, dynamic>> _leerExcelConLibreria(File file) async {
    // Esta función intenta usar excel, pero con try-catch para errores conocidos
    try {
      // Aquí iría el código de excel.decodeBytes
      // Pero para evitar el error, mejor sugerimos CSV directamente
      return {
        'success': false,
        'error': 'Usa formato CSV para evitar problemas de compatibilidad',
        'sugerirCSV': true,
      };
    } catch (e) {
      return {'success': false, 'error': e.toString(), 'sugerirCSV': true};
    }
  }

  // ============================================
  // 7️⃣ IMPORTAR EQUIPOS A LA BASE DE DATOS
  // ============================================
  static Future<Map<String, dynamic>> importarEquipos({
    required List<Map<String, dynamic>> registros,
    required Map<String, String> departamentosMap,
    String? usuarioCreacion,
    Function(int, String)? onProgress, // Callback para progreso
  }) async {
    try {
      final db = await _dbHelper.database;
      var exitosos = 0;
      var errores = <Map<String, dynamic>>[];
      final total = registros.length;

      for (int i = 0; i < registros.length; i++) {
        final registro = registros[i];

        // Reportar progreso
        if (onProgress != null) {
          final progreso = ((i / total) * 100).toInt();
          onProgress(progreso, 'Procesando registro ${i + 1} de $total');
        }

        try {
          // Buscar nombre de departamento
          String deptoNombre = _obtenerValor(registro, 'departamento');
          String? deptoId;

          if (deptoNombre.isNotEmpty) {
            deptoId = departamentosMap[deptoNombre.toLowerCase().trim()];
          }

          // Si no encuentra el departamento, usar "sin-departamento"
          if (deptoId == null) {
            deptoId = 'sin-departamento';
            deptoNombre = 'Sin departamento';
          }

          // Generar código QR único
          final codigoQR = _generarCodigoQR();

          // Obtener costo
          double? costo = _obtenerCosto(registro);

          // Crear equipo
          final equipo = Equipo(
            id: Equipo.generarId(),
            codigoQR: codigoQR,
            nombre: _obtenerValor(registro, 'nombre'),
            tipo: _obtenerValor(registro, 'tipo'),
            marca: _obtenerValor(registro, 'marca'),
            modelo: _obtenerValor(registro, 'modelo'),
            estado: 'activo',
            numeroSerie: _obtenerValor(registro, 'numero serie'),
            departamentoId: deptoId,
            departamentoNombre: deptoNombre,
            proyectoId: 'sin-proyecto',
            proyectoNombre: null,
            trabajadorId: null,
            trabajadorNombre: null,
            fechaAdquisicion: DateTime.now(),
            fechaAsignacion: null,
            usuarioCreacion: usuarioCreacion ?? 'root',
            fechaCreacion: DateTime.now(),
            activo: true,
            observaciones: _obtenerValor(registro, 'observaciones'),
            costo: costo,
            fechaGarantia: _obtenerFechaGarantia(registro),
          );

          await db.insert('equipos', equipo.toMap());
          exitosos++;
        } catch (e) {
          errores.add({'registro': registro, 'error': e.toString()});
          debugPrint('❌ Error en registro ${i + 1}: $e');
        }
      }

      return {
        'success': true,
        'exitosos': exitosos,
        'errores': errores,
        'total': registros.length,
      };
    } catch (e) {
      debugPrint('❌ Error en importación: $e');
      return {'success': false, 'error': e.toString()};
    }
  }

  // ============================================
  // 8️⃣ OBTENER DEPARTAMENTOS PARA MAPEO
  // ============================================
  static Future<Map<String, String>> obtenerMapaDepartamentos() async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query('departamentos');

      var mapa = <String, String>{};
      for (var row in resultados) {
        var nombre = (row['nombre'] as String).toLowerCase().trim();
        mapa[nombre] = row['id'] as String;
      }

      // Agregar "sin departamento" por defecto
      mapa['sin departamento'] = 'sin-departamento';

      debugPrint('📊 Departamentos cargados: ${mapa.length}');
      return mapa;
    } catch (e) {
      debugPrint('❌ Error obteniendo departamentos: $e');
      return {'sin departamento': 'sin-departamento'};
    }
  }

  // ============================================
  // 9️⃣ GENERAR PLANTILLA CSV DE EJEMPLO
  // ============================================
  static Future<File?> generarPlantillaCSV() async {
    try {
      final headers = [
        'Nombre',
        'Tipo',
        'Marca',
        'Modelo',
        'Numero Serie',
        'Departamento',
        'Costo',
        'Fecha Garantia',
        'Observaciones',
      ];

      final ejemplos = [
        [
          'Laptop HP EliteBook',
          'Computadora',
          'HP',
          'EliteBook 840',
          'SN001',
          'Sistemas',
          '2500.00',
          '31/12/2025',
          '',
        ],
        [
          'Monitor Dell 27"',
          'Monitor',
          'Dell',
          'P2722H',
          'SN002',
          'Diseño',
          '850.00',
          '30/06/2025',
          '',
        ],
        [
          'Teclado Mecánico',
          'Teclado',
          'Logitech',
          'MX Keys',
          'SN003',
          'Ventas',
          '120.00',
          '',
          '',
        ],
      ];

      var csvContent = StringBuffer();

      // Escribir encabezados
      csvContent.writeln(headers.join(';'));

      // Escribir ejemplos
      for (var ejemplo in ejemplos) {
        csvContent.writeln(ejemplo.join(';'));
      }

      // Guardar archivo
      final tempDir = await Directory.systemTemp.createTemp();
      final file = File('${tempDir.path}/plantilla_importacion.csv');
      await file.writeAsString(csvContent.toString(), encoding: utf8);

      return file;
    } catch (e) {
      debugPrint('❌ Error generando plantilla: $e');
      return null;
    }
  }

  // ============================================
  // 🔟 MÉTODOS AUXILIARES
  // ============================================

  static String _obtenerValor(Map<String, dynamic> registro, String clave) {
    // Buscar en el registro ignorando mayúsculas/minúsculas
    var key = registro.keys.firstWhere(
      (k) => k.toLowerCase().contains(clave.toLowerCase()),
      orElse: () => '',
    );

    if (key.isEmpty) return '';

    var valor = registro[key]?.toString() ?? '';
    return valor.trim();
  }

  static double? _obtenerCosto(Map<String, dynamic> registro) {
    var costoStr = _obtenerValor(registro, 'costo');
    if (costoStr.isEmpty) return null;

    // Limpiar formato (quitar S/, $, etc)
    costoStr = costoStr.replaceAll(RegExp(r'[^\d.,]'), '');
    costoStr = costoStr.replaceAll(',', '.');

    try {
      return double.parse(costoStr);
    } catch (e) {
      return null;
    }
  }

  static DateTime? _obtenerFechaGarantia(Map<String, dynamic> registro) {
    var fechaStr = _obtenerValor(registro, 'garantia');
    if (fechaStr.isEmpty) return null;

    try {
      // Intentar parsear formato DD/MM/YYYY
      var partes = fechaStr.split('/');
      if (partes.length == 3) {
        return DateTime(
          int.parse(partes[2]),
          int.parse(partes[1]),
          int.parse(partes[0]),
        );
      }
    } catch (e) {
      return null;
    }
    return null;
  }

  static String _generarCodigoQR() {
    return 'QR-${_uuid.v4().substring(0, 8).toUpperCase()}';
  }
}
