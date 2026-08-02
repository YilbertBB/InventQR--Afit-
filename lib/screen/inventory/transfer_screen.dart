import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/equipo.dart';
import '../../models/departamento.dart';
import '../../providers/departamento_provider.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/traslado_provider.dart';
import '../../providers/auth_provider.dart';
import '../../utils/permission_guard.dart';

class TransferScreen extends StatefulWidget {
  final String? equipoId;
  final String? equipoNombre;
  final String? departamentoActualId;
  final String? departamentoActualNombre;
  final String? destinoId; // ← NUEVO
  final String? destinoNombre;

  const TransferScreen({
    super.key,
    this.equipoId,
    this.equipoNombre,
    this.departamentoActualId,
    this.departamentoActualNombre,
    this.destinoId, // ← NUEVO
    this.destinoNombre,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  // Datos del equipo seleccionado
  Equipo? _equipoSeleccionado;
  bool _cargandoEquipo = false;

  // Departamentos
  List<Departamento> _departamentos = [];
  String? _selectedDestinoId;
  String? _selectedDestinoNombre;

  // Motivo
  final TextEditingController _reasonController = TextEditingController();

  // Estado
  bool _cargando = false;

  final List<String> suggestionTags = [
    'Mantenimiento',
    'Reasignación',
    'Baja Técnica',
    'Préstamo',
    'Actualización',
  ];

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_puedeTrasladar()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tiene permisos para trasladar equipos'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }

      _cargarDatosIniciales();
    });

