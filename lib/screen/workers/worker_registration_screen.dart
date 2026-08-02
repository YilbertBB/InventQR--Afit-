import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/trabajador.dart';
import '../../providers/trabajador_provider.dart';
import '../../providers/departamento_provider.dart';
import '../../providers/auth_provider.dart';
import '../../models/departamento.dart';
import '../../core/app_theme.dart';

class WorkerRegistrationScreen extends StatefulWidget {
  final Trabajador? trabajador;

  const WorkerRegistrationScreen({super.key, this.trabajador});

  @override
  State<WorkerRegistrationScreen> createState() =>
      _WorkerRegistrationScreenState();
}

class _WorkerRegistrationScreenState extends State<WorkerRegistrationScreen> {
  bool _isActive = true;
  bool _isLoading = false;

  // Controladores
  final TextEditingController _nombresController = TextEditingController();
  final TextEditingController _apellidosController = TextEditingController();
  final TextEditingController _dniController = TextEditingController();
  final TextEditingController _cargoController = TextEditingController();
  final TextEditingController _areaController = TextEditingController();
  final TextEditingController _telefonoController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();

  // Variables para dropdown
  Departamento? _departamentoSeleccionado;
  DateTime? _fechaIngresoSeleccionada;

  @override
  void initState() {
    super.initState();

    // Cargar departamentos DESPUÉS de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final deptoProvider = Provider.of<DepartamentoProvider>(
        context,
        listen: false,
      );
      deptoProvider.cargarDepartamentos();
    });

    // Si estamos en modo edición, cargar los datos del trabajador
    if (widget.trabajador != null) {
      // También usar post frame callback para cargar los datos
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cargarDatosTrabajador();
      });
    }
  }

  void _cargarDatosTrabajador() async {
    final trabajador = widget.trabajador!;

    // Cargar datos básicos primero
    _nombresController.text = trabajador.nombres;
    _apellidosController.text = trabajador.apellidos;
    _dniController.text = trabajador.dni;
    _cargoController.text = trabajador.cargo;
    _areaController.text = trabajador.area;
    _telefonoController.text = trabajador.telefono ?? '';
    _emailController.text = trabajador.emailCorporativo ?? '';
    _fechaIngresoSeleccionada = trabajador.fechaIngreso;
    _isActive = trabajador.activo;

    // Obtener el provider
    final deptoProvider = Provider.of<DepartamentoProvider>(
      context,
      listen: false,
    );

    // Esperar a que los departamentos estén cargados
    if (deptoProvider.departamentos.isEmpty) {
      await deptoProvider.cargarDepartamentos();
    }

    // Buscar y seleccionar el departamento por ID
    if (mounted) {
      final deptoEncontrado = deptoProvider.departamentos.firstWhere(
        (d) => d.id == trabajador.departamentoId,
        orElse: () {
          // Si no se encuentra, crear uno temporal para mostrar
          return Departamento(
            id: trabajador.departamentoId,
            nombre: trabajador.departamentoNombre ?? 'Sin departamento',
            cantidadEquiposAsignados: 0,
            cantidadPersonal: 0,
          );
        },
      );

      setState(() {
        _departamentoSeleccionado = deptoEncontrado;
      });
    }
  }

  @override
  void dispose() {
    // Limpiar controladores
    _nombresController.dispose();
    _apellidosController.dispose();
    _dniController.dispose();
    _cargoController.dispose();
    _areaController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  bool _puedeGestionarTrabajadores() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    return authProvider.tienePermiso('gestion_trabajadores');
  }

  Future<void> _guardarTrabajador() async {
    if (!_puedeGestionarTrabajadores()) {
      _mostrarError('No tiene permisos para gestionar trabajadores');
      return;
    }

    // Validar campos obligatorios
    if (!_validarCampos()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final trabajadorProvider = Provider.of<TrabajadorProvider>(
        context,
        listen: false,
      );

      // Crear objeto Trabajador
      final trabajador = Trabajador(
        id: widget.trabajador?.id ?? Trabajador.generarId(),
        nombres: _nombresController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        dni: _dniController.text.trim(),
        cargo: _cargoController.text.trim(),
        departamentoId: _departamentoSeleccionado!.id,
        departamentoNombre: _departamentoSeleccionado!.nombre,
        area: _areaController.text.trim(),
        telefono: _telefonoController.text.trim().isNotEmpty
            ? _telefonoController.text.trim()
            : null,
        emailCorporativo: _emailController.text.trim().isNotEmpty
            ? _emailController.text.trim()
            : null,
        fechaIngreso: _fechaIngresoSeleccionada ?? DateTime.now(),
        activo: _isActive,
        fechaCreacion: widget.trabajador?.fechaCreacion ?? DateTime.now(),
        usuarioCreacion: widget.trabajador?.usuarioCreacion ?? 'admin',
        fotoUrl: widget.trabajador?.fotoUrl,
      );

      // Guardar en base de datos
      final bool exito;
      if (widget.trabajador == null) {
        // Modo creación
        exito = await trabajadorProvider.crearTrabajador(trabajador);
      } else {
        // Modo edición
        exito = await trabajadorProvider.actualizarTrabajador(trabajador);
      }

      if (exito && mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.trabajador == null
                  ? 'Trabajador creado exitosamente'
                  : 'Trabajador actualizado exitosamente',
            ),
            backgroundColor: Colors.green,
          ),
        );

        // Regresar con resultado exitoso
        Navigator.pop(context, true); // <-- IMPORTANTE: devolver true
      } else if (mounted) {
        // Mostrar error del provider
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(trabajadorProvider.error ?? 'Error desconocido'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  bool _validarCampos() {
    // Validar campos obligatorios
    if (_nombresController.text.trim().isEmpty) {
      _mostrarError('Por favor ingresa los nombres');
      return false;
    }

    if (_apellidosController.text.trim().isEmpty) {
      _mostrarError('Por favor ingresa los apellidos');
      return false;
    }

    if (_dniController.text.trim().isEmpty) {
      _mostrarError('Por favor ingresa el CI');
      return false;
    }

    if (_dniController.text.trim().length != 11) {
      _mostrarError('El CI debe tener 11 dígitos');
      return false;
    }

    if (_cargoController.text.trim().isEmpty) {
      _mostrarError('Por favor ingresa el cargo');
      return false;
    }

    if (_departamentoSeleccionado == null) {
      _mostrarError('Por favor selecciona un departamento');
      return false;
    }

    if (_areaController.text.trim().isEmpty) {
      _mostrarError('Por favor ingresa el área');
      return false;
    }

    if (_fechaIngresoSeleccionada == null) {
      _mostrarError('Por favor selecciona la fecha de ingreso');
      return false;
    }

    return true;
  }

  void _mostrarError(String mensaje) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(mensaje), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEdicion = widget.trabajador != null;
    final bool puedeGestionarTrabajadores = context.watch<AuthProvider>().tienePermiso(
      'gestion_trabajadores',
    );

    if (!puedeGestionarTrabajadores) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trabajadores')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock_outline, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'No tiene permisos para gestionar trabajadores',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // Consumir el DepartamentoProvider
    final deptoProvider = Provider.of<DepartamentoProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          isEdicion ? 'Editar Trabajador' : 'Nuevo Trabajador',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: isDark
            ? const Color(0xFF101922)
            : AppTheme.backgroundColorLight,
        elevation: 0,
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title Section
                    Stack(
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isEdicion
                                  ? 'Editar Registro'
                                  : 'Registro Detallado',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isEdicion
                                  ? 'Actualiza la información del trabajador.'
                                  : 'Complete todos los campos para el control de activos TI.',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 32),

                    // Form
                    Form(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Información Identitaria
                          _buildSectionTitle('Información Identitaria'),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: _buildTextField(
                                  hintText: 'Nombres',
                                  controller: _nombresController,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildTextField(
                                  hintText: 'Apellidos',
                                  controller: _apellidosController,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'CI (Carnet de Identidad)',
                            controller: _dniController,
                            prefixIcon: Icons.fingerprint,
                            keyboardType: TextInputType.number,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(11),
                            ],
                          ),

                          const SizedBox(height: 24),

                          // Estructura Organizacional
                          _buildSectionTitle('Estructura Organizacional'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Cargo',
                            controller: _cargoController,
                            prefixIcon: Icons.badge,
                          ),
                          const SizedBox(height: 12),

                          // Dropdown de Departamentos desde la BD
                          deptoProvider.cargando
                              ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(
                                      color: AppTheme.primaryColor,
                                    ),
                                  ),
                                )
                              : _buildDropdownDepartamentos(
                                  deptoProvider.departamentos,
                                ),

                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Área',
                            controller: _areaController,
                            prefixIcon: Icons.domain,
                          ),

                          const SizedBox(height: 24),

                          // Contacto y Registro
                          _buildSectionTitle('Contacto y Registro'),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Teléfono',
                            controller: _telefonoController,
                            prefixIcon: Icons.smartphone,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 12),
                          _buildTextField(
                            hintText: 'Email Corporativo',
                            controller: _emailController,
                            prefixIcon: Icons.alternate_email,
                            keyboardType: TextInputType.emailAddress,
                          ),
                          const SizedBox(height: 12),
                          _buildDatePickerField(),

                          const SizedBox(height: 24),

                          // Configuración del Sistema
                          _buildSectionTitle('Configuración del Sistema'),
                          const SizedBox(height: 12),
                          Container(
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF1C2630)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF2D3A48)
                                    : Colors.grey[300]!,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                // Estado del Trabajador
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.how_to_reg,
                                          color: Colors.grey[400],
                                        ),
                                        const SizedBox(width: 12),
                                        const Text(
                                          'Estado del Trabajador',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Switch(
                                          value: _isActive,
                                          activeThumbColor: const Color(
                                            0xFF2B8CEE,
                                          ),
                                          onChanged: (value) {
                                            setState(() {
                                              _isActive = value;
                                            });
                                          },
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          _isActive ? 'ACTIVO' : 'INACTIVO',
                                          style: const TextStyle(
                                            fontSize: 5,
                                            fontWeight: FontWeight.w600,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),

                                const Divider(height: 24, color: Colors.grey),

                                // Información del sistema (solo lectura)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'INFORMACIÓN DEL SISTEMA',
                                      style: TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.grey[500],
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Container(
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? const Color(
                                                0xFF101922,
                                              ).withValues(alpha: 0.5)
                                            : const Color(0xFFF9FAFB),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isDark
                                              ? const Color(0xFF2D3A48)
                                              : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: TextField(
                                        controller: TextEditingController(
                                          text:
                                              widget.trabajador?.id ??
                                              'Generado al guardar',
                                        ),
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: isDark
                                              ? Colors.grey[300]
                                              : Colors.grey[700],
                                        ),
                                        decoration: InputDecoration(
                                          prefixIcon: Icon(
                                            Icons.info_outline,
                                            color: Colors.grey[400],
                                            size: 20,
                                          ),
                                          border: InputBorder.none,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: 12,
                                                vertical: 12,
                                              ),
                                          hintText: 'ID del Trabajador',
                                          hintStyle: TextStyle(
                                            color: Colors.grey[500],
                                            fontSize: 14,
                                          ),
                                        ),
                                        enabled: false,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),

      // Bottom Save Button
      bottomSheet: Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.95),
          border: Border(
            top: BorderSide(color: Theme.of(context).dividerColor),
          ),
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _guardarTrabajador,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryColor,
                foregroundColor: Colors.white,
                elevation: 8,
                shadowColor: AppTheme.primaryColor.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                minimumSize: const Size(double.infinity, 56),
              ),
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          isEdicion
                              ? 'Actualizar Registro'
                              : 'Guardar Registro',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(isEdicion ? Icons.update : Icons.save, size: 24),
                      ],
                    ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        color: Colors.grey[500],
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildTextField({
    required String hintText,
    required TextEditingController controller,
    IconData? prefixIcon,
    TextInputType? keyboardType,
    List<TextInputFormatter>? inputFormatters,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      style: TextStyle(
        fontSize: 14,
        color: isDark ? Colors.grey[300] : Colors.grey[800],
      ),
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2630) : Colors.white,
        hintText: hintText,
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[600] : Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, color: Colors.grey[400])
            : null,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D3A48) : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D3A48) : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }

  Widget _buildDropdownDepartamentos(List<Departamento> departamentos) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DropdownButtonFormField<String>(
      // Cambiar a String en lugar de Departamento
      initialValue: _departamentoSeleccionado?.id, // Usar el ID como valor
      decoration: InputDecoration(
        filled: true,
        fillColor: isDark ? const Color(0xFF1C2630) : Colors.white,
        hintText: 'Seleccionar Departamento',
        hintStyle: TextStyle(
          color: isDark ? Colors.grey[600] : Colors.grey[400],
          fontSize: 14,
        ),
        prefixIcon: Icon(Icons.account_tree, color: Colors.grey[400]),
        suffixIcon: Icon(Icons.expand_more, color: Colors.grey[400]),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D3A48) : Colors.grey[300]!,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: isDark ? const Color(0xFF2D3A48) : Colors.grey[300]!,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.primaryColor, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      items: [
        ...departamentos.map((depto) {
          return DropdownMenuItem(
            value: depto.id, // Usar el ID como valor
            child: Text(
              depto.nombre,
              style: TextStyle(
                color: isDark ? Colors.grey[300] : Colors.grey[800],
              ),
            ),
          );
        }),
      ],
      onChanged: (String? deptoId) {
        if (deptoId != null) {
          // Buscar el departamento completo por su ID
          final deptoSeleccionado = departamentos.firstWhere(
            (d) => d.id == deptoId,
            orElse: () => departamentos.first,
          );
          setState(() {
            _departamentoSeleccionado = deptoSeleccionado;
          });
        }
      },
      style: TextStyle(
        color: isDark ? Colors.grey[300] : Colors.grey[800],
        fontSize: 14,
      ),
      validator: (value) {
        if (value == null) {
          return 'Por favor selecciona un departamento';
        }
        return null;
      },
    );
  }

  Widget _buildDatePickerField() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bool isEdicion = widget.trabajador != null;

    return GestureDetector(
      onTap: isEdicion
          ? null
          : () async {
              final pickedDate = await showDatePicker(
                context: context,
                initialDate: _fechaIngresoSeleccionada ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime.now(),
                builder: (context, child) {
                  return Theme(
                    data: isDark ? ThemeData.dark() : ThemeData.light(),
                    child: child!,
                  );
                },
              );
              if (pickedDate != null) {
                setState(() {
                  _fechaIngresoSeleccionada = pickedDate;
                });
              }
            },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1C2630) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF2D3A48) : Colors.grey[300]!,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(
              Icons.calendar_today,
              color: isEdicion ? Colors.grey[500] : Colors.grey[400],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                _fechaIngresoSeleccionada != null
                    ? '${_fechaIngresoSeleccionada!.day}/${_fechaIngresoSeleccionada!.month}/${_fechaIngresoSeleccionada!.year}'
                    : 'Seleccionar Fecha de Ingreso',
                style: TextStyle(
                  fontSize: 14,
                  color: _fechaIngresoSeleccionada != null
                      ? (isDark ? Colors.grey[300] : Colors.grey[800])
                      : (isDark ? Colors.grey[600] : Colors.grey[400]),
                ),
              ),
            ),
            if (isEdicion)
              Icon(Icons.lock_outline, color: Colors.grey[500], size: 16),
          ],
        ),
      ),
    );
  }
}
