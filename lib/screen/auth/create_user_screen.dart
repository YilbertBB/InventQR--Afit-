import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';

import '../../core/app_routes.dart';
import '../../database/database_helper.dart';
import '../../models/usuario.dart';
import '../../models/departamento.dart';
import '../../providers/auth_provider.dart';

class CreateEditUserScreen extends StatefulWidget {
  final Usuario? usuarioAEditar;
  final bool esModoEdicion;

  const CreateEditUserScreen({
    super.key,
    this.usuarioAEditar,
    this.esModoEdicion = false,
  });

  @override
  State<CreateEditUserScreen> createState() => _CreateEditUserScreenState();
}

class _CreateEditUserScreenState extends State<CreateEditUserScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();

  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  String _selectedRole = 'empleado';
  String? _selectedDepartment;
  bool _isLoading = false;
  bool _usuarioActivo = true;

  // Lista de departamentos obtenida de la BD
  List<Departamento> _departamentos = [];
  bool _cargandoDepartamentos = true;

  // Lista de roles disponibles
  final List<String> _rolesDisponibles = [
    'admin',
    'supervisor',
    'auditor',
    'empleado',
  ];

  @override
  void initState() {
    super.initState();

    // Cargar departamentos de la base de datos
    _cargarDepartamentos();

    // Si estamos en modo edición, cargar datos del usuario
    if (widget.esModoEdicion && widget.usuarioAEditar != null) {
      _cargarDatosUsuario();
    }
  }

  Future<void> _cargarDepartamentos() async {
    try {
      setState(() {
        _cargandoDepartamentos = true;
      });

      final db = await _dbHelper.database;
      final resultados = await db.query('departamentos', orderBy: 'nombre ASC');

      final lista = resultados.map((map) => Departamento.fromMap(map)).toList();

      setState(() {
        _departamentos = lista;
        _cargandoDepartamentos = false;

        // Seleccionar el primer departamento por defecto si no hay selección
        if (_selectedDepartment == null && lista.isNotEmpty) {
          _selectedDepartment = lista.first.nombre;
        }

        // Si estamos en modo edición y el usuario ya tenía un departamento,
        // verificar si sigue existiendo
        if (widget.esModoEdicion &&
            widget.usuarioAEditar != null &&
            widget.usuarioAEditar!.departamento != null) {
          final departamentoExistente = lista.firstWhere(
            (depto) => depto.nombre == widget.usuarioAEditar!.departamento,
            orElse: () => lista.isNotEmpty
                ? lista.first
                : Departamento(id: '', nombre: 'Sin departamento'),
          );

          _selectedDepartment = departamentoExistente.nombre;
        }
      });
    } catch (e) {
      setState(() {
        _cargandoDepartamentos = false;
        _departamentos = [];
      });
    }
  }

  void _cargarDatosUsuario() {
    final usuario = widget.usuarioAEditar!;

    _nameController.text = usuario.nombreCompleto;
    _emailController.text = usuario.email;
    _usernameController.text = usuario.username;
    _phoneController.text = usuario.telefono;
    _selectedRole = usuario.rol;
    _selectedDepartment = usuario.departamento;
    _usuarioActivo = usuario.activo;

    // En modo edición, los campos de contraseña están vacíos por defecto
    // El usuario solo debe llenarlos si quiere cambiar la contraseña
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final usuarioActual = authProvider.usuarioActual;

    // Verificar permisos
    final puedeGestionarUsuarios =
        usuarioActual?.tienePermiso('gestion_usuarios') ?? false;

    // En modo edición, verificar que no se esté editando a sí mismo (a menos que sea admin)
    final estaEditandoseASiMismo =
        widget.esModoEdicion && widget.usuarioAEditar?.id == usuarioActual?.id;

    // Si no tiene permisos y no se está editando a sí mismo, redirigir
    if (!puedeGestionarUsuarios &&
        !estaEditandoseASiMismo &&
        usuarioActual != null) {
      Future.microtask(() {
        if (!context.mounted) return;

        AppRoutes.goBack(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tiene permisos para gestionar usuarios'),
          ),
        );
      });
    }

    final titulo = widget.esModoEdicion
        ? 'Editar Usuario'
        : 'Crear Nuevo Usuario';
    final textoBoton = widget.esModoEdicion
        ? 'Actualizar Usuario'
        : 'Registrar Usuario';

    return Scaffold(
      backgroundColor: const Color(0xFFf6f7f8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf6f7f8),
        shape: const Border(bottom: BorderSide(color: Color(0xFFe5e7eb))),
        title: Text(
          titulo,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF1f2937),
            letterSpacing: -0.015,
          ),
        ),
        centerTitle: true,
        leading: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () => AppRoutes.goBack(context),
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
            icon: const Icon(
              Icons.arrow_back_ios_new,
              color: Colors.black,
              size: 24,
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Headline Section
                  _buildHeadlineSection(widget.esModoEdicion),

                  // Información importante
                  if (!widget.esModoEdicion && usuarioActual?.rol == 'admin')
                    _buildAdminInfoSection(),

                  // Form Section
                  _buildFormSection(),

                  // Role Selector Section
                  if (puedeGestionarUsuarios || estaEditandoseASiMismo)
                    _buildRoleSelectorSection(),

                  // Department Selector (solo si hay departamentos)
                  if (puedeGestionarUsuarios) _buildDepartmentSelector(),

                  // Estado del usuario (solo para admin en modo edición)
                  if (widget.esModoEdicion &&
                      puedeGestionarUsuarios &&
                      !estaEditandoseASiMismo)
                    _buildEstadoUsuario(),

                  // Action Buttons Section
                  _buildActionButtonsSection(
                    authProvider,
                    textoBoton,
                    widget.esModoEdicion,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),

            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: const Center(child: CircularProgressIndicator()),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeadlineSection(bool esModoEdicion) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            esModoEdicion ? 'Editar Cuenta' : 'Nueva Cuenta',
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1f2937),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            esModoEdicion
                ? 'Actualice la información del usuario seleccionado.'
                : 'Complete los datos para registrar un nuevo perfil en el sistema.',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF6b7280),
              height: 1.5,
            ),
          ),

          // Mostrar información del usuario en modo edición
          if (esModoEdicion && widget.usuarioAEditar != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFF2b8cee).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2b8cee).withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Usuario actual:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        color: Color(0xFF6b7280),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${widget.usuarioAEditar!.id.substring(0, 8)}...',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6b7280),
                      ),
                    ),
                    Text(
                      'Creado: ${_formatearFecha(widget.usuarioAEditar!.fechaCreacion)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF6b7280),
                      ),
                    ),
                    if (widget.usuarioAEditar!.fechaUltimoLogin != null)
                      Text(
                        'Último acceso: ${_formatearFecha(widget.usuarioAEditar!.fechaUltimoLogin!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6b7280),
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAdminInfoSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF2b8cee).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF2b8cee).withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: Color(0xFF2b8cee), size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Nota Importante:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1f2937),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Al crear el primer usuario administrador, el usuario "root" será eliminado automáticamente por seguridad.',
                  style: TextStyle(
                    color: Colors.grey[700],
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormSection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuarioActual = authProvider.usuarioActual;
    final puedeGestionarUsuarios =
        usuarioActual?.tienePermiso('gestion_usuarios') ?? false;
    final estaEditandoseASiMismo =
        widget.esModoEdicion && widget.usuarioAEditar?.id == usuarioActual?.id;

    return Column(
      children: [
        // Nombre Completo
        _buildTextField(
          label: 'Nombre Completo',
          hintText: 'Ej. Juan Pérez',
          controller: _nameController,
          icon: Icons.person,
          keyboardType: TextInputType.name,
          enabled:
              !widget.esModoEdicion ||
              puedeGestionarUsuarios ||
              estaEditandoseASiMismo,
        ),

        // Nombre de usuario
        _buildTextField(
          label: 'Nombre de Usuario',
          hintText: 'jperez',
          controller: _usernameController,
          icon: Icons.person_outline,
          keyboardType: TextInputType.text,
          enabled: !widget.esModoEdicion || puedeGestionarUsuarios,
        ),

        // Correo Electrónico
        _buildTextField(
          label: 'Correo Electrónico',
          hintText: 'usuario@empresa.com',
          controller: _emailController,
          icon: Icons.mail,
          keyboardType: TextInputType.emailAddress,
          enabled:
              !widget.esModoEdicion ||
              puedeGestionarUsuarios ||
              estaEditandoseASiMismo,
        ),

        // Teléfono
        _buildTextField(
          label: 'Teléfono',
          hintText: '+51 999 999 999',
          controller: _phoneController,
          icon: Icons.phone,
          keyboardType: TextInputType.phone,
          enabled:
              !widget.esModoEdicion ||
              puedeGestionarUsuarios ||
              estaEditandoseASiMismo,
        ),

        // Contraseña (solo para creación o cambio explícito)
        if (!widget.esModoEdicion || _passwordController.text.isNotEmpty)
          _buildPasswordField(
            label: widget.esModoEdicion
                ? 'Nueva Contraseña (dejar en blanco para mantener)'
                : 'Contraseña',
            hintText: '••••••••',
            controller: _passwordController,
            obscureText: _obscurePassword,
            onToggleVisibility: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            enabled:
                !widget.esModoEdicion ||
                puedeGestionarUsuarios ||
                estaEditandoseASiMismo,
          ),

        // Confirmar Contraseña (solo si se está cambiando)
        if (!widget.esModoEdicion || _passwordController.text.isNotEmpty)
          _buildPasswordField(
            label: widget.esModoEdicion
                ? 'Confirmar Nueva Contraseña'
                : 'Confirmar Contraseña',
            hintText: '••••••••',
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            onToggleVisibility: () {
              setState(() {
                _obscureConfirmPassword = !_obscureConfirmPassword;
              });
            },
            enabled:
                !widget.esModoEdicion ||
                puedeGestionarUsuarios ||
                estaEditandoseASiMismo,
          ),
      ],
    );
  }

  Widget _buildTextField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    bool obscureText = false,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: enabled ? const Color(0xFF374151) : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled
                    ? const Color.fromRGBO(59, 71, 84, 1)
                    : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    keyboardType: keyboardType,
                    enabled: enabled,
                    style: TextStyle(
                      fontSize: 16,
                      color: enabled
                          ? const Color(0xFF1f2937)
                          : Colors.grey[400],
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: enabled
                            ? const Color(0xFF9ca3af)
                            : Colors.grey[400],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 56,
                  decoration: BoxDecoration(
                    color: enabled ? Colors.white : Colors.grey[100],
                    border: Border(
                      left: BorderSide(
                        color: enabled
                            ? const Color(0xFF3b4754)
                            : Colors.grey[300]!,
                      ),
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      icon,
                      color: enabled
                          ? const Color(0xFF6b7280)
                          : Colors.grey[400],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPasswordField({
    required String label,
    required String hintText,
    required TextEditingController controller,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: enabled ? const Color(0xFF374151) : Colors.grey[400],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: enabled ? Colors.white : Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: enabled ? const Color(0xFF3b4754) : Colors.grey[300]!,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    obscureText: obscureText,
                    enabled: enabled,
                    style: TextStyle(
                      fontSize: 16,
                      color: enabled
                          ? const Color(0xFF1f2937)
                          : Colors.grey[400],
                    ),
                    decoration: InputDecoration(
                      hintText: hintText,
                      hintStyle: TextStyle(
                        color: enabled
                            ? const Color(0xFF9ca3af)
                            : Colors.grey[400],
                        fontSize: 16,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: enabled ? onToggleVisibility : null,
                  child: Container(
                    width: 56,
                    decoration: BoxDecoration(
                      color: enabled ? Colors.white : Colors.grey[100],
                      border: Border(
                        left: BorderSide(
                          color: enabled
                              ? const Color(0xFF3b4754)
                              : Colors.grey[300]!,
                        ),
                      ),
                    ),
                    child: Center(
                      child: Icon(
                        obscureText ? Icons.visibility : Icons.visibility_off,
                        color: enabled
                            ? const Color(0xFF6b7280)
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSelectorSection() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuarioActual = authProvider.usuarioActual;
    final estaEditandoseASiMismo =
        widget.esModoEdicion && widget.usuarioAEditar?.id == usuarioActual?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Rol del Usuario',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 16),
          Column(
            children: _rolesDisponibles.map((role) {
              final estaSeleccionado = _selectedRole == role;
              return _buildRoleOption(
                title: _getRoleName(role),
                description: _getRoleDescription(role),
                isSelected: estaSeleccionado,
                onTap: () {
                  if (!widget.esModoEdicion || !estaEditandoseASiMismo) {
                    setState(() {
                      _selectedRole = role;
                    });
                  }
                },
                enabled: !widget.esModoEdicion || !estaEditandoseASiMismo,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleOption({
    required String title,
    required String description,
    required bool isSelected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled ? onTap : null,
          child: Container(
            decoration: BoxDecoration(
              color: isSelected
                  ? const Color(0xFF2b8cee).withValues(alpha: 0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected
                    ? const Color(0xFF2b8cee)
                    : const Color(0xFF3b4754),
                width: isSelected ? 2 : 1,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: enabled
                                  ? const Color(0xFF1f2937)
                                  : Colors.grey[400],
                            ),
                          ),
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF2b8cee)
                                    : const Color(0xFF9ca3af),
                                width: 2,
                              ),
                            ),
                            child: isSelected
                                ? Center(
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF2b8cee),
                                      ),
                                    ),
                                  )
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 14,
                          color: enabled
                              ? const Color(0xFF6b7280)
                              : Colors.grey[400],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentSelector() {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuarioActual = authProvider.usuarioActual;
    final estaEditandoseASiMismo =
        widget.esModoEdicion && widget.usuarioAEditar?.id == usuarioActual?.id;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Departamento',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF374151),
                ),
              ),
              if (_cargandoDepartamentos)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (_cargandoDepartamentos)
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(child: Text('Cargando departamentos...')),
            )
          else if (_departamentos.isEmpty)
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: const Center(
                child: Text('No hay departamentos registrados'),
              ),
            )
          else
            Container(
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3b4754)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedDepartment,
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(
                      Icons.arrow_drop_down,
                      color: Color(0xFF6b7280),
                    ),
                  ),
                  isExpanded: true,
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1f2937),
                  ),
                  onChanged: (widget.esModoEdicion && estaEditandoseASiMismo)
                      ? null
                      : (String? newValue) {
                          setState(() {
                            _selectedDepartment = newValue;
                          });
                        },
                  items: _departamentos.map<DropdownMenuItem<String>>((
                    Departamento depto,
                  ) {
                    return DropdownMenuItem<String>(
                      value: depto.nombre,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              depto.nombre,
                              style: const TextStyle(fontSize: 16),
                            ),
                            if (depto.cantidadPersonal > 0 ||
                                depto.cantidadEquiposAsignados > 0)
                              Text(
                                '${depto.cantidadPersonal} pers., ${depto.cantidadEquiposAsignados} eq.',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6b7280),
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
        ],
      ),
    );
  }

  Widget _buildEstadoUsuario() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Estado del Usuario',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF374151),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _usuarioActivo = true),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _usuarioActivo
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        bottomLeft: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: _usuarioActivo
                            ? Colors.green
                            : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle,
                          color: _usuarioActivo
                              ? Colors.green
                              : Colors.grey[400],
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Activo',
                          style: TextStyle(
                            color: _usuarioActivo
                                ? Colors.green
                                : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _usuarioActivo = false),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: !_usuarioActivo
                          ? Colors.red.withValues(alpha: 0.1)
                          : Colors.grey[100],
                      borderRadius: const BorderRadius.only(
                        topRight: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                      border: Border.all(
                        color: !_usuarioActivo ? Colors.red : Colors.grey[300]!,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.block,
                          color: !_usuarioActivo
                              ? Colors.red
                              : Colors.grey[400],
                          size: 24,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Inactivo',
                          style: TextStyle(
                            color: !_usuarioActivo
                                ? Colors.red
                                : Colors.grey[400],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtonsSection(
    AuthProvider authProvider,
    String textoBoton,
    bool esModoEdicion,
  ) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuarioActual = authProvider.usuarioActual;
    final puedeGestionarUsuarios =
        usuarioActual?.tienePermiso('gestion_usuarios') ?? false;
    final estaEditandoseASiMismo =
        widget.esModoEdicion && widget.usuarioAEditar?.id == usuarioActual?.id;

    // Solo mostrar botón de eliminar si es modo edición, tiene permisos y no se está editando a sí mismo
    final mostrarBotonEliminar =
        esModoEdicion && puedeGestionarUsuarios && !estaEditandoseASiMismo;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      child: Column(
        children: [
          Container(
            height: 56,
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFF2b8cee),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2b8cee).withValues(alpha: 0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _isLoading
                    ? null
                    : () => esModoEdicion
                          ? _actualizarUsuario(context, authProvider)
                          : _crearUsuario(context, authProvider),
                child: Center(
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          textoBoton,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          if (mostrarBotonEliminar)
            Container(
              height: 56,
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: _isLoading
                      ? null
                      : () => _eliminarUsuario(context, authProvider),
                  child: Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.delete, color: Colors.red, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          'Eliminar Usuario',
                          style: TextStyle(
                            color: Colors.red,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _crearUsuario(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    // Validaciones
    if (_nameController.text.isEmpty) {
      _showSnackBar('Por favor ingrese el nombre completo');
      return;
    }

    if (_emailController.text.isEmpty) {
      _showSnackBar('Por favor ingrese el correo electrónico');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showSnackBar('Por favor ingrese un correo electrónico válido');
      return;
    }

    if (_usernameController.text.isEmpty) {
      _showSnackBar('Por favor ingrese el nombre de usuario');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showSnackBar('Por favor ingrese una contraseña');
      return;
    }

    if (_passwordController.text.length < 6) {
      _showSnackBar('La contraseña debe tener al menos 6 caracteres');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showSnackBar('Las contraseñas no coinciden');
      return;
    }

    // Verificar que haya departamentos
    if (_departamentos.isEmpty) {
      _showSnackBar(
        'No hay departamentos registrados. Cree al menos uno primero.',
      );
      return;
    }

    final esRoot = authProvider.usuarioActual?.username == 'root';
    if (esRoot && _selectedRole != 'admin') {
      _showSnackBar('El usuario root solo puede crear administradores');
      return;
    }
    // Crear objeto Usuario
    final nuevoUsuario = Usuario(
      id: const Uuid().v4(),
      username: _usernameController.text,
      passwordHash: _passwordController.text, // En producción usar hash
      nombreCompleto: _nameController.text,
      email: _emailController.text,
      rol: _selectedRole,
      departamento: _selectedDepartment,
      telefono: _phoneController.text,
      activo: true,
      fechaCreacion: DateTime.now(),
    );

    // Mostrar diálogo de confirmación
    final confirm = await _mostrarDialogoConfirmacion(
      '¿Está seguro de crear el siguiente usuario?',
      nuevoUsuario,
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final creadoExitosamente = await authProvider.crearUsuarioConVerificacion(
        nuevoUsuario,
      );

      if (creadoExitosamente) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario creado exitosamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Navegar hacia atrás
        await Future.delayed(const Duration(milliseconds: 500));
        final usuarioActual = authProvider.usuarioActual;
        if (usuarioActual == null) {
          if (context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            AppRoutes.goToLogin(context);

            // Mostrar mensaje informativo
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Usuario root eliminado por seguridad. Inicie sesión con el nuevo administrador.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 4),
              ),
            );
          }
        } else {
          if (!context.mounted) return;

          AppRoutes.goBack(context);
        }

        // Si el usuario creado es admin, mostrar advertencia sobre root
        if (_selectedRole == 'admin') {
          _mostrarAdvertenciaRoot();
        }
      } else {
        _showSnackBar(authProvider.errorMensaje ?? 'Error al crear usuario');
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _actualizarUsuario(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    if (widget.usuarioAEditar == null) return;

    // Validaciones básicas
    if (_nameController.text.isEmpty) {
      _showSnackBar('Por favor ingrese el nombre completo');
      return;
    }

    if (_emailController.text.isEmpty) {
      _showSnackBar('Por favor ingrese el correo electrónico');
      return;
    }

    if (!_emailController.text.contains('@')) {
      _showSnackBar('Por favor ingrese un correo electrónico válido');
      return;
    }

    if (_usernameController.text.isEmpty) {
      _showSnackBar('Por favor ingrese el nombre de usuario');
      return;
    }

    // Validar contraseña solo si se está cambiando
    if (_passwordController.text.isNotEmpty) {
      if (_passwordController.text.length < 6) {
        _showSnackBar('La nueva contraseña debe tener al menos 6 caracteres');
        return;
      }

      if (_passwordController.text != _confirmPasswordController.text) {
        _showSnackBar('Las contraseñas no coinciden');
        return;
      }
    }

    // Verificar que haya departamentos
    if (_departamentos.isEmpty) {
      _showSnackBar(
        'No hay departamentos registrados. Cree al menos uno primero.',
      );
      return;
    }

    // Crear objeto Usuario actualizado
    final usuarioActualizado = widget.usuarioAEditar!.copyWith(
      username: _usernameController.text,
      passwordHash: _passwordController.text.isNotEmpty
          ? _passwordController.text
          : widget.usuarioAEditar!.passwordHash,
      nombreCompleto: _nameController.text,
      email: _emailController.text,
      rol: _selectedRole,
      departamento: _selectedDepartment,
      telefono: _phoneController.text,
      activo: _usuarioActivo,
    );

    // Mostrar diálogo de confirmación
    final confirm = await _mostrarDialogoConfirmacion(
      '¿Está seguro de actualizar este usuario?',
      usuarioActualizado,
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      final actualizadoExitosamente = await authProvider.actualizarPerfil(
        usuarioActualizado,
      );

      if (actualizadoExitosamente) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Usuario actualizado exitosamente'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 2),
            ),
          );
        }

        // Mostrar mensaje de éxito

        // Navegar hacia atrás
        await Future.delayed(const Duration(milliseconds: 500));
        if (context.mounted) {
          AppRoutes.goBack(context);
        }
      } else {
        _showSnackBar(
          authProvider.errorMensaje ?? 'Error al actualizar usuario',
        );
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _eliminarUsuario(
    BuildContext context,
    AuthProvider authProvider,
  ) async {
    if (widget.usuarioAEditar == null) return;

    final usuario = widget.usuarioAEditar!;

    // Mostrar opciones de eliminación
    final opcionEliminar = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Eliminar Usuario'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Qué acción desea realizar con este usuario?'),
            const SizedBox(height: 16),
            Text('Nombre: ${usuario.nombreCompleto}'),
            Text('Correo: ${usuario.email}'),
            Text('Rol: ${_getRoleName(usuario.rol)}'),
            const SizedBox(height: 16),
            const Text(
              'Seleccione una opción:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 0),
            child: const Text('Cancelar'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context, 1),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.orange,
              side: const BorderSide(color: Colors.orange),
            ),
            child: const Text('Desactivar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, 2),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    // 0 = Cancelar, 1 = Desactivar, 2 = Eliminar
    if (opcionEliminar == null || opcionEliminar == 0) return;

    setState(() => _isLoading = true);

    try {
      bool operacionExitosa = false;
      String mensajeExito = '';
      String mensajeError = '';

      if (opcionEliminar == 1) {
        // Desactivar usuario
        operacionExitosa = await authProvider.desactivarUsuario(usuario.id);
        mensajeExito = 'Usuario desactivado exitosamente';
        mensajeError =
            authProvider.errorMensaje ?? 'Error al desactivar usuario';
      } else if (opcionEliminar == 2) {
        if (!context.mounted) return;
        final confirmacionDefinitiva = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.dangerous, color: Colors.red),
                SizedBox(width: 10),
                Text('Confirmación Final'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '¿Está completamente seguro de ELIMINAR PERMANENTEMENTE este usuario?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                Text('Nombre: ${usuario.nombreCompleto}'),
                Text('Correo: ${usuario.email}'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning, size: 16, color: Colors.red),
                          SizedBox(width: 8),
                          Text(
                            'ADVERTENCIA:',
                            style: TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Esta acción eliminará permanentemente todos los datos del usuario.',
                        style: TextStyle(fontSize: 12),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Esta acción NO se puede deshacer.',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
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
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ELIMINAR PERMANENTEMENTE'),
              ),
            ],
          ),
        );

        if (confirmacionDefinitiva != true) {
          setState(() => _isLoading = false);
          return;
        }

        operacionExitosa = await authProvider.eliminarUsuario(usuario.id);
        mensajeExito = 'Usuario eliminado permanentemente';
        mensajeError = authProvider.errorMensaje ?? 'Error al eliminar usuario';
      }

      if (operacionExitosa && context.mounted) {
        // Mostrar mensaje de éxito
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(mensajeExito),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 3),
          ),
        );

        // Navegar hacia atrás
        await Future.delayed(const Duration(milliseconds: 500));

        // Devuelve true para indicar que se eliminó/desactivó
        if (context.mounted) {
          Navigator.of(context).pop(true);
        }
      } else {
        _showSnackBar(mensajeError);
      }
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<bool?> _mostrarDialogoConfirmacion(
    String mensaje,
    Usuario usuario,
  ) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          widget.esModoEdicion
              ? 'Confirmar Actualización'
              : 'Confirmar Registro',
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(mensaje),
            const SizedBox(height: 12),
            Text('Nombre: ${usuario.nombreCompleto}'),
            Text('Correo: ${usuario.email}'),
            Text('Usuario: ${usuario.username}'),
            Text('Rol: ${_getRoleName(usuario.rol)}'),
            if (usuario.departamento != null)
              Text('Departamento: ${usuario.departamento}'),
            if (widget.esModoEdicion)
              Text('Estado: ${usuario.activo ? 'Activo' : 'Inactivo'}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancelar',
              style: TextStyle(color: Colors.black),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2b8cee),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: Text(widget.esModoEdicion ? 'Actualizar' : 'Registrar'),
          ),
        ],
      ),
    );
  }

  String _getRoleName(String role) {
    switch (role) {
      case 'admin':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'auditor':
        return 'Auditor';
      case 'empleado':
        return 'Empleado';
      default:
        return 'Empleado';
    }
  }

  String _getRoleDescription(String role) {
    switch (role) {
      case 'admin':
        return 'Acceso completo a todas las funciones del sistema.';
      case 'supervisor':
        return 'Gestionar equipos, traslados y exportar datos.';
      case 'auditor':
        return 'Realizar revisiones y generar reportes.';
      case 'empleado':
        return 'Solo lectura y escaneo de equipos.';
      default:
        return 'Usuario básico del sistema.';
    }
  }

  String _formatearFecha(DateTime fecha) {
    return DateFormat('dd/MM/yyyy HH:mm').format(fecha);
  }

  void _mostrarAdvertenciaRoot() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.security, color: Colors.orange),
            SizedBox(width: 10),
            Flexible(
              child: Text(
                'Usuario Root Eliminado',
                maxLines: 2,
                softWrap: true,
              ),
            ),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se ha creado el primer usuario administrador.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 10),
            Text(
              'Por motivos de seguridad, el usuario "root" ha sido eliminado automáticamente del sistema.',
            ),
            SizedBox(height: 10),
            Text(
              'Asegúrese de guardar las credenciales del nuevo usuario administrador.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Entendido'),
          ),
        ],
      ),
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2b8cee),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
