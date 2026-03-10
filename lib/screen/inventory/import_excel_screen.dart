import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../services/excel_import_service.dart';
import '../../providers/equipo_provider.dart';
import '../../core/app_theme.dart';

class ImportExcelScreen extends StatefulWidget {
  const ImportExcelScreen({super.key});

  @override
  State<ImportExcelScreen> createState() => _ImportExcelScreenState();
}

class _ImportExcelScreenState extends State<ImportExcelScreen> {
  bool _fileSelected = false;
  double _uploadProgress = 0.0;
  String? _fileName;
  bool _isUploading = false;
  bool _importComplete = false;

  List<Map<String, dynamic>> _previewData = [];
  int _totalRegistros = 0;
  Map<String, String> _departamentosMap = {};

  // Resultados de importación
  int _exitosos = 0;
  int _errores = 0;
  List<Map<String, dynamic>> _erroresList = [];

  @override
  void initState() {
    super.initState();
    _cargarDepartamentos();
  }

  Future<void> _cargarDepartamentos() async {
    _departamentosMap = await ExcelImportService.obtenerMapaDepartamentos();
  }

  Future<void> _selectFile() async {
    final file = await ExcelImportService.seleccionarArchivo();

    if (file != null) {
      setState(() {
        _fileSelected = true;
        _fileName = file.path.split('/').last;
        _isUploading = true;
        _uploadProgress = 0.0;
        _importComplete = false;
      });

      // Leer archivo
      final resultado = await ExcelImportService.leerArchivo(file);

      if (resultado['success'] == true) {
        setState(() {
          _previewData = List<Map<String, dynamic>>.from(
            resultado['registros'],
          ).take(5).toList(); // Solo mostrar 5 en vista previa
          _totalRegistros = resultado['totalRegistros'];
        });

        _simulateUpload();
      } else {
        setState(() {
          _isUploading = false;
          _fileSelected = false;
          _fileName = null;
        });

        _showErrorDialog('Error al leer archivo', resultado['error']);
      }
    }
  }

  void _simulateUpload() async {
    for (int i = 0; i <= 100; i += 5) {
      await Future.delayed(const Duration(milliseconds: 50));
      if (mounted) {
        setState(() {
          _uploadProgress = i / 100;
        });
      }
    }

    if (mounted) {
      setState(() {
        _isUploading = false;
      });
    }
  }

  Future<void> _startImport(BuildContext context) async {
    if (!_fileSelected || _isUploading || _previewData.isEmpty) return;

    // Mostrar diálogo de confirmación
    final confirm = await _showConfirmDialog();
    if (!confirm) return;

    setState(() {
      _isUploading = true;
      _uploadProgress = 0.0;
      _erroresList.clear();
    });

    try {
      final usuario = 'root';

      // Procesar importación
      final resultado = await ExcelImportService.importarEquipos(
        registros: _previewData, // Esto solo tiene 5 registros, necesitas todos
        departamentosMap: _departamentosMap,
        usuarioCreacion: usuario,
      );

      if (resultado['success'] == true) {
        setState(() {
          _exitosos = resultado['exitosos'];
          _errores = resultado['errores'].length;
          _erroresList = List<Map<String, dynamic>>.from(resultado['errores']);
          _importComplete = true;
          _uploadProgress = 1.0;
        });
        if (context.mounted) {
          await Provider.of<EquipoProvider>(
            context,
            listen: false,
          ).cargarEquipos();
        }
        // Recargar equipos en el provider

        // Mostrar resultado
        _showResultDialog();
      } else {
        _showErrorDialog('Error en importación', resultado['error']);
      }
    } catch (e) {
      _showErrorDialog('Error inesperado', e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<bool> _showConfirmDialog() async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            title: const Text(
              'Confirmar Importación',
              style: TextStyle(
                color: Color(0xFF111318),
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se importarán $_totalRegistros registros a la base de datos.',
                  style: const TextStyle(color: Color(0xFF111318)),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: AppTheme.warningColor.withValues(alpha: 0.2),
                    ),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.info, color: AppTheme.warningColor, size: 20),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Esta acción creará nuevos equipos. Asegúrate de que los datos sean correctos.',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF92400E),
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
                child: const Text(
                  'Cancelar',
                  style: TextStyle(color: Color(0xFF64748B)),
                ),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                ),
                child: const Text('Confirmar'),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _showResultDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Importación Completada',
          style: TextStyle(
            color: Color(0xFF111318),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _errores == 0
                    ? Colors.green.shade50
                    : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    _errores == 0 ? Icons.check_circle : Icons.warning,
                    color: _errores == 0 ? Colors.green : Colors.orange,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '✅ $_exitosos exitosos',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        if (_errores > 0)
                          Text(
                            '❌ $_errores con errores',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_erroresList.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text(
                'Errores encontrados:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Container(
                constraints: const BoxConstraints(maxHeight: 150),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _erroresList.length,
                  itemBuilder: (context, index) {
                    final error = _erroresList[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 4),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Registro ${index + 1}: ${error['error']}',
                        style: const TextStyle(fontSize: 11, color: Colors.red),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _fileSelected = false;
                _fileName = null;
                _previewData = [];
                _totalRegistros = 0;
                _importComplete = false;
                _uploadProgress = 0.0;
              });
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

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.red)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _fileSelected = false;
                _fileName = null;
                _isUploading = false;
              });
            },
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  String _getProgressStatus() {
    if (_importComplete) return '¡Importación completada!';
    if (_uploadProgress < 0.3) return 'Leyendo estructura del archivo...';
    if (_uploadProgress < 0.6) return 'Validando datos...';
    if (_uploadProgress < 0.9) return 'Procesando registros...';
    return 'Finalizando importación...';
  }

