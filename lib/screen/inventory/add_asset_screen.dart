import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/equipo.dart';
import '../../providers/departamento_provider.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/trabajador_provider.dart';
import '../../core/app_theme.dart';

class AddAssetScreen extends StatefulWidget {
  final Equipo? equipo;

  const AddAssetScreen({super.key, this.equipo});

  @override
  State<AddAssetScreen> createState() => _AddAssetScreenState();
}

class _AddAssetScreenState extends State<AddAssetScreen> {
  final bool _darkMode = false;
  bool _cargando = false;

  bool get _esModoEdicion =>
      widget.equipo != null &&
      widget.equipo!.id.startsWith('eq-'); // ← ID real de BD

  // bool get _esCreacionDesdeScanner =>
  //     widget.equipo != null &&
  //     widget.equipo!.id.startsWith('temp-'); // ← ID temporal

  // bool get _esCreacionManual => widget.equipo == null;

  // Controladores
  final TextEditingController _assetNameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _qrCodeController = TextEditingController();
  final TextEditingController _serialNumberController = TextEditingController();
  final TextEditingController _observacionesController =
      TextEditingController();
  final TextEditingController _costoController = TextEditingController();
  final TextEditingController _proyectoController = TextEditingController();

  // Selecciones
  String? _selectedDepartmentId = 'sin-departamento';
  String? _selectedDepartmentName;
  String? _selectedTipo;
  String? _selectedEstado = 'en espera';
  String? _selectedTrabajadorId;
  String? _selectedTrabajadorNombre;

  // Listas
  List<Map<String, String>> _departamentos = [];
  List<Map<String, String>> _trabajadores = [];

  // Tipos de equipo predefinidos
  final List<Map<String, dynamic>> _tiposEquipo = const [
    {'icon': Icons.computer, 'label': 'Computadora', 'value': 'Computadora'},
    {'icon': Icons.chair, 'label': 'Silla', 'value': 'Silla'},
    {'icon': Icons.table_chart, 'label': 'Mesa', 'value': 'Mesa'},
    {'icon': Icons.keyboard, 'label': 'Teclado', 'value': 'Teclado'},
    {'icon': Icons.monitor, 'label': 'Monitor', 'value': 'Monitor'},
    {'icon': Icons.mouse, 'label': 'Mouse', 'value': 'Mouse'},
    {'icon': Icons.devices_other, 'label': 'Otro', 'value': 'Otro'},
  ];

  // Estados predefinidos
  final List<Map<String, dynamic>> _estados = const [
    {'label': 'En espera', 'value': 'en espera'},
    {'label': 'Activo', 'value': 'activo'},
    {'label': 'Mantenimiento', 'value': 'mantenimiento'},
    {'label': 'Baja', 'value': 'baja'},
  ];

  @override
  void initState() {
    super.initState();

    // Cargar departamentos al iniciar
    Future.microtask(() {
      if (mounted) {
        _cargarDepartamentos();
      }
    });

    // ✅ Cargar datos del equipo SIEMPRE que exista un equipo
    if (widget.equipo != null) {
      // ← Usar widget.equipo != null, NO _esModoEdicion
      Future.microtask(() {
        if (mounted) {
          _cargarDatosEquipo();
        }
      });
    }
  }

  @override
  void dispose() {
    _assetNameController.dispose();
    _brandController.dispose();
    _modelController.dispose();
    _qrCodeController.dispose();
    _serialNumberController.dispose();
    _observacionesController.dispose();
    _costoController.dispose();
    _proyectoController.dispose();
    super.dispose();
  }

  // ============================================
  // CARGA DE DATOS
  // ============================================

  // lib/screens/add_asset_screen.dart

  // add_asset_screen.dart

  // add_asset_screen.dart

