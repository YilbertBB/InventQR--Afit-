import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';
import '../database/database_helper.dart';
import 'storage_service.dart';

class DatabaseBackupService {
  // ============================================
  // 1️⃣ EXPORTAR BASE DE DATOS A LA CARPETA DE LA APP
  // ============================================
  static Future<File?> exportDatabaseToAppFolder() async {
    try {
      // Obtener la carpeta de Database
      final dbFolder = await StorageService.getDatabaseFolder();

      // Obtener la ruta actual de la BD
      final dbPath = await _getDatabasePath();
      final originalFile = File(dbPath);

      if (!await originalFile.exists()) {
        throw Exception('Base de datos no encontrada');
      }

      // Crear nombre con timestamp
      final timestamp = DateTime.now()
          .toIso8601String()
          .replaceAll(':', '-')
          .replaceAll('.', '-');
      final backupName = 'backup_$timestamp.db';
      final backupFile = File('${dbFolder.path}/$backupName');

      // Copiar el archivo
      await originalFile.copy(backupFile.path);

      debugPrint('✅ BD exportada a: ${backupFile.path}');
      return backupFile;
    } catch (e) {
      debugPrint('❌ Error exportando BD: $e');
      return null;
    }
  }

  // ============================================
  // 2️⃣ EXPORTAR Y COMPARTIR BASE DE DATOS
  // ============================================
  static Future<void> exportAndShareDatabase(BuildContext context) async {
    try {
      // Verificar permisos
      final hasPermission =
          await StorageService.solicitarPermisosAlmacenamiento();
      if (!hasPermission) {
        if (!context.mounted) return;
        _showSnackBar(
          context,
          '❌ Permisos de almacenamiento denegados',
          Colors.red,
        );
        return;
      }

      // Asegurar que existen las carpetas
      await StorageService.inicializarCarpetas();

      // Exportar BD
      final backupFile = await exportDatabaseToAppFolder();

      if (backupFile == null) {
        if (!context.mounted) return;
        _showSnackBar(context, '❌ Error al crear backup', Colors.red);
        return;
      }

      // Compartir el archivo
      await SharePlus.instance.share(
        ShareParams(
          text: '📦 Backup de base de datos - ${DateTime.now().toLocal()}',
          files: [XFile(backupFile.path)],
        ),
      );

      if (!context.mounted) return;
      _showSnackBar(context, '✅ Backup creado y compartido', Colors.green);
    } catch (e) {
      debugPrint('❌ Error: $e');
      _showSnackBar(context, '❌ Error: $e', Colors.red);
    }
  }

  // ============================================
  // 3️⃣ IMPORTAR BASE DE DATOS DESDE UN ARCHIVO
  // ============================================
  // Versión alternativa SIN closeDatabase
  static Future<bool> importDatabaseFromFile(
    String filePath,
    BuildContext context,
  ) async {
    try {
      // Verificar que el archivo existe
      final sourceFile = File(filePath);
      if (!await sourceFile.exists()) {
        if (context.mounted) {
          _showSnackBar(context, '❌ Archivo no encontrado', Colors.red);
        }
        return false;
      }

      // Verificar que es un archivo .db
      if (!filePath.endsWith('.db')) {
        if (context.mounted) {
          _showSnackBar(context, '❌ El archivo debe ser .db', Colors.red);
        }
        return false;
      }

      // Crear backup automático antes de restaurar
      await exportDatabaseToAppFolder();

      // Obtener la ruta actual de la BD
      final dbPath = await _getDatabasePath();
      final destFile = File(dbPath);

      // Cerrar la base de datos actual (si está abierta)
      try {
        final db = await DatabaseHelper.instance.database;
        await db.close();
      } catch (e) {
        // Ignorar error si no se puede cerrar
      }

      // Copiar el archivo importado
      await sourceFile.copy(destFile.path);
      if (context.mounted) {
        _showSnackBar(
          context,
          '✅ Base de datos restaurada correctamente',
          Colors.green,
        );
        _showSnackBar(
          context,
          '⚠️ Reinicia la aplicación para aplicar los cambios',
          Colors.orange,
        );
      }

      return true;
    } catch (e) {
      debugPrint('❌ Error importando BD: $e');
      if (context.mounted) {
        _showSnackBar(context, '❌ Error: $e', Colors.red);
      }

      return false;
    }
  }

  // ============================================
  // 4️⃣ LISTAR TODOS LOS BACKUPS DISPONIBLES
  // ============================================
  static Future<List<File>> listAvailableBackups() async {
    try {
      final dbFolder = await StorageService.getDatabaseFolder();

      final files = dbFolder.listSync().where((entity) {
        return entity is File && entity.path.endsWith('.db');
      }).toList();

      // Ordenar por fecha de modificación (más reciente primero)
      files.sort((a, b) {
        return (b as File).lastModifiedSync().compareTo(
          (a as File).lastModifiedSync(),
        );
      });

      return files.cast<File>();
    } catch (e) {
      debugPrint('❌ Error listando backups: $e');
      return [];
    }
  }

  // ============================================
  // 5️⃣ ELIMINAR BACKUP ANTIGUOS (OPCIONAL)
  // ============================================
  static Future<void> cleanOldBackups({int keepLast = 10}) async {
    try {
      final backups = await listAvailableBackups();

      if (backups.length > keepLast) {
        for (int i = keepLast; i < backups.length; i++) {
          await backups[i].delete();
          debugPrint('🗑️ Backup eliminado: ${backups[i].path}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error limpiando backups: $e');
    }
  }

  // ============================================
  // 6️⃣ OBTENER INFORMACIÓN DE LOS BACKUPS
  // ============================================
  static Future<List<Map<String, dynamic>>> getBackupsInfo() async {
    final backups = await listAvailableBackups();

    return backups.map((file) {
      final stat = file.statSync();
      final fileName = path.basename(file.path);

      // Extraer fecha del nombre del archivo (formato: backup_2024-01-01T10-30-00.db)
      DateTime? backupDate;
      try {
        final dateStr = fileName
            .replaceAll('backup_', '')
            .replaceAll('.db', '');
        backupDate = DateTime.parse(
          dateStr.replaceAll('-', ':').replaceAll('T', ' '),
        );
      } catch (e) {
        backupDate = file.lastModifiedSync();
      }

      return {
        'file': file,
        'name': fileName,
        'path': file.path,
        'size': _formatFileSize(stat.size),
        'date': backupDate,
        'modified': file.lastModifiedSync(),
      };
    }).toList();
  }

  // ============================================
  // 7️⃣ MÉTODOS AUXILIARES
  // ============================================
  static String _formatFileSize(int bytes) {
    if (bytes <= 0) return '0 B';
    const suffixes = ['B', 'KB', 'MB', 'GB'];
    var i = (log(bytes) / log(1024)).floor();
    return '${(bytes / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }

  static void _showSnackBar(BuildContext context, String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // ============================================
  // 8️⃣ MÉTODO PRIVADO PARA OBTENER RUTA DE BD
  // ============================================
  static Future<String> _getDatabasePath() async {
    final db = await DatabaseHelper.instance.database;
    return db.path;
  }
}