  Color _getDepartmentColor(String department) {
    switch (department.toLowerCase()) {
      case 'sistemas':
        return const Color(0xFF3B82F6);
      case 'diseño':
      case 'diseno':
        return const Color(0xFF8B5CF6);
      case 'ventas':
        return AppTheme.successColor;
      default:
        return const Color(0xFF64748B);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Importar desde Excel',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: AppTheme.backgroundColorLight,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
        actions: [
          IconButton(
            onPressed: () => _showHelpDialog(context),
            icon: const Icon(
              Icons.help_outline,
              color: Color(0xFF64748B),
              size: 20,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 430),
          margin: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.only(bottom: 140),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInstructionSection(),
                      _buildUploadZone(),
                      if (_isUploading) _buildProgressBar(),
                      if (_fileSelected && _previewData.isNotEmpty)
                        _buildPreviewSection(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomSheet: _buildBottomActionBar(),
    );
  }

  Widget _buildInstructionSection() {
    final requiredColumns = [
      {'label': 'Nombre', 'icon': Icons.check_circle},
      {'label': 'Tipo', 'icon': Icons.check_circle},
      {'label': 'Marca', 'icon': Icons.check_circle},
      {'label': 'Modelo', 'icon': Icons.check_circle},
      {'label': 'Número Serie', 'icon': Icons.check_circle},
      {'label': 'Departamento', 'icon': Icons.check_circle},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: const Text(
              'Instrucciones de formato',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Color(0xFF111318),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(
              top: 8,
              left: 4,
              right: 4,
              bottom: 16,
            ),
            child: Text(
              'Para una correcta importación, asegúrate de que tu archivo incluya las siguientes columnas:',
              style: const TextStyle(
                fontSize: 14,
                color: Color(0xFF64748B),
                height: 1.5,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 3.2,
              children: requiredColumns.map((column) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Icon(
                        column['icon'] as IconData,
                        color: AppTheme.primaryColor,
                        size: 18,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          column['label'] as String,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF111318),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUploadZone() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: GestureDetector(
        onTap: _fileSelected && !_isUploading ? null : _selectFile,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _fileSelected
                  ? AppTheme.primaryColor.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Center(
            child: Column(
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _fileSelected ? Icons.file_present : Icons.upload_file,
                    color: AppTheme.primaryColor,
                    size: 40,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  _fileSelected
                      ? 'Archivo seleccionado'
                      : 'Cargar archivo Excel',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF111318),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _fileSelected
                      ? _fileName ?? 'archivo.xlsx'
                      : 'Formatos soportados: .xlsx, .xls, .csv',
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF64748B),
                  ),
                ),
                const SizedBox(height: 20),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  height: 44,
                  width: _fileSelected ? 200 : 180,
                  decoration: BoxDecoration(
                    color: _fileSelected
                        ? AppTheme.successColor
                        : AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(999),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (_fileSelected
                                    ? AppTheme.successColor
                                    : AppTheme.primaryColor)
                                .withValues(alpha: 0.3),
                        blurRadius: 16,
                        spreadRadius: 2,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _fileSelected ? Icons.check : Icons.cloud_upload,
                          color: Colors.white,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _fileSelected
                              ? 'Archivo Listo'
                              : 'Seleccionar Archivo',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_fileSelected && !_isUploading) ...[
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        _fileSelected = false;
                        _fileName = null;
                        _uploadProgress = 0.0;
                        _isUploading = false;
                        _previewData = [];
                        _totalRegistros = 0;
                      });
                    },
                    child: const Text(
                      'Elegir otro archivo',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE2E8F0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _importComplete
                            ? 'Importación completada'
                            : 'Procesando archivo...',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF111318),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _fileName ?? 'archivo.xlsx',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF64748B),
                          overflow: TextOverflow.ellipsis,
                        ),
                        maxLines: 1,
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(_uploadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Stack(
              children: [
                Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: const Color(0xFFE2E8F0),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 500),
                  height: 8,
                  width:
                      MediaQuery.of(context).size.width * 0.8 * _uploadProgress,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor,
                    borderRadius: BorderRadius.circular(999),
                    gradient: const LinearGradient(
                      colors: [AppTheme.primaryColor, Color(0xFF3B82F6)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              _getProgressStatus(),
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Vista previa de datos',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF111318),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$_totalRegistros registros',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF64748B),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE2E8F0)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 32,
                horizontalMargin: 16,
                headingRowHeight: 56,
                headingRowColor: WidgetStateProperty.all(
                  const Color(0xFFF8FAFC),
                ),
                columns: const [
                  DataColumn(
                    label: Text(
                      'NOMBRE',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'TIPO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'MARCA',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                  DataColumn(
                    label: Text(
                      'DEPARTAMENTO',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF64748B),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ],
                rows: _previewData.map((row) {
                  // ⚠️ CORREGIDO: Obtener valores directamente del mapa
                  final nombre = _obtenerValorPreview(row, 'nombre');
                  final tipo = _obtenerValorPreview(row, 'tipo');
                  final marca = _obtenerValorPreview(row, 'marca');
                  final depto = _obtenerValorPreview(row, 'departamento');

                  return DataRow(
                    cells: [
                      DataCell(
                        Container(
                          constraints: const BoxConstraints(maxWidth: 150),
                          child: Text(
                            nombre,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF111318),
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          tipo,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      DataCell(
                        Text(
                          marca,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                      DataCell(
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: _getDepartmentColor(
                              depto,
                            ).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            depto,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _getDepartmentColor(depto),
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Total a importar',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    Text(
                      '$_totalRegistros activos',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111318),
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Vista previa',
                      style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                    ),
                    Text(
                      '${_previewData.length} mostrados',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111318),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ⚠️ NUEVO: Método auxiliar para obtener valores en vista previa
  String _obtenerValorPreview(Map<String, dynamic> registro, String clave) {
    // Buscar en el registro ignorando mayúsculas/minúsculas
    var key = registro.keys.firstWhere(
      (k) => k.toLowerCase().contains(clave.toLowerCase()),
      orElse: () => '',
    );

    if (key.isEmpty) return '';

    var valor = registro[key]?.toString() ?? '';
    return valor.trim();
  }

  Widget _buildBottomActionBar() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFFE2E8F0))),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFEF3C7).withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppTheme.warningColor.withValues(alpha: 0.2),
                ),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info, color: AppTheme.warningColor, size: 18),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Al confirmar, se crearán los registros de activos y se generarán códigos QR únicos para cada uno.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: () =>
                    _fileSelected && !_isUploading && !_importComplete
                    ? _startImport
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      _fileSelected && !_isUploading && !_importComplete
                      ? AppTheme.primaryColor
                      : const Color(0xFF94A3B8),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (_isUploading)
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                    else if (_importComplete)
                      const Icon(Icons.check_circle, size: 22)
                    else
                      const Icon(Icons.cloud_upload, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      _isUploading
                          ? 'Importando...'
                          : _importComplete
                          ? 'Importación Completada'
                          : 'Confirmar Importación',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Text(
            'Ayuda - Formato de Excel',
            style: TextStyle(
              color: Color(0xFF111318),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildHelpItem(
                  'Columnas requeridas:',
                  'Nombre, Tipo, Marca, Modelo, Número Serie, Departamento',
                ),
                _buildHelpItem(
                  'Columnas opcionales:',
                  'Costo, Fecha Garantía, Observaciones',
                ),
                _buildHelpItem(
                  'Tipos de archivo:',
                  'Soporta archivos .xlsx, .xls y .csv con codificación UTF-8.',
                ),
                _buildHelpItem(
                  'Tamaño máximo:',
                  'El archivo no debe superar los 10MB para un procesamiento óptimo.',
                ),
                _buildHelpItem(
                  'Departamentos:',
                  'Los nombres de departamento deben coincidir con los existentes en el sistema.',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text(
                'Entendido',
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHelpItem(String title, String description) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFF111318),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(color: Color(0xFF64748B), fontSize: 13),
          ),
        ],
      ),
    );
  }
}
