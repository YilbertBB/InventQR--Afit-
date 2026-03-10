import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_routes.dart';
import '../../models/equipo.dart';
import '../../providers/equipo_provider.dart';
import '../../services/excel_export_service.dart';
import 'add_asset_screen.dart';
import 'asset_details_screen.dart';
import '../../core/app_theme.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final bool _darkMode = false;
  int _selectedChip = 0;
  int _selectedNavIndex = 1;
  final TextEditingController _searchController = TextEditingController();
  final List<String> _chips = [
    'Todos',
    'Activos',
    'En espera',
    'Mantenimiento',
    'Baja',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final equipoProvider = context.read<EquipoProvider>();
      equipoProvider.limpiarFiltros();
      equipoProvider.cargarEquipos();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _darkMode
          ? Theme.of(context).copyWith(brightness: Brightness.dark)
          : Theme.of(context).copyWith(brightness: Brightness.light),
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          backgroundColor: Colors.white.withValues(alpha: 0.95),
          leading: IconButton(
            onPressed: () => AppRoutes.goBack(context),
            icon: Icon(
              Icons.arrow_back_ios_new,
              color: Theme.of(context).colorScheme.onSurface,
              size: 24,
            ),
          ),
          title: Consumer<EquipoProvider>(
            builder: (context, provider, child) {
              final totalEquipos = provider.equipos.length;

              return Text(
                'Inventario ($totalEquipos)',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              );
            },
          ),
          centerTitle: true,
          actions: [const SizedBox(width: 8), _buildMenuButton()],
        ),
        body: Consumer<EquipoProvider>(
          builder: (context, provider, child) {
            if (provider.cargando && provider.equipos.isEmpty) {
              return const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(
                    AppTheme.primaryColor,
                  ),
                ),
              );
            }

            if (provider.error != null && provider.equipos.isEmpty) {
              return _buildErrorState(provider);
            }

            if (provider.equipos.isEmpty) {
              return _buildEmptyState(context);
            }

            return SafeArea(
              child: Column(
                children: [
                  _buildSearchBar(provider),
                  _buildChipsFilter(provider),
                  Expanded(
                    child: provider.equipos.isEmpty
                        ? _buildEmptyState(context)
                        : RefreshIndicator(
                            onRefresh: () => provider.cargarEquipos(),
                            color: AppTheme.primaryColor,
                            child: ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              itemCount: provider.equipos.length,
                              itemBuilder: (context, index) {
                                final equipo = provider.equipos[index];
                                return _buildAssetCard(equipo, provider);
                              },
                            ),
                          ),
                  ),
                ],
              ),
            );
          },
        ),
        bottomNavigationBar: _buildBottomNavBar(),
        floatingActionButton: FloatingActionButton(
          onPressed: () async {
            final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AddAssetScreen()),
            );
            if (result == true && context.mounted) {
              context.read<EquipoProvider>().cargarEquipos();
            }
          },
          backgroundColor: AppTheme.primaryColor,
          elevation: 8,
          child: const Icon(Icons.add, size: 30, color: Colors.white),
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      ),
    );
  }

  // ============================================
  // BUILDERS DE UI
  // ============================================

  Widget _buildMenuButton() {
    return Container(
      margin: const EdgeInsets.only(right: 12),
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: _darkMode ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: () => _showOptionsMenu(context),
        icon: const Icon(Icons.more_vert, color: Colors.grey, size: 20),
      ),
    );
  }

  Widget _buildErrorState(EquipoProvider provider) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text(
            'Error al cargar inventario',
            style: TextStyle(fontSize: 18, color: Colors.red),
          ),
          const SizedBox(height: 8),
          Text(
            provider.error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => provider.cargarEquipos(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.inventory_2_outlined,
              size: 60,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No hay equipos registrados',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1E293B),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Comienza agregando tu primer equipo\nal inventario',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddAssetScreen()),
              );
              if (result == true && context.mounted) {
                context.read<EquipoProvider>().cargarEquipos();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Agregar Primer Equipo'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(EquipoProvider provider) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _darkMode ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _darkMode
                ? const Color(0xFF334155).withValues(alpha: 0.5)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            const SizedBox(width: 16),
            const Icon(Icons.search, color: Color(0xFF94A3B8), size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre, QR o departamento...',
                  hintStyle: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                  ),
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                ),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
                onChanged: (value) => _performSearch(value, provider),
              ),
            ),
            if (_searchController.text.isNotEmpty)
              IconButton(
                icon: const Icon(
                  Icons.clear,
                  size: 20,
                  color: Color(0xFF94A3B8),
                ),
                onPressed: () {
                  _searchController.clear();
                  _performSearch('', provider);
                },
              ),
            _buildScannerButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildScannerButton() {
    return GestureDetector(
      onTap: () async {
        await AppRoutes.goToScanner(context);

        if (!mounted) return;

        final provider = context.read<EquipoProvider>();
        provider.limpiarFiltros(); // 🔴 CLAVE
        await provider.cargarEquipos(); // 🔴 CLAVE
      },
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: AppTheme.primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(
            Icons.qr_code_scanner,
            color: AppTheme.primaryColor,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildChipsFilter(EquipoProvider provider) {
    return SizedBox(
      height: 40,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          itemCount: _chips.length,
          itemBuilder: (context, index) {
            return Padding(
              padding: EdgeInsets.only(
                right: index < _chips.length - 1 ? 8 : 0,
              ),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_chips[index]),
                    if (index > 0) ...[
                      const SizedBox(width: 6),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 18,
                        color: _selectedChip == index ? Colors.white : null,
                      ),
                    ],
                  ],
                ),
                selected: _selectedChip == index,
                onSelected: (selected) {
                  setState(() => _selectedChip = selected ? index : 0);
                  _filterByStatus(_chips[_selectedChip], provider);
                },
                backgroundColor: _darkMode
                    ? const Color(0xFF1E293B)
                    : Colors.white,
                selectedColor: AppTheme.primaryColor,
                labelStyle: TextStyle(
                  color: _selectedChip == index
                      ? Colors.white
                      : _darkMode
                      ? const Color(0xFFCBD5E1)
                      : const Color(0xFF475569),
                ),
                side: BorderSide(
                  color: _darkMode
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1.5,
                ),
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.all(Radius.circular(999)),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildAssetCard(Equipo equipo, EquipoProvider provider) {
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AssetDetailScreen(equipoId: equipo.id),
        ),
      ).then((_) => provider.cargarEquipos()),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: _darkMode
              ? const Color(0xFF1E293B).withValues(alpha: 0.7)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: _darkMode
                ? const Color(0xFF334155).withValues(alpha: 0.4)
                : const Color(0xFFE2E8F0),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _darkMode ? 0.2 : 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
              spreadRadius: 0.5,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildAssetIcon(equipo),
              const SizedBox(width: 16),
              Expanded(child: _buildAssetInfo(equipo, provider)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAssetIcon(Equipo equipo) {
    return Stack(
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            color: _darkMode
                ? const Color(0xFF334155)
                : const Color(0xFFF1F5F9),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(
            _getIconForType(equipo.tipo),
            size: 32,
            color: _darkMode
                ? const Color(0xFFCBD5E1)
                : const Color(0xFF64748B),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: _getStatusColor(equipo.estado),
              shape: BoxShape.circle,
              border: Border.all(
                color: _darkMode ? const Color(0xFF1E293B) : Colors.white,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAssetInfo(Equipo equipo, EquipoProvider provider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                equipo.nombre,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: _darkMode
                    ? const Color(0xFF334155).withValues(alpha: 0.5)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                equipo.codigoQR.length > 12
                    ? '${equipo.codigoQR.substring(0, 12)}...'
                    : equipo.codigoQR,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: _darkMode
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                  fontFamily: 'RobotoMono',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          '${equipo.tipo} • ${equipo.marca} ${equipo.modelo}',
          style: const TextStyle(
            fontSize: 12,
            color: AppTheme.primaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(
              Icons.business,
              size: 12,
              color: _darkMode
                  ? const Color(0xFF94A3B8)
                  : const Color(0xFF64748B),
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                equipo.departamentoNombre != null &&
                        equipo.departamentoNombre != 'Sin departamento'
                    ? equipo.departamentoNombre!
                    : '',
                style: TextStyle(
                  fontSize: 12,
                  color: _darkMode
                      ? const Color(0xFF94A3B8)
                      : const Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        if (equipo.trabajadorNombre != null) ...[
          const SizedBox(height: 2),
          Row(
            children: [
              Icon(
                Icons.person,
                size: 12,
                color: _darkMode
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF64748B),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  'Asignado: ${equipo.trabajadorNombre!}',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.green[700],
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildActionButton(
                onPressed: () => _editAsset(context, equipo),
                icon: Icons.edit,
                label: 'Editar',
                color: _darkMode
                    ? const Color(0xFFCBD5E1)
                    : const Color(0xFF64748B),
                backgroundColor: _darkMode
                    ? const Color(0xFF334155)
                    : const Color(0xFFF1F5F9),
              ),
            ),
            const SizedBox(width: 8),
            _buildActionButton(
              onPressed: () => _confirmDeleteEquipo(equipo, provider),
              icon: Icons.delete,
              label: 'Eliminar',
              color: const Color(0xFFD6002E),
              backgroundColor: const Color(0xFFD6002E).withValues(alpha: 0.1),
              borderColor: const Color(0xFFD6002E).withValues(alpha: 0.2),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color backgroundColor,
    Color? borderColor,
  }) {
    return Container(
      height: 32,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
        border: borderColor != null ? Border.all(color: borderColor) : null,
      ),
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 14, color: color),
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          minimumSize: Size.zero,
        ),
      ),
    );
  }

  Widget _buildBottomNavBar() {
    return BottomAppBar(
      height: 60,
      padding: const EdgeInsets.only(top: 10),
      color: _darkMode
          ? const Color(0xFF101622).withValues(alpha: 0.95)
          : Colors.white.withValues(alpha: 0.95),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavButton(
            icon: Icons.dashboard,
            label: 'Inicio',
            isActive: _selectedNavIndex == 0,
            onTap: _navigateToDashboard,
          ),
          _buildNavButton(
            icon: Icons.list_alt,
            label: 'Inventario',
            isActive: _selectedNavIndex == 1,
            onTap: _selectStock,
          ),
          _buildNavButton(
            icon: Icons.business,
            label: 'Departamentos',
            isActive: _selectedNavIndex == 2,
            onTap: () => AppRoutes.goToDepartments(context),
          ),
          _buildNavButton(
            icon: Icons.report,
            label: 'Reporte',
            isActive: _selectedNavIndex == 3,
            onTap: () => AppRoutes.goToSelectDepartments(context),
          ),
        ],
      ),
    );
  }

  Widget _buildNavButton({
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isActive ? AppTheme.primaryColor : const Color(0xFF94A3B8),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive ? AppTheme.primaryColor : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // MÉTODOS DE NAVEGACIÓN
  // ============================================

  void _navigateToDashboard() {
    setState(() => _selectedNavIndex = 0);
    AppRoutes.goToDashboard(context);
  }

  void _selectStock() {
    setState(() => _selectedNavIndex = 1);
  }

  // ============================================
  // BÚSQUEDA Y FILTROS
  // ============================================

  Future<void> _performSearch(String query, EquipoProvider provider) async {
    await provider.buscarEquipos(query);
  }

  void _filterByStatus(String status, EquipoProvider provider) {
    String? estadoFiltro;
    switch (status) {
      case 'Activos':
        estadoFiltro = 'activo';
        break;
      case 'En espera':
        estadoFiltro = 'en espera';
        break;
      case 'Mantenimiento':
        estadoFiltro = 'mantenimiento';
        break;
      case 'Baja':
        estadoFiltro = 'baja';
        break;
    }
    provider.aplicarFiltros(estado: estadoFiltro);
  }

  // ============================================
  // ACCIONES DE EQUIPOS
  // ============================================

  void _editAsset(BuildContext context, Equipo equipo) async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => AddAssetScreen(equipo: equipo)),
    );
    if (result == true && context.mounted) {
      context.read<EquipoProvider>().cargarEquipos();
    }
  }

  void _confirmDeleteEquipo(Equipo equipo, EquipoProvider provider) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Eliminar Equipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Estás seguro de eliminar "${equipo.nombre}"?'),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.warning, color: Colors.red, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Esta acción es permanente y no se puede deshacer',
                      style: TextStyle(color: Colors.red, fontSize: 12),
                    ),
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
            onPressed: () async {
              // ✅ Capturar referencias necesarias
              // final messenger = ScaffoldMessenger.of(dialogContext);
              final navigator = Navigator.of(dialogContext);

              // ✅ Cerrar el diálogo INMEDIATAMENTE
              navigator.pop();

              try {
                // ✅ Ejecutar la eliminación
                final success = await provider.eliminarEquipo(equipo.id);

                // ✅ Verificar si el widget de la pantalla SIGUE montado
                if (mounted) {
                  if (success) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('✅ Equipo eliminado exitosamente'),
                        backgroundColor: Colors.green,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );

                    // ✅ Recargar la lista de equipos
                    await provider.cargarEquipos();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          '❌ Error: ${provider.error ?? "No se pudo eliminar"}',
                        ),
                        backgroundColor: Colors.red,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('❌ Error: $e'),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Eliminar permanentemente'),
          ),
        ],
      ),
    );
  }

  // ============================================
  // MÉTODOS AUXILIARES
  // ============================================

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

  Color _getStatusColor(String estado) {
    switch (estado.toLowerCase()) {
      case 'activo':
        return Colors.green;
      case 'en espera':
        return Colors.blue;
      case 'mantenimiento':
        return Colors.orange;
      case 'baja':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  void _showOptionsMenu(BuildContext context) {
    final provider = context.read<EquipoProvider>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(
                  Icons.import_export,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Importar desde Excel'),
                onTap: () {
                  Navigator.pop(context);
                  AppRoutes.goToImportExcel(context);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.download,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Exportar Inventario a Excel'),
                subtitle: const Text('Descargar lista completa de equipos'),
                onTap: () {
                  Navigator.pop(context);
                  _exportarInventario();
                },
              ),

              const Divider(),
              ListTile(
                leading: const Icon(
                  Icons.refresh,
                  color: AppTheme.primaryColor,
                ),
                title: const Text('Actualizar Inventario'),
                onTap: () {
                  Navigator.pop(context);
                  provider.cargarEquipos();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================
  // EXPORTAR INVENTARIO A EXCEL
  // ============================================
  Future<void> _exportarInventario() async {
    final provider = Provider.of<EquipoProvider>(context, listen: false);

    if (provider.equipos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No hay equipos para exportar'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    await ExcelExportService.exportarYCompartir(
      equipos: provider.equipos,
      context: context,
    );
  }
}
