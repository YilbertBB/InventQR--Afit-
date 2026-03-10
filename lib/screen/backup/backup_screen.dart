import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../../services/database_backup_service.dart';
import '../../core/app_theme.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  List<Map<String, dynamic>> _backups = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBackups();
  }

  Future<void> _loadBackups() async {
    setState(() => _isLoading = true);
    final backups = await DatabaseBackupService.getBackupsInfo();
    setState(() {
      _backups = backups;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Backups'),
        backgroundColor: AppTheme.primaryColor,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadBackups),
        ],
      ),
      body: Column(
        children: [
          // Botones de acción
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _exportBackup,
                    icon: const Icon(Icons.backup),
                    label: const Text('Nuevo Backup'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _importBackup,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restaurar'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Lista de backups
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _backups.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _backups.length,
                    itemBuilder: (context, index) {
                      final backup = _backups[index];
                      return _buildBackupCard(backup);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.backup_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay backups disponibles',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Crea tu primer backup con el botón "Nuevo Backup"',
            style: TextStyle(fontSize: 14, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildBackupCard(Map<String, dynamic> backup) {
    final file = backup['file'] as File;
    final date = backup['date'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(Icons.storage, color: AppTheme.primaryColor),
        ),
        title: Text(
          backup['name'],
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('📅 ${_formatDate(date)}'),
            Text('💾 ${backup['size']}'),
          ],
        ),
        trailing: PopupMenuButton(
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'share',
              child: Row(
                children: [
                  Icon(Icons.share, size: 20),
                  SizedBox(width: 8),
                  Text('Compartir'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'restore',
              child: Row(
                children: [
                  Icon(Icons.restore, size: 20, color: Colors.orange),
                  SizedBox(width: 8),
                  Text('Restaurar'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Eliminar'),
                ],
              ),
            ),
          ],
          onSelected: (value) async {
            if (value == 'share') {
              await SharePlus.instance.share(
                ShareParams(files: [XFile(file.path)]),
              );
            } else if (value == 'restore') {
              _showRestoreDialog(file);
            } else if (value == 'delete') {
              _showDeleteDialog(file);
            }
          },
        ),
      ),
    );
  }

  Future<void> _exportBackup() async {
    final file = await DatabaseBackupService.exportDatabaseToAppFolder();

    if (file != null) {
      await _loadBackups();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Backup creado: ${file.path}'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    }
  }

  Future<void> _importBackup(BuildContext context) async {
    try {
      // Seleccionar archivo
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['db'],
      );

      if (result != null && context.mounted) {
        final filePath = result.files.single.path!;
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('⚠️ Restaurar Backup'),
            content: const Text(
              'Esta acción reemplazará la base de datos actual.\n'
              '¿Estás seguro de continuar?',
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

        if (confirm == true && context.mounted) {
          final success = await DatabaseBackupService.importDatabaseFromFile(
            filePath,
            context,
          );

          if (success && mounted) {
            // Cerrar sesión o reiniciar app
            _showRestartDialog();
          }
        }
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  void _showRestoreDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restaurar Backup'),
        content: Text('¿Restaurar backup de ${file.path}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              final success =
                  await DatabaseBackupService.importDatabaseFromFile(
                    file.path,
                    context,
                  );
              if (success && mounted) {
                _showRestartDialog();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );
  }

  void _showDeleteDialog(File file) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar Backup'),
        content: Text('¿Eliminar backup ${file.path}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () async {
              await file.delete();
              if (context.mounted) {
                Navigator.pop(context);
                await _loadBackups();
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('✅ Backup eliminado'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
  }

  void _showRestartDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('✅ Base de datos restaurada'),
        content: const Text(
          'La base de datos ha sido restaurada correctamente.\n'
          'La aplicación se reiniciará para aplicar los cambios.',
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              // Aquí puedes navegar al login o reiniciar la app
              Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
            },
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
