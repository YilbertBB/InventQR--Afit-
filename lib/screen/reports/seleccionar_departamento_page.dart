import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../providers/departamento_provider.dart';
import '../../providers/revision_provider.dart'; // Necesitaremos crearlo
import '../../models/departamento.dart';

class SeleccionarDepartamentoPage extends StatefulWidget {
  const SeleccionarDepartamentoPage({super.key});

  @override
  State<SeleccionarDepartamentoPage> createState() =>
      _SeleccionarDepartamentoPageState();
}

class _SeleccionarDepartamentoPageState
    extends State<SeleccionarDepartamentoPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // Cargar departamentos al iniciar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<DepartamentoProvider>().cargarDepartamentos();
    });
  }

  List<Departamento> get _departamentosFiltrados {
    final departamentos = context.watch<DepartamentoProvider>().departamentos;
    if (_searchQuery.isEmpty) return departamentos;
    return departamentos.where((dept) {
      return dept.nombre.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  Future<void> _iniciarRevision(
    BuildContext context,
    Departamento departamento,
  ) async {
    // Mostrar diálogo de confirmación
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Iniciar revisión física'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Departamento: ${departamento.nombre}'),
            const SizedBox(height: 8),
            Text(
              'Este departamento tiene ${departamento.cantidadEquiposAsignados} equipos registrados.',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            const Text(
              'Se registrarán los equipos que encuentres físicamente. '
              'Al finalizar podrás ver un reporte de faltantes y sobrantes.',
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('CANCELAR'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('INICIAR REVISIÓN'),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      // Iniciar la revisión usando el provider
      final revisionProvider = context.read<RevisionProvider>();
      final inicioExitoso = await revisionProvider.iniciarRevision(
        departamentoId: departamento.id,
        departamentoNombre: departamento.nombre,
      );

      if (inicioExitoso && context.mounted) {
        // Navegar a la vista de escaneo
        AppRoutes.goToProgresoReport(context);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              revisionProvider.error ?? 'Error al iniciar revisión',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final screenWidth = mediaQuery.size.width;
    final maxWidth = 480.0;
    final padding = screenWidth > maxWidth ? (screenWidth - maxWidth) / 2 : 0.0;
    final departamentoProvider = context.watch<DepartamentoProvider>();

    return Scaffold(
      appBar: AppBar(
        leading: Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: () {
              AppRoutes.goBack(context);
            },
            style: IconButton.styleFrom(
              backgroundColor: Colors.transparent,
              shape: const CircleBorder(),
            ),
            icon: Icon(Icons.arrow_back_ios_new, color: Colors.black, size: 24),
          ),
        ),
        title: Text(
          'Seleccionar Departamento',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFFf6f6f8),
      ),
      body: Container(
        color: const Color(0xFFf6f6f8),
        child: SafeArea(
          child: Container(
            margin: EdgeInsets.symmetric(horizontal: padding),
            constraints: BoxConstraints(maxWidth: maxWidth),
            child: Column(
              children: [
                // SearchBar
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(12),
                              bottomLeft: Radius.circular(12),
                            ),
                          ),
                          child: Icon(
                            Icons.search,
                            color: const Color(0xFF64748b),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: const BorderRadius.only(
                                topRight: Radius.circular(12),
                                bottomRight: Radius.circular(12),
                              ),
                            ),
                            child: TextField(
                              controller: _searchController,
                              onChanged: (value) {
                                setState(() {
                                  _searchQuery = value;
                                });
                              },
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.black,
                                fontWeight: FontWeight.normal,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Buscar departamento...',
                                hintStyle: TextStyle(
                                  color: const Color(0xFF64748b),
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.only(
                                  left: 12,
                                  right: 16,
                                  bottom: 2,
                                ),
                                fillColor: Colors.white,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Contenido principal
                if (departamentoProvider.cargando)
                  const Expanded(
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_departamentosFiltrados.isEmpty)
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.search_off,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isEmpty
                                ? 'No hay departamentos'
                                : 'No se encontraron resultados',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  // Grid de Departamentos
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: GridView.builder(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 1.1,
                            ),
                        itemCount: _departamentosFiltrados.length,
                        itemBuilder: (context, index) {
                          final departamento = _departamentosFiltrados[index];
                          return _buildDepartamentoCard(departamento);
                        },
                      ),
                    ),
                  ),

                // Bottom Navigation Bar Spacer
                const SizedBox(height: 60),
              ],
            ),
          ),
        ),
      ),

      // Floating Action Button (Scanning Trigger)
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: const Color(0xFFe2e8f0))),
        ),
        child: BottomAppBar(
          height: 72,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          color: Colors.white.withValues(alpha: 0.95),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildBottomNavItem(
                icon: Icons.apartment,
                label: 'Departamentos',
                isActive: true,
              ),

              _buildBottomNavItem(
                icon: Icons.history,
                label: 'Historial',
                isActive: false,
                onTap: () => AppRoutes.goToAuditHistory(context),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDepartamentoCard(Departamento departamento) {
    // Asignar icono y color según el nombre del departamento
    final icono = _getIconoPorNombre(departamento.nombre);
    final colorIcono = _getColorPorNombre(departamento.nombre);

    return GestureDetector(
      onTap: () => _iniciarRevision(context, departamento),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFe2e8f0)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Icono
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: colorIcono.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icono, color: colorIcono, size: 24),
              ),

              // Texto
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    departamento.nombre,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${departamento.cantidadEquiposAsignados} equipos',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF64748b),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavItem({
    required IconData icon,
    required String label,
    required bool isActive,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            color: isActive
                ? const Color(0xFF135bec)
                : (const Color(0xFF64748b)),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: isActive
                  ? const Color(0xFF135bec)
                  : const Color(0xFF64748b),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  // Helper para asignar iconos según el nombre
  IconData _getIconoPorNombre(String nombre) {
    final nombreLower = nombre.toLowerCase();
    if (nombreLower.contains('soporte') || nombreLower.contains('ti')) {
      return Icons.computer;
    } else if (nombreLower.contains('mobiliario') ||
        nombreLower.contains('muebles')) {
      return Icons.chair;
    } else if (nombreLower.contains('operaciones')) {
      return Icons.settings;
    } else if (nombreLower.contains('rrhh') || nombreLower.contains('humano')) {
      return Icons.people;
    } else if (nombreLower.contains('ventas')) {
      return Icons.trending_up;
    } else if (nombreLower.contains('almacen') ||
        nombreLower.contains('bodega')) {
      return Icons.inventory;
    } else if (nombreLower.contains('desarrollo') ||
        nombreLower.contains('software')) {
      return Icons.code;
    } else {
      return Icons.business;
    }
  }

  Color _getColorPorNombre(String nombre) {
    final nombreLower = nombre.toLowerCase();
    if (nombreLower.contains('soporte')) return const Color(0xFF135bec);
    if (nombreLower.contains('mobiliario')) return const Color(0xFFf97316);
    if (nombreLower.contains('operaciones')) return const Color(0xFF10b981);
    if (nombreLower.contains('rrhh')) return const Color(0xFF8b5cf6);
    if (nombreLower.contains('ventas')) return const Color(0xFF3b82f6);
    if (nombreLower.contains('almacen')) return const Color(0xFFf59e0b);
    if (nombreLower.contains('desarrollo')) return const Color(0xFFec4899);
    return const Color(0xFF64748b);
  }
}
