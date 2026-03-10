import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/database_backup_service.dart';
import '../../services/storage_service.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';

class BackupManagementScreen extends StatefulWidget {
  const BackupManagementScreen({super.key});

  @override
  State<BackupManagementScreen> createState() => _BackupManagementScreenState();
}

class _BackupManagementScreenState extends State<BackupManagementScreen> {
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = true;
  String? _ultimoBackupInfo;

  @override
  void initState() {
    super.initState();
    _cargarBackups();
  }

  Future<void> _cargarBackups() async {
    setState(() => _isLoading = true);

    // Verificar permisos
    await StorageService.solicitarPermisosAlmacenamiento();
    await StorageService.inicializarCarpetas();

    final backups = await DatabaseBackupService.getBackupsInfo();

    setState(() {
      _backups = backups;
      _isLoading = false;

      if (backups.isNotEmpty) {
        final ultimo = backups.first;
        final fecha = ultimo['date'] as DateTime;
        _ultimoBackupInfo =
            '${fecha.day}/${fecha.month}/${fecha.year}, ${fecha.hour.toString().padLeft(2, '0')}:${fecha.minute.toString().padLeft(2, '0')}';
      } else {
        _ultimoBackupInfo = null;
      }
    });
  }

  Future<void> _crearBackup(BuildContext context) async {
    // Mostrar diálogo de carga
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final file = await DatabaseBackupService.exportDatabaseToAppFolder();

      if (context.mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga

        if (file != null) {
          await _cargarBackups(); // Recargar lista

          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '✅ Backup creado: ${file.path.split('/').last}',
                      ),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        } else {
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('❌ Error al crear backup'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _importarBackup(BuildContext context) async {
    try {
      // Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
        dialogTitle: 'Seleccionar archivo de backup',
      );

      if (result != null && context.mounted) {
        final filePath = result.files.single.path!;

        // Confirmar restauración
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Restaurar Backup'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Esta acción reemplazará la base de datos actual.'),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Archivo: ${result.files.single.name}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancelar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                ),
                child: const Text('Restaurar'),
              ),
            ],
          ),
        );

        if (confirm == true && context.mounted) {
          // Mostrar carga
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) =>
                const Center(child: CircularProgressIndicator()),
          );

          final success = await DatabaseBackupService.importDatabaseFromFile(
            filePath,
            context,
          );

          if (context.mounted) {
            Navigator.pop(context); // Cerrar diálogo de carga

            if (success) {
              await _cargarBackups();
              if (!context.mounted) return;
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (context) => AlertDialog(
                  title: const Text('✅ Restauración Exitosa'),
                  content: const Text(
                    'La base de datos ha sido restaurada correctamente.\n\nLa aplicación se reiniciará para aplicar los cambios.',
                  ),
                  actions: [
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        AppRoutes.goToDashboard(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primaryColor,
                      ),
                      child: const Text('Aceptar'),
                    ),
                  ],
                ),
              );
            }
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _restaurarBackup(
    BuildContext context,
    Map<String, dynamic> backup,
  ) async {
    final file = backup['file'] as File;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('⚠️ Restaurar Backup'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Restaurar backup del ${backup['date']}?'),
            const SizedBox(height: 8),
            Text(
              'Tamaño: ${backup['size']}',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (context.mounted && confirm == true) {
      // Mostrar carga
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      final success = await DatabaseBackupService.importDatabaseFromFile(
        file.path,
        context,
      );

      if (context.mounted) {
        Navigator.pop(context); // Cerrar diálogo de carga

        if (success) {
          await _cargarBackups();
          if (!context.mounted) return;
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => AlertDialog(
              title: const Text('✅ Restauración Exitosa'),
              content: const Text(
                'La base de datos ha sido restaurada correctamente.\n\nLa aplicación se reiniciará para aplicar los cambios.',
              ),
              actions: [
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    AppRoutes.goToDashboard(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                  ),
                  child: const Text('Aceptar'),
                ),
              ],
            ),
          );
        }
      }
    }
  }

  Future<void> _exportarBackup(Map<String, dynamic> backup) async {
    final file = backup['file'] as File;

    await SharePlus.instance.share(
      ShareParams(
        text: '📦 Backup de base de datos - ${backup['date']}',
        files: [XFile(file.path)],
      ),
    );
  }

  Future<void> _eliminarBackup(Map<String, dynamic> backup) async {
    final file = backup['file'] as File;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🗑️ Eliminar Backup'),
        content: Text('¿Eliminar backup del ${backup['date']}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await file.delete();
        await _cargarBackups();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Backup eliminado'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ Error: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Datos'),
        centerTitle: false,
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        surfaceTintColor: Colors.transparent,
      ),
      body: RefreshIndicator(
        onRefresh: _cargarBackups,
        color: AppTheme.primaryColor,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Crear Backup e Importar datos
            Row(
              children: [
                Expanded(
                  child: ElevatedIconButton(
                    icon: Icons.save_alt,
                    label: 'CREAR BACKUP',
                    onPressed: () => _crearBackup(context),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: OutlinedIconButton(
                    icon: Icons.upload,
                    label: 'IMPORTAR DATOS',
                    onPressed: () => _importarBackup(context),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Último respaldo
            if (_ultimoBackupInfo != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: Colors.green.shade700,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'ÚLTIMO RESPALDO:',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Text(
                      _ultimoBackupInfo!,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                      ),
                    ),
                  ],
                ),
              )
            else
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade300),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Colors.grey.shade600,
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'No hay backups disponibles',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 32),

            // Historial de backups
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'HISTORIAL DE BACKUPS',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_backups.length} ARCHIVOS',
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Lista de backups
              if (_backups.isEmpty)
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey.shade300),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.backup_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'No hay backups disponibles',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                )
              else
                ..._backups.map((backup) => _buildBackupItem(backup)),
            ],

            const SizedBox(height: 24),

            // Nota al pie
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 20,
                    color: Colors.blue.shade800,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Los archivos de respaldo contienen la configuración de departamentos y el inventario completo de activos TI.',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blue.shade900,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBackupItem(Map<String, dynamic> backup) {
    final date = backup['date'] as DateTime;
    final dateStr = '${date.day}/${date.month}/${date.year}';
    final timeStr =
        '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    final size = backup['size'] as String;
    final name = backup['name'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Fecha y tamaño
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeStr,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  size,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade800),
                ),
              ),
            ],
          ),

          // Nombre del archivo
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                name.length > 30
                    ? '...${name.substring(name.length - 30)}'
                    : name,
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.grey.shade500,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Botones Restaurar, Exportar y Eliminar
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _restaurarBackup(context, backup),
                  icon: const Icon(Icons.restore, size: 18),
                  label: const Text('Restaurar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () => _exportarBackup(backup),
                  icon: const Icon(Icons.download, size: 18),
                  label: const Text('Exportar'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 45,
                height: 45,
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.red.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () => _eliminarBackup(backup),
                  icon: const Icon(Icons.delete, color: Colors.red, size: 20),
                  tooltip: 'Eliminar backup',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Botones personalizados (igual que en tu diseño original)
class ElevatedIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const ElevatedIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}

class OutlinedIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const OutlinedIconButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primaryColor,
        side: const BorderSide(color: AppTheme.primaryColor),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
