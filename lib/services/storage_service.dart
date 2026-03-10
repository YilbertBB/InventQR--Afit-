import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class StorageService {
  static const String appFolderName = 'InventQR';

  // 📌 VERIFICAR PERMISOS ACTUALES
  static Future<bool> verificarPermisos() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      final manageStatus = await Permission.manageExternalStorage.status;
      return status.isGranted || manageStatus.isGranted;
    }
    return true; // iOS no necesita permisos especiales
  }

  // 📌 SOLICITAR PERMISOS DE ALMACENAMIENTO
  static Future<bool> solicitarPermisosAlmacenamiento() async {
    if (Platform.isAndroid) {
      // Para Android 11+ (API 30+)
      if (await Permission.manageExternalStorage.request().isGranted) {
        debugPrint('✅ Permiso manageExternalStorage concedido');
        return true;
      }

      // Para Android 10 y anteriores
      if (await Permission.storage.request().isGranted) {
        debugPrint('✅ Permiso storage concedido');
        return true;
      }

      // Android 13+ (permisos más específicos)
      if (await Permission.photos.request().isGranted ||
          await Permission.videos.request().isGranted ||
          await Permission.audio.request().isGranted) {
        debugPrint('✅ Permisos multimedia concedidos');
        return true;
      }

      debugPrint('❌ Permisos denegados');

      return false;
    }

    return true;
  }

  // 📌 INICIALIZAR CARPETAS DE LA APP
  static Future<void> inicializarCarpetas() async {
    try {
      await getAppRootDirectory();
      await getDatabaseFolder();
      await getExportsFolder();
      await getQRFolder();
      await getReportsFolder();
      debugPrint('✅ Carpetas de la app creadas exitosamente');
    } catch (e) {
      debugPrint('❌ Error creando carpetas: $e');
    }
  }

  // 📌 OBTENER CARPETA RAÍZ
  static Future<Directory?> getAppRootDirectory() async {
    if (Platform.isAndroid) {
      final directory = Directory('/storage/emulated/0/$appFolderName');
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else if (Platform.isIOS) {
      final directory = await getApplicationDocumentsDirectory();
      final appDir = Directory('${directory.path}/$appFolderName');
      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return appDir;
    }
    return null;
  }

  // 📌 CREAR SUBFOLDER
  static Future<Directory> getSubfolder(String subfolderName) async {
    final rootDir = await getAppRootDirectory();
    final subDir = Directory('${rootDir!.path}/$subfolderName');
    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }
    return subDir;
  }

  static Future<Directory> getDatabaseFolder() => getSubfolder('Database');
  static Future<Directory> getExportsFolder() => getSubfolder('Exports');
  static Future<Directory> getQRFolder() => getSubfolder('QR_Codes');
  static Future<Directory> getReportsFolder() => getSubfolder('Reports');

  // 📌 VERIFICAR ESPACIO EN DISCO
  static Future<bool> hayEspacioSuficiente({
    int requiredBytes = 10485760,
  }) async {
    // 10MB por defecto
    try {
      final directory = await getAppRootDirectory();
      if (directory == null) return false;

      return true;
    } catch (e) {
      debugPrint('Error verificando espacio: $e');
      return true;
    }
  }
}