  Future<void> _cargarDepartamentos() async {
    if (!mounted) return;

    try {
      final provider = context.read<DepartamentoProvider>();
      await provider.cargarDepartamentos();

      if (!mounted) return;

      setState(() {
        // OBTENER DEPARTAMENTOS FILTRADOS
        _departamentos = provider.departamentos.map<Map<String, String>>((
          depto,
        ) {
          return {'id': depto.id, 'nombre': depto.nombre};
        }).toList();

        // ✅ SOLO UNA OPCIÓN POR DEFECTO: 'sin-departamento'
        _departamentos.insert(0, {
          'id': 'sin-departamento', // ← ÚNICO ID PARA "SIN DEPARTAMENTO"
          'nombre': 'Sin departamento',
        });
      });

      // Inicializar _selectedDepartmentId como 'sin-departamento' por defecto
      _selectedDepartmentId = 'sin-departamento';

      debugPrint('📋 Departamentos cargados: ${_departamentos.length}');
      debugPrint('📋 IDs: ${_departamentos.map((d) => d['id']).toList()}');

      // Si estamos en modo edición, seleccionar el departamento del equipo
      // En _cargarDepartamentos, dentro del if (_esModoEdicion)

      if (_esModoEdicion && mounted) {
        // ✅ Si el equipo tiene 'sin-departamento', seleccionar esa opción
        if (widget.equipo!.departamentoId == 'sin-departamento' ||
            widget.equipo!.departamentoId.isEmpty) {
          _selectedDepartmentId = 'sin-departamento';
          _selectedDepartmentName = null;
          debugPrint('✅ Seleccionado: sin-departamento');
        } else {
          // Verificar que el ID existe en la lista
          final existe = _departamentos.any(
            (d) => d['id'] == widget.equipo!.departamentoId,
          );

          if (existe) {
            _selectedDepartmentId = widget.equipo!.departamentoId;
            _selectedDepartmentName = widget.equipo!.departamentoNombre;
            debugPrint('✅ Seleccionado: ${widget.equipo!.departamentoId}');

            if (_selectedDepartmentId != null &&
                _selectedDepartmentId!.isNotEmpty &&
                _selectedDepartmentId != 'sin-departamento') {
              await _cargarTrabajadoresPorDepartamento(_selectedDepartmentId!);
            }
          } else {
            // Si no existe, seleccionar sin-departamento
            _selectedDepartmentId = 'sin-departamento';
            _selectedDepartmentName = null;
            debugPrint(
              '⚠️ Departamento no encontrado, usando sin-departamento',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando departamentos: $e');
    }
  }

  Future<void> _cargarTrabajadoresPorDepartamento(String departamentoId) async {
    if (departamentoId.isEmpty || !mounted) {
      setState(() => _trabajadores = []);
      return;
    }

    try {
      final provider = context.read<TrabajadorProvider>();
      final trabajadores = await provider.obtenerTrabajadoresPorDepartamento(
        departamentoId,
      );

      if (!mounted) return;

      setState(() {
        _trabajadores = trabajadores.map<Map<String, String>>((t) {
          return {'id': t.id, 'nombre': t.nombreCompleto, 'cargo': t.cargo};
        }).toList();

        _trabajadores.insert(0, {
          'id': '',
          'nombre': 'Sin asignar',
          'cargo': '',
        });
      });

      // En modo edición, restaurar el trabajador seleccionado después de cargar la lista
      if (_esModoEdicion && mounted) {
        if (widget.equipo!.trabajadorId != null &&
            widget.equipo!.trabajadorId!.isNotEmpty) {
          // Verificar que el trabajador sigue existiendo en el departamento
          final existeTrabajador = _trabajadores.any(
            (t) => t['id'] == widget.equipo!.trabajadorId,
          );

          if (existeTrabajador) {
            _selectedTrabajadorId = widget.equipo!.trabajadorId;
            _selectedTrabajadorNombre = widget.equipo!.trabajadorNombre;
          }
        }
      }
    } catch (e) {
      debugPrint('Error cargando trabajadores: $e');
    }
  }

  void _cargarDatosEquipo() {
    if (widget.equipo == null || !mounted) {
      return;
    }

    final equipo = widget.equipo!;

    debugPrint('📦 Cargando datos del equipo: ${equipo.nombre}');
    debugPrint('📦 ID: ${equipo.id}');
    debugPrint('📦 Desde escáner: ${equipo.id.startsWith('temp-')}');

    _assetNameController.text = equipo.nombre;
    _brandController.text = equipo.marca;
    _modelController.text = equipo.modelo;
    _qrCodeController.text = equipo.codigoQR;
    _serialNumberController.text = equipo.numeroSerie;
    _observacionesController.text = equipo.observaciones ?? '';
    _costoController.text = equipo.costo?.toStringAsFixed(2) ?? '';
    _proyectoController.text = equipo.proyectoNombre ?? '';

    _selectedTipo = equipo.tipo;
    _selectedEstado = equipo.estado;
    _selectedDepartmentId = equipo.departamentoId.isEmpty
        ? 'sin-departamento'
        : equipo.departamentoId;
    _selectedDepartmentName = equipo.departamentoNombre;
    _selectedTrabajadorId = equipo.trabajadorId;
    _selectedTrabajadorNombre = equipo.trabajadorNombre;
  }

  void _navigateToScanner() async {
    final codigoQR = 'QR-${DateTime.now().millisecondsSinceEpoch}';

    setState(() {
      _qrCodeController.text = codigoQR;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('QR escaneado: $codigoQR'),
          backgroundColor: Colors.green,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================
  // VALIDACIÓN Y GUARDADO - ❌ SIN CAMPOS OBLIGATORIOS
  // ============================================

  bool _validarFormulario() {
    // ✅ SOLO VALIDAMOS EL CÓDIGO QR PARA NUEVOS EQUIPOS
    if (!_esModoEdicion && _qrCodeController.text.trim().isEmpty) {
      _mostrarError('El código QR es obligatorio para nuevos equipos');
      return false;
    }

    return true;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _guardarEquipo() async {
    if (!_validarFormulario()) return;

    setState(() => _cargando = true);

    try {
      final provider = Provider.of<EquipoProvider>(context, listen: false);
      final ahora = DateTime.now();

      // ✅ LÓGICA CORREGIDA PARA DETECTAR EDICIÓN REAL
      final bool esEdicionReal =
          widget.equipo != null &&
          widget.equipo!.esEdicionReal; // ← Usa el helper

      debugPrint(
        '🔍 Modo: ${esEdicionReal ? "EDICIÓN REAL" : "CREACIÓN NUEVA"}',
      );

      if (widget.equipo != null) {
        debugPrint('🔍 Equipo temporal: ${widget.equipo!.esTemporal}');
        debugPrint('🔍 ID: ${widget.equipo!.id}');
        debugPrint('🔍 Departamento ID: ${widget.equipo!.departamentoId}');
      } else {
        debugPrint('🔍 Creación manual (sin equipo precargado)');
      }

      // Parsear costo si existe
      double? costo;
      if (_costoController.text.trim().isNotEmpty) {
        costo = double.tryParse(_costoController.text.trim());
      }

      // ✅ Crear objeto Equipo con valores del formulario
      final equipo = Equipo(
        id: esEdicionReal ? widget.equipo!.id : Equipo.generarId(),
        codigoQR: _qrCodeController.text.trim(),
        nombre: _assetNameController.text.trim().isEmpty
            ? 'Equipo sin nombre'
            : _assetNameController.text.trim(),
        tipo: _selectedTipo ?? 'Otro',
        marca: _brandController.text.trim().isEmpty
            ? 'Sin marca'
            : _brandController.text.trim(),
        modelo: _modelController.text.trim().isEmpty
            ? 'Sin modelo'
            : _modelController.text.trim(),
        estado: _selectedEstado ?? 'en espera',
        numeroSerie: _serialNumberController.text.trim().isEmpty
            ? 'SN-${DateTime.now().millisecondsSinceEpoch}'
            : _serialNumberController.text.trim(),

        departamentoId: _selectedDepartmentId ?? 'sin-departamento',

        departamentoNombre: _selectedDepartmentId == 'sin-departamento'
            ? null
            : _selectedDepartmentName,

        proyectoId: '',
        proyectoNombre: _proyectoController.text.trim().isEmpty
            ? null
            : _proyectoController.text.trim(),
        trabajadorId:
            _selectedTrabajadorId == null || _selectedTrabajadorId!.isEmpty
            ? null
            : _selectedTrabajadorId,
        trabajadorNombre:
            _selectedTrabajadorNombre == null ||
                _selectedTrabajadorNombre!.isEmpty
            ? null
            : _selectedTrabajadorNombre,
        fechaAdquisicion: esEdicionReal
            ? widget.equipo!.fechaAdquisicion
            : ahora,
        fechaAsignacion: _selectedTrabajadorId?.isNotEmpty == true
            ? (esEdicionReal && widget.equipo!.fechaAsignacion != null
                  ? widget.equipo!.fechaAsignacion
                  : ahora)
            : null,
        usuarioCreacion: esEdicionReal
            ? widget.equipo!.usuarioCreacion
            : 'usuario_actual',
        fechaCreacion: esEdicionReal ? widget.equipo!.fechaCreacion : ahora,
        activo: true,
        observaciones: _observacionesController.text.trim().isEmpty
            ? null
            : _observacionesController.text.trim(),
        costo: costo,
        fechaGarantia: null,
      );

      debugPrint('📦 Equipo a guardar: ${equipo.nombre}');
      debugPrint(
        '📦 Tipo operación: ${esEdicionReal ? "ACTUALIZAR" : "CREAR"}',
      );
      debugPrint('📦 Departamento ID: ${equipo.departamentoId}');

      bool success;
      if (esEdicionReal) {
        success = await provider.actualizarEquipo(equipo);
        debugPrint('🔄 Actualizando equipo existente...');
      } else {
        success = await provider.crearEquipo(equipo);
        debugPrint('🆕 Creando nuevo equipo...');
      }

      if (success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              esEdicionReal
                  ? '✅ Equipo actualizado exitosamente'
                  : '✅ Equipo creado exitosamente',
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );

        // ✅ Asegurar que el provider recargó
        await provider.cargarEquipos();

        if (mounted) {
          Navigator.pop(context, true);
        }
      } else if (mounted) {
        _mostrarError('Error: ${provider.error ?? "No se pudo guardar"}');
      }
    } catch (e) {
      if (mounted) {
        _mostrarError('Error al guardar el equipo: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  // ============================================
  // CONSTRUCCIÓN DE UI - SIN ASTERISCOS (*)
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkMode
          ? Theme.of(context).copyWith(brightness: Brightness.dark)
          : Theme.of(context).copyWith(brightness: Brightness.light),
      child: Scaffold(
        backgroundColor: _darkMode
            ? const Color(0xFF101622)
            : AppTheme.backgroundColorLight,
        appBar: AppBar(
          leading: IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: _darkMode ? Colors.white : Colors.black,
              size: 24,
            ),
          ),
          title: Text(
            _esModoEdicion ? 'Editar Equipo' : 'Añadir Nuevo Equipo',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: _darkMode ? Colors.white : const Color(0xFF111318),
            ),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: _cargando
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              )
            : SafeArea(
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 430),
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildBasicInfoSection(),
                        const SizedBox(height: 32),
                        _buildTipoSection(),
                        const SizedBox(height: 32),
                        _buildEstadoSection(),
                        const SizedBox(height: 32),
                        buildDepartamentoSection(),
                        const SizedBox(height: 32),
                        buildTrabajadorSection(),
                        const SizedBox(height: 32),
                        buildAdditionalInfoSection(),
                        const SizedBox(height: 32),
                        buildQRSection(),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
        bottomNavigationBar: buildFooterActions(),
      ),
    );
  }

  // ============================================
  // SECCIONES DEL FORMULARIO - SIN ASTERISCOS (*)
  // ============================================

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Nombre del Equipo',
          hintText: 'Ej. PC-I5 - Desarrollo 2 (opcional)',
          controller: _assetNameController,
          isRequired: false, // ❌ Ya no es obligatorio
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Marca',
          hintText: 'Ej. Dell, HP, Lenovo (opcional)',
          controller: _brandController,
          isRequired: false, // ❌ Ya no es obligatorio
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Modelo',
          hintText: 'Ej. PC-I5, Silla Ergonómica X (opcional)',
          controller: _modelController,
          isRequired: false, // ❌ Ya no es obligatorio
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Número de Serie',
          hintText: 'Ingrese el número de serie (opcional)',
          controller: _serialNumberController,
          isRequired: false, // ❌ Ya no es obligatorio
        ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    bool isRequired = false, // ✅ Parámetro mantenido pero siempre false
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _darkMode
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF374151),
            ),
          ),
        ),
        Container(
          height: 50,
          decoration: BoxDecoration(
            color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _darkMode
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: TextField(
            controller: controller,
            style: TextStyle(
              fontSize: 16,
              color: _darkMode ? Colors.white : Colors.black,
            ),
            keyboardType: keyboardType,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: TextStyle(
                color: const Color(0xFF9CA3AF),
                fontSize: 16,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(
                  color: AppTheme.primaryColor,
                  width: 2,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 16),
          child: Text(
            'TIPO DE EQUIPO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _darkMode
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF374151),
              letterSpacing: 1.0,
            ),
          ),
        ),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.0,
          children: _tiposEquipo.map((tipo) {
            final bool isSelected = _selectedTipo == tipo['value'];
            return _buildTipoCard(
              icon: tipo['icon'] as IconData,
              label: tipo['label'] as String,
              isSelected: isSelected,
              onTap: () {
                setState(() {
                  _selectedTipo = tipo['value'] as String;
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTipoCard({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected
                ? AppTheme.primaryColor
                : (_darkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9)),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.2),
                    blurRadius: 8,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 32,
              color: isSelected
                  ? AppTheme.primaryColor
                  : const Color(0xFF6B7280),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? AppTheme.primaryColor
                    : (_darkMode
                          ? const Color(0xFF94A3B8)
                          : const Color(0xFF6B7280)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEstadoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ESTADO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _darkMode
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF374151),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _darkMode
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedEstado,
              onChanged: (String? newValue) {
                setState(() {
                  _selectedEstado = newValue;
                });
              },
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: _darkMode ? Colors.white : Colors.black,
              ),
              dropdownColor: _darkMode ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(
                fontSize: 16,
                color: _darkMode ? Colors.white : Colors.black,
              ),
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Seleccionar estado (opcional)',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
              items: _estados.map((estado) {
                return DropdownMenuItem<String>(
                  value: estado['value'] as String,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      estado['label'] as String,
                      style: TextStyle(
                        color: _darkMode ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildDepartamentoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'DEPARTAMENTO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _darkMode
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF374151),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _darkMode
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedDepartmentId,
              onChanged: (String? newValue) async {
                setState(() {
                  _selectedDepartmentId = newValue;
                  _selectedTrabajadorId = '';
                  _selectedTrabajadorNombre = null;

                  if (newValue != null && newValue != 'sin-departamento') {
                    final depto = _departamentos.firstWhere(
                      (d) => d['id'] == newValue,
                      orElse: () => {'id': 'sin-departamento', 'nombre': ''},
                    );
                    _selectedDepartmentName = depto['nombre'];
                  } else {
                    _selectedDepartmentName = null;
                  }
                });

                if (newValue != null &&
                    newValue != 'sin-departamento' &&
                    mounted) {
                  await _cargarTrabajadoresPorDepartamento(newValue);
                }
              },
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color: _darkMode ? Colors.white : Colors.black,
              ),
              dropdownColor: _darkMode ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(
                fontSize: 16,
                color: _darkMode ? Colors.white : Colors.black,
              ),
              hint: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  'Seleccionar departamento',
                  style: TextStyle(color: Color(0xFF9CA3AF)),
                ),
              ),
              items: _departamentos.map((depto) {
                final bool isSinDepartamento =
                    depto['id'] == 'sin-departamento';
                return DropdownMenuItem<String>(
                  value: depto['id'],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(
                      depto['nombre']!,
                      style: TextStyle(
                        color: isSinDepartamento
                            ? const Color(0xFF9CA3AF)
                            : (_darkMode ? Colors.white : Colors.black),
                        fontStyle: isSinDepartamento ? FontStyle.italic : null,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget buildTrabajadorSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'ASIGNAR A TRABAJADOR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: _darkMode
                  ? const Color(0xFFCBD5E1)
                  : const Color(0xFF374151),
              letterSpacing: 1.0,
            ),
          ),
        ),
        Container(
          height: 56,
          decoration: BoxDecoration(
            color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _darkMode
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _selectedTrabajadorId,
              onChanged:
                  (_selectedDepartmentId == null ||
                      _selectedDepartmentId!.isEmpty)
                  ? null
                  : (String? newValue) {
                      setState(() {
                        _selectedTrabajadorId = newValue;
                        if (newValue != null && newValue.isNotEmpty) {
                          final trabajador = _trabajadores.firstWhere(
                            (t) => t['id'] == newValue,
                            orElse: () => const {
                              'id': '',
                              'nombre': '',
                              'cargo': '',
                            },
                          );
                          _selectedTrabajadorNombre = trabajador['nombre'];
                        } else {
                          _selectedTrabajadorNombre = null;
                        }
                      });
                    },
              isExpanded: true,
              icon: Icon(
                Icons.keyboard_arrow_down,
                color:
                    (_selectedDepartmentId == null ||
                        _selectedDepartmentId!.isEmpty)
                    ? Colors.grey
                    : (_darkMode ? Colors.white : Colors.black),
              ),
              dropdownColor: _darkMode ? const Color(0xFF1E293B) : Colors.white,
              style: TextStyle(
                fontSize: 16,
                color:
                    (_selectedDepartmentId == null ||
                        _selectedDepartmentId!.isEmpty)
                    ? Colors.grey
                    : (_darkMode ? Colors.white : Colors.black),
              ),
              hint: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  _selectedDepartmentId == null ||
                          _selectedDepartmentId!.isEmpty
                      ? 'Primero seleccione un departamento'
                      : 'Seleccionar trabajador (opcional)',
                  style: TextStyle(
                    color:
                        _selectedDepartmentId == null ||
                            _selectedDepartmentId!.isEmpty
                        ? Colors.grey
                        : const Color(0xFF9CA3AF),
                  ),
                ),
              ),
              items: _trabajadores.map((trabajador) {
                final bool isDefault = trabajador['id'] == '';
                return DropdownMenuItem<String>(
                  value: trabajador['id'],
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          trabajador['nombre'] ?? 'Sin nombre',
                          style: TextStyle(
                            color: isDefault
                                ? const Color(0xFF9CA3AF)
                                : (_darkMode ? Colors.white : Colors.black),
                            fontSize: 15,
                          ),
                        ),
                        if (!isDefault &&
                            trabajador['cargo'] != null &&
                            trabajador['cargo']!.isNotEmpty)
                          Text(
                            trabajador['cargo']!,
                            style: TextStyle(
                              fontSize: 11,
                              color: _darkMode
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (_selectedDepartmentId != null && _selectedDepartmentId!.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 4),
            child: Text(
              'La asignación se registrará en el historial del equipo',
              style: TextStyle(
                fontSize: 11,
                color: _darkMode ? Colors.grey[400] : Colors.grey[600],
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
      ],
    );
  }

  Widget buildAdditionalInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildTextField(
          label: 'Proyecto/Área',
          hintText: 'Ej. Desarrollo 2, Marketing (opcional)',
          controller: _proyectoController,
          isRequired: false,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Costo (S/.)',
          hintText: 'Ej. 1500.00 (opcional)',
          controller: _costoController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          isRequired: false,
        ),
        const SizedBox(height: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Observaciones',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _darkMode
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF374151),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _darkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFE5E7EB),
                ),
              ),
              child: TextField(
                controller: _observacionesController,
                style: TextStyle(
                  fontSize: 16,
                  color: _darkMode ? Colors.white : Colors.black,
                ),
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Notas adicionales sobre el equipo... (opcional)',
                  hintStyle: TextStyle(
                    color: const Color(0xFF9CA3AF),
                    fontSize: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: AppTheme.primaryColor,
                      width: 2,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ============================================
  // SELECTOR DE FORMATO QR
  // ============================================

  String formatoQRSeleccionado =
      'recomendado'; // recomendado, inventario, uuid, numerico, semantico, timestamp

  final List<Map<String, dynamic>> formatosQR = [
    {
      'valor': 'recomendado',
      'label': 'Recomendado automático',
      'descripcion': 'Elige el mejor formato según el tipo de equipo',
      'icono': Icons.auto_awesome,
    },
    {
      'valor': 'inventario',
      'label': 'Inventario secuencial',
      'descripcion': 'INV-2026-02-0001, INV-2026-02-0002...',
      'icono': Icons.format_list_numbered,
    },
    {
      'valor': 'uuid',
      'label': 'UUID único',
      'descripcion': 'Identificador universal único',
      'icono': Icons.fingerprint,
    },
    {
      'valor': 'numerico',
      'label': 'Numérico simple',
      'descripcion': '000001, 000002, 000003...',
      'icono': Icons.numbers,
    },
    {
      'valor': 'semantico',
      'label': 'Semántico',
      'descripcion': 'COMPU-DESARROLLO-001, SILLA-MARKETING-002',
      'icono': Icons.tag,
    },
    {
      'valor': 'timestamp',
      'label': 'Timestamp',
      'descripcion': 'QR-20260211-143022',
      'icono': Icons.access_time,
    },
  ];

  Future<void> generarCodigoQRConFormato() async {
    if (_cargando) return;

    setState(() => _cargando = true);

    try {
      final provider = Provider.of<EquipoProvider>(context, listen: false);
      String codigo;

      switch (formatoQRSeleccionado) {
        case 'inventario':
          codigo = await provider.generarQRInventario();
          break;
        case 'uuid':
          codigo = provider.generarQRUUID();
          break;
        case 'numerico':
          codigo = await provider.generarQRNumerico();
          break;
        case 'semantico':
          codigo = await provider.generarQRSemantico(
            tipo: _selectedTipo ?? 'EQ',
            proyecto: _proyectoController.text.trim(),
            departamento: _selectedDepartmentName,
          );
          break;
        case 'timestamp':
          codigo = provider.generarQRTimestamp();
          break;
        case 'recomendado':
        default:
          codigo = await provider.generarQRRecomendado(
            tipo: _selectedTipo,
            proyecto: _proyectoController.text.trim(),
            departamento: _selectedDepartmentName,
          );
          break;
      }

      setState(() {
        _qrCodeController.text = codigo;
      });

      if (mounted) {
        final formato = formatosQR.firstWhere(
          (f) => f['valor'] == formatoQRSeleccionado,
          orElse: () => {'label': 'QR'},
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${formato['label']} generado: $codigo'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ Error generando QR: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  Widget buildQRSection() {
    return Column(
      children: [
        // Selector de formato QR
        Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _darkMode ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _darkMode
                  ? const Color(0xFF334155)
                  : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.qr_code_2, color: AppTheme.primaryColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'FORMATO DE CÓDIGO QR',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _darkMode
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF374151),
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                decoration: BoxDecoration(
                  color: _darkMode ? const Color(0xFF1E293B) : Colors.grey[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _darkMode
                        ? const Color(0xFF475569)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: formatoQRSeleccionado,
                    onChanged: (String? newValue) {
                      setState(() {
                        formatoQRSeleccionado = newValue!;
                      });
                    },
                    isExpanded: true,
                    icon: Icon(
                      Icons.keyboard_arrow_down,
                      color: _darkMode ? Colors.white : Colors.black,
                    ),
                    dropdownColor: _darkMode
                        ? const Color(0xFF1E293B)
                        : Colors.white,
                    style: TextStyle(
                      fontSize: 14,
                      color: _darkMode ? Colors.white : Colors.black,
                    ),
                    items: formatosQR.map((formato) {
                      return DropdownMenuItem<String>(
                        value: formato['valor'] as String,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Row(
                            children: [
                              Icon(
                                formato['icono'] as IconData,
                                size: 20,
                                color: AppTheme.primaryColor,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      formato['label'] as String,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        color: _darkMode
                                            ? Colors.white
                                            : Colors.black,
                                      ),
                                    ),
                                    Text(
                                      formato['descripcion'] as String,
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: _darkMode
                                            ? Colors.grey[400]
                                            : Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              if (formatoQRSeleccionado == 'semantico' && _selectedTipo == null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 14,
                        color: Colors.orange[700],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Selecciona un tipo de equipo para mejor resultado',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.orange[700],
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),

        // Botones de acción
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _navigateToScanner,
                child: Container(
                  height: 72,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.primaryColor, width: 2),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.qr_code_scanner,
                        color: AppTheme.primaryColor,
                        size: 28,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Escanear QR',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              height: 72,
              width: 72,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppTheme.primaryColor, width: 2),
              ),
              child: IconButton(
                onPressed: generarCodigoQRConFormato,
                icon: _cargando
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          color: AppTheme.primaryColor,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.auto_awesome,
                        color: AppTheme.primaryColor,
                        size: 32,
                      ),
                tooltip: 'Generar QR automático',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Text(
            _esModoEdicion
                ? 'QR Actual: ${_qrCodeController.text}'
                : 'Selecciona un formato y genera el QR automáticamente',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: _darkMode
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF6B7280),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTextField(
          label: 'Código QR',
          hintText: 'Código generado automáticamente',
          controller: _qrCodeController,
          isRequired: !_esModoEdicion,
        ),
      ],
    );
  }

  Widget buildFooterActions() {
    return Container(
      decoration: BoxDecoration(
        color: _darkMode
            ? const Color(0xFF0F172A).withValues(alpha: 0.8)
            : Colors.white.withValues(alpha: 0.8),
        border: Border(
          top: BorderSide(
            color: _darkMode
                ? const Color(0xFF334155)
                : const Color(0xFFF1F5F9),
          ),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _cargando ? null : () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: _darkMode
                        ? const Color(0xFFCBD5E1)
                        : const Color(0xFF374151),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(
                        color: _darkMode
                            ? const Color(0xFF475569)
                            : const Color(0xFFD1D5DB),
                      ),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    'Cancelar',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _darkMode
                          ? const Color(0xFFCBD5E1)
                          : const Color(0xFF374151),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              flex: 2,
              child: SizedBox(
                height: 56,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _guardarEquipo,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryColor,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 4,
                    shadowColor: const Color(
                      0xFF135BEC,
                    ).withValues(alpha: 0.25),
                  ),
                  child: _cargando
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : Text(
                          _esModoEdicion ? 'Actualizar' : 'Guardar Equipo',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