    // ✅ 2. Si recibimos equipo por parámetro, cargarlo DESPUÉS del build
    if (widget.equipoId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _cargarEquipoPorId(widget.equipoId!);
      });
    }

    if (widget.destinoId != null && widget.destinoNombre != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setState(() {
          _selectedDestinoId = widget.destinoId;
          _selectedDestinoNombre = widget.destinoNombre;
        });
      });
    }
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  bool _puedeTrasladar() {
    final authProvider = context.read<AuthProvider>();
    return PermissionGuard.canAccess(authProvider.usuarioActual, 'trasladar');
  }

  Future<void> _cargarDatosIniciales() async {
    if (!mounted) return;

    try {
      final deptoProvider = Provider.of<DepartamentoProvider>(
        context,
        listen: false,
      );
      await deptoProvider.cargarDepartamentos();

      if (!mounted) return;

      setState(() {
        _departamentos = deptoProvider.departamentos
            .where((d) => d.id != widget.departamentoActualId)
            .toList();
      });
    } catch (e) {
      debugPrint('Error cargando departamentos: $e');
    }
  }

  Future<void> _cargarEquipoPorId(String equipoId) async {
    if (!mounted) return;

    setState(() => _cargandoEquipo = true);

    try {
      final equipoProvider = Provider.of<EquipoProvider>(
        context,
        listen: false,
      );
      final equipo = await equipoProvider.obtenerEquipoPorId(equipoId);

      if (mounted) {
        setState(() {
          _equipoSeleccionado = equipo;
          _cargandoEquipo = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _cargandoEquipo = false);
      }
      debugPrint('Error cargando equipo: $e');
    }
  }

  // Búsqueda de equipos
  Future<void> _buscarEquipo(String query) async {
    if (query.isEmpty) return;

    setState(() => _cargandoEquipo = true);

    try {
      final equipoProvider = Provider.of<EquipoProvider>(
        context,
        listen: false,
      );
      final resultados = await equipoProvider.buscarEquipos(query);

      if (resultados.isNotEmpty && mounted) {
        setState(() {
          _equipoSeleccionado = resultados.first;
          _cargandoEquipo = false;
        });
      } else {
        setState(() => _cargandoEquipo = false);
      }
    } catch (e) {
      setState(() => _cargandoEquipo = false);
    }
  }

  // Escáner QR (placeholder)
  Future<void> _escanearQR() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('📱 Escáner QR próximamente'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Confirmar traslado
  Future<void> _confirmTransfer() async {
    if (!_puedeTrasladar()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No tiene permisos para trasladar equipos'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    // Validaciones
    if (_equipoSeleccionado == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un activo'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_selectedDestinoId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor seleccione un departamento de destino'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    if (_reasonController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor ingrese un motivo del traslado'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // Mostrar diálogo de confirmación
    final screenContext = context;
    final motivoController = _reasonController;

    showDialog(
      context: screenContext,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Confirmar Traslado'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('¿Está seguro de realizar el traslado?'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _equipoSeleccionado!.nombre,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Código: ${_equipoSeleccionado!.codigoQR}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1),
                  const SizedBox(height: 8),
                  Text(
                    'Desde: ${widget.departamentoActualNombre ?? _equipoSeleccionado!.departamentoNombre ?? 'Sin departamento'}',
                    style: const TextStyle(fontSize: 13),
                  ),
                  Text(
                    'Hacia: $_selectedDestinoNombre',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Motivo: ${motivoController.text}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF135bec),
            ),
            onPressed: () async {
              final motivo = motivoController.text;

              // Cerrar diálogo
              Navigator.pop(dialogContext);

              // Ejecutar traslado
              if (screenContext.mounted) {
                setState(() => _cargando = true);

                try {
                  final trasladoProvider = Provider.of<TrasladoProvider>(
                    screenContext,
                    listen: false,
                  );

                  final success = await trasladoProvider.trasladarEquipo(
                    equipoId: _equipoSeleccionado!.id,
                    equipoNombre: _equipoSeleccionado!.nombre,
                    desdeDepartamentoId:
                        widget.departamentoActualId ??
                        _equipoSeleccionado!.departamentoId,
                    desdeDepartamentoNombre:
                        widget.departamentoActualNombre ??
                        _equipoSeleccionado!.departamentoNombre ??
                        'Sin departamento',
                    haciaDepartamentoId: _selectedDestinoId!,
                    haciaDepartamentoNombre: _selectedDestinoNombre!,
                    motivo: motivo,
                    observaciones: null,
                  );

                  if (success && screenContext.mounted) {
                    // Recargar equipos
                    await Provider.of<EquipoProvider>(
                      screenContext,
                      listen: false,
                    ).cargarEquipos();
                    if (!screenContext.mounted) return;

                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Traslado confirmado exitosamente'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    // Cerrar pantalla y notificar éxito
                    Navigator.pop(screenContext, true);
                  }
                } catch (e) {
                  if (screenContext.mounted) {
                    ScaffoldMessenger.of(screenContext).showSnackBar(
                      SnackBar(
                        content: Text('❌ Error: $e'),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                } finally {
                  if (screenContext.mounted) {
                    setState(() => _cargando = false);
                  }
                }
              }
            },
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFf6f6f8),
      appBar: AppBar(
        backgroundColor: const Color(0xFFf6f6f8),
        shape: Border(bottom: BorderSide(color: const Color(0xFFe2e8f0))),
        leading: IconButton(
          onPressed: () => Navigator.pop(context),
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.black,
            size: 24,
          ),
        ),
        title: const Text(
          'Traslado de Activos',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0f172a),
          ),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.history, size: 24, color: Color(0xFF334155)),
            onPressed: () {},
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 24),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Sección 1: Selección del Activo
                        _buildSectionTitle(
                          number: 1,
                          title: 'Selección del Activo',
                        ),
                        const SizedBox(height: 16),

                        // Barra de búsqueda (solo si no viene por parámetro)
                        if (widget.equipoId == null) ...[
                          _buildSearchBar(),
                          const SizedBox(height: 12),
                          _buildQrButton(),
                          const SizedBox(height: 16),
                        ],

                        // Vista previa del activo
                        _buildAssetPreview(),
                        const SizedBox(height: 32),

                        // Sección 2: Ubicación
                        _buildSectionTitle(
                          number: 2,
                          title: 'Ubicación de Destino',
                        ),
                        const SizedBox(height: 16),
                        _buildLocationSection(),
                        const SizedBox(height: 32),

                        // Sección 3: Detalles
                        _buildSectionTitle(
                          number: 3,
                          title: 'Detalles del Traslado',
                        ),
                        const SizedBox(height: 16),
                        _buildDetailsSection(),
                        const SizedBox(height: 120),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle({required int number, required String title}) {
    return Row(
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: const Color(0xFF135bec).withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Center(
            child: Text(
              number.toString(),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: Color(0xFF135bec),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0f172a),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 52,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Row(
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 16),
            child: Icon(Icons.search, color: Color(0xFF94a3b8), size: 24),
          ),
          Expanded(
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Buscar por ID o nombre...',
                hintStyle: TextStyle(color: Color(0xFF64748b), fontSize: 14),
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 16,
                ),
              ),
              style: const TextStyle(color: Color(0xFF0f172a), fontSize: 14),
              onSubmitted: _buscarEquipo,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQrButton() {
    return Container(
      height: 52,
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF135bec).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFF135bec).withValues(alpha: 0.2),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: _escanearQR,
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.qr_code_scanner, color: Color(0xFF135bec), size: 24),
              SizedBox(width: 8),
              Text(
                'Escanear Código QR',
                style: TextStyle(
                  color: Color(0xFF135bec),
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetPreview() {
    if (_cargandoEquipo) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe2e8f0)),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF135bec)),
          ),
        ),
      );
    }

    if (_equipoSeleccionado == null) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFe2e8f0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.inventory_2_outlined, color: Color(0xFF94a3b8)),
            SizedBox(width: 12),
            Text(
              'Ningún activo seleccionado',
              style: TextStyle(color: Color(0xFF64748b), fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFe2e8f0)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFf1f5f9),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Icon(
                _getIconForType(_equipoSeleccionado!.tipo),
                size: 32,
                color: const Color(0xFF64748b),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Activo Seleccionado',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748b),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _equipoSeleccionado!.nombre,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0f172a),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  'Código: ${_equipoSeleccionado!.codigoQR}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF94a3b8),
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Colors.green, size: 24),
        ],
      ),
    );
  }

  Widget _buildLocationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Origen
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Departamento de Origen',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748b),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 52,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFf8fafc),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.business_center,
                    size: 20,
                    color: Color(0xFF94a3b8),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.departamentoActualNombre ??
                        _equipoSeleccionado?.departamentoNombre ??
                        'Sin departamento',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Destino
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Departamento de Destino',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748b),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              height: 52,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFe2e8f0)),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  dropdownColor: Colors.white,
                  value: _selectedDestinoId,
                  isExpanded: true,
                  icon: const Padding(
                    padding: EdgeInsets.only(right: 16),
                    child: Icon(Icons.expand_more, color: Color(0xFF94a3b8)),
                  ),
                  hint: const Padding(
                    padding: EdgeInsets.only(left: 16),
                    child: Text(
                      'Seleccione departamento...',
                      style: TextStyle(fontSize: 14, color: Color(0xFF94a3b8)),
                    ),
                  ),
                  items: _departamentos.map((depto) {
                    return DropdownMenuItem<String>(
                      value: depto.id,
                      child: Padding(
                        padding: const EdgeInsets.only(left: 16),
                        child: Text(
                          depto.nombre,
                          style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFF0f172a),
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                  onChanged: _equipoSeleccionado == null
                      ? null
                      : (value) {
                          final depto = _departamentos.firstWhere(
                            (d) => d.id == value,
                            orElse: () => Departamento(id: '', nombre: ''),
                          );
                          setState(() {
                            _selectedDestinoId = value;
                            _selectedDestinoNombre = depto.nombre;
                          });
                        },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDetailsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Motivo del Traslado',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF64748b),
              ),
            ),
            const SizedBox(height: 4),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFe2e8f0)),
              ),
              child: TextField(
                controller: _reasonController,
                maxLines: 4,
                decoration: InputDecoration(
                  filled: true,
                  fillColor: Colors.white,
                  hintText:
                      'Ej. Reasignación por nuevo ingreso, mantenimiento preventivo...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94a3b8),
                    fontSize: 14,
                  ),
                  contentPadding: const EdgeInsets.all(16),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFFe2e8f0),
                      width: 1.0,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                      color: Color(0xFF135bec),
                      width: 2.0,
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Color(0xFFe2e8f0)),
                  ),
                ),
                style: const TextStyle(fontSize: 14, color: Color(0xFF0f172a)),
              ),
            ),
          ],
        ),

        const SizedBox(height: 12),

        // Etiquetas de sugerencia
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: suggestionTags.map((tag) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  _reasonController.text = tag;
                });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFf8fafc),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFe2e8f0)),
                ),
                child: Text(
                  tag,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF475569),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildBottomButton() {
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFFf6f6f8),
          border: Border(top: BorderSide(color: Color(0xFFe2e8f0))),
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: SizedBox(
                height: 56,
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _cargando ? null : _confirmTransfer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF135bec),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFF135bec).withValues(alpha: 0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Confirmar Traslado',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(width: 8),
                            Icon(Icons.send, size: 20),
                          ],
                        ),
                ),
              ),
            ),
            Container(
              height: 6,
              width: 134,
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFcbd5e1).withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getIconForType(String tipo) {
    switch (tipo.toLowerCase()) {
      case 'computadora':
        return Icons.computer;
      case 'silla':
        return Icons.chair;
      case 'mesa':
        return Icons.table_chart;
      case 'teclado':
        return Icons.keyboard;
      case 'monitor':
        return Icons.monitor;
      case 'mouse':
        return Icons.mouse;
      default:
        return Icons.devices_other;
    }
  }
}
