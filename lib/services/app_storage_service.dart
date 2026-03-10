import 'dart:io';
import 'package:path_provider/path_provider.dart';

class AppStorageService {
  static const String appFolderName = 'InventQR';
  static Future<Directory?> getAppRootDirectory() async {
    if (Platform.isAndroid) {
      // Intentar en Almacenamiento Externo (visible para el usuario)
      final directory = Directory('/storage/emulated/0/$appFolderName');

      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      return directory;
    } else if (Platform.isIOS) {
      // En iOS, usar Documents directory
      final directory = await getApplicationDocumentsDirectory();
      final appDir = Directory('${directory.path}/$appFolderName');

      if (!await appDir.exists()) {
        await appDir.create(recursive: true);
      }
      return appDir;
    }
    return null;
  }

  // Crear subcarpetas específicas
  static Future<Directory> getSubfolder(String subfolderName) async {
    final rootDir = await getAppRootDirectory();
    final subDir = Directory('${rootDir!.path}/$subfolderName');

    if (!await subDir.exists()) {
      await subDir.create(recursive: true);
    }
    return subDir;
  }

  // Obtener carpeta para base de datos
  static Future<Directory> getDatabaseFolder() async {
    return await getSubfolder('Database');
  }

  // Obtener carpeta para exports Excel
  static Future<Directory> getExportsFolder() async {
    return await getSubfolder('Exports');
  }

  // Obtener carpeta para códigos QR
  static Future<Directory> getQRFolder() async {
    return await getSubfolder('QR_Codes');
  }

  // Obtener carpeta para reportes
  static Future<Directory> getReportsFolder() async {
    return await getSubfolder('Reports');
  }
}
