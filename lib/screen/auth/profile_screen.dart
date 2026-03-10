import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_theme.dart';
import '../../core/app_routes.dart';
import '../../models/revision.dart';
import '../../providers/auth_provider.dart';
import '../../providers/equipo_provider.dart';
import '../../providers/revision_provider.dart';
import '../../models/usuario.dart';
import '../inventory/history_screen.dart';
import 'create_user_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final int _selectedNavIndex = 3;

  final List<AccountAction> _accountActions = [
    AccountAction(
      title: 'Historial de Actividades',
      icon: Icons.history,
      iconColor: const Color(0xFF8B5CF6),
      iconBackground: const Color(0xFFEDE9FE),
      subtitle: '',
    ),
    AccountAction(
      title: 'Editar Perfil',
      icon: Icons.person,
      iconColor: AppTheme.primaryColor,
      iconBackground: const Color(0xFFDBEAFE),
      subtitle: '',
    ),
    AccountAction(
      title: 'Cerrar Sesión',
      icon: Icons.logout,
      iconColor: AppTheme.errorColor,
      iconBackground: const Color(0xFFFEE2E2),
      subtitle: '',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final usuarioActual = authProvider.usuarioActual;

    // Usar colores de AppTheme
    final primaryColor = AppTheme.primaryColor;
    final backgroundColor = AppTheme.backgroundColorLight;
    final surfaceColor = Colors.white;
    final borderColor = const Color(0xFFE5E7EB);
    final textColor = const Color(0xFF111827);

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenido principal
            SingleChildScrollView(
              child: Column(
                children: [
                  // Top Navigation Bar
                  _buildTopAppBar(
                    context,
                    primaryColor,
                    textColor,
                    backgroundColor,
                    borderColor,
                  ),

                  // Profile Header (con datos reales)
                  _buildProfileHeader(
                    context,
                    primaryColor,
                    backgroundColor,
                    textColor,
                    usuarioActual,
                  ),

                  // Statistics Grid
                  _buildStatisticsGrid(
                    context,
                    surfaceColor,
                    borderColor,
                    textColor,
                  ),

                  // Account Actions Section
                  _buildAccountActions(
                    context,
                    surfaceColor,
                    borderColor,
                    textColor,
                    usuarioActual,
                  ),

                  // Espacio para la navegación inferior
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomAppBar(
        height: 60,
        padding: const EdgeInsets.only(top: 10),
        color: Colors.white.withValues(alpha: 0.95),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // Botón Dashboard
            _buildNavButton(
              icon: Icons.dashboard,
              label: 'Inicio',
              isActive: _selectedNavIndex == 0,
              onTap: () => AppRoutes.goToDashboard(context),
            ),

            // Botón Stock (activo)
            _buildNavButton(
              icon: Icons.list_alt,
              label: 'Inventario',
              isActive: _selectedNavIndex == 1,
              onTap: () => AppRoutes.goToInventory(context),
            ),

            // Botón Reportes
            _buildNavButton(
              icon: Icons.supervised_user_circle_sharp,
              label: 'Usuarios',
              isActive: _selectedNavIndex == 2,
              onTap: () => AppRoutes.goToUserList(context),
            ),

            // Botón Ajustes
            _buildNavButton(
              icon: Icons.person,
              label: 'Perfil',
              isActive: _selectedNavIndex == 3,
              onTap: () => AppRoutes.goToProfile(context),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => AppRoutes.goToScanner(context),
        backgroundColor: const Color(0xFF135BEC),
        elevation: 8,
        shape: const CircleBorder(),
        child: const Icon(Icons.qr_code_scanner, size: 30, color: Colors.white),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildTopAppBar(
    BuildContext context,
    Color primaryColor,
    Color textColor,
    Color backgroundColor,
    Color borderColor,
  ) {
    final iconBg = const Color(0xFFE5E7EB);
    final iconColor = const Color(0xFF4B5563);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.8),
        border: Border(bottom: BorderSide(color: borderColor, width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo and Title
          Row(
            children: [
              Icon(Icons.inventory_2, color: primaryColor, size: 28),
              const SizedBox(width: 8),
              Text(
                'IT Assets',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),

          // Action Buttons
          Row(
            children: [
              IconButton(
                onPressed: () {
                  _showSettings(context);
                },
                style: IconButton.styleFrom(
                  backgroundColor: iconBg,
                  shape: const CircleBorder(),
                  padding: const EdgeInsets.all(8),
                ),
                icon: Icon(Icons.settings, color: iconColor, size: 20),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(
    BuildContext context,
    Color primaryColor,
    Color backgroundColor,
    Color textColor,
    Usuario? usuario,
  ) {
    final nombreUsuario = usuario?.nombreCompleto ?? 'Usuario';
    final rolUsuario = _getRolDisplayName(usuario?.rol ?? 'empleado');
    final departamento = usuario?.departamento ?? 'Sin departamento';
    final email = usuario?.email ?? 'sin@email.com';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 16),
      child: Column(
        children: [
          // Profile Avatar
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: primaryColor.withValues(alpha: 0.2),
                    width: 4,
                  ),
                ),
                padding: const EdgeInsets.all(4),
                child: ClipOval(child: _buildUserAvatar(usuario, primaryColor)),
              ),
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: backgroundColor, width: 4),
                ),
              ),
            ],
          ),

          // Name and Title
          const SizedBox(height: 16),
          Text(
            nombreUsuario,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF111827),
            ),
          ),
          Text(
            rolUsuario,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: const Color(0xFF6B7280),
            ),
          ),

          // Email
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Text(
              email,
              style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
            ),
          ),

          // Location Badge
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.business, color: primaryColor, size: 14),
                const SizedBox(width: 4),
                Text(
                  departamento,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: primaryColor,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Estado del usuario
          if (usuario != null)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: usuario.activo
                    ? AppTheme.successColor.withValues(alpha: 0.1)
                    : AppTheme.errorColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                usuario.activo ? 'Activo' : 'Inactivo',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: usuario.activo
                      ? AppTheme.successColor
                      : AppTheme.errorColor,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(Usuario? usuario, Color primaryColor) {
    // Si el usuario tiene una foto URL, intentar cargarla
    if (usuario?.fotoUrl != null && usuario!.fotoUrl!.isNotEmpty) {
      return Image.network(
        usuario.fotoUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return _buildDefaultAvatar(usuario, primaryColor);
        },
      );
    }

    return _buildDefaultAvatar(usuario, primaryColor);
  }

  Widget _buildDefaultAvatar(Usuario? usuario, Color primaryColor) {
    return Container(
      color: primaryColor.withValues(alpha: 0.1),
      child: Center(child: Icon(Icons.person, size: 48, color: primaryColor)),
    );
  }

  String _getRolDisplayName(String rol) {
    switch (rol) {
      case 'admin':
        return 'Administrador';
      case 'supervisor':
        return 'Supervisor';
      case 'auditor':
        return 'Auditor';
      case 'empleado':
        return 'Empleado';
      default:
        return 'Usuario';
    }
  }

  Widget _buildStatisticsGrid(
    BuildContext context,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    final equipoProvider = Provider.of<EquipoProvider>(context);
    final revisionProvider = Provider.of<RevisionProvider>(context);

    final totalActivos = equipoProvider.equipos.where((e) => e.activo).length;
    final equiposAsignados = equipoProvider.equipos
        .where((e) => e.estaAsignado)
        .length;

    final historialRevisiones = revisionProvider.historialRevisiones;
    final totalRevisiones = historialRevisiones.length;
    final revisionesCompletadas = historialRevisiones
        .where((r) => r.estaCompletada)
        .length;
    final porcentajeRevisiones = totalRevisiones == 0
        ? 0.0
        : (revisionesCompletadas / totalRevisiones) * 100;

    final ultimaRevision = _obtenerUltimaRevision(historialRevisiones);
    final ultimaActividad = ultimaRevision == null
        ? 'Sin actividad'
        : _formatTiempoTranscurrido(ultimaRevision.fechaRevision);
    final faltantesUltimaRevision = ultimaRevision?.equiposFaltantes ?? 0;

    final stats = [
      StatItem(
        title: 'Activos',
        value: totalActivos.toString(),
        icon: Icons.devices,
        change: '$equiposAsignados asignados',
        changeColor: AppTheme.primaryColor,
      ),
      StatItem(
        title: 'Revisiones',
        value: '${porcentajeRevisiones.toStringAsFixed(1)}%',
        icon: Icons.task_alt,
        change: '$revisionesCompletadas/$totalRevisiones completadas',
        changeColor: totalRevisiones == 0
            ? AppTheme.warningColor
            : AppTheme.successColor,
      ),
      StatItem(
        title: 'Última Actividad',
        value: ultimaActividad,
        icon: Icons.history,
      ),
      StatItem(
        title: 'Faltantes',
        value: faltantesUltimaRevision.toString(),
        icon: Icons.warning,
        change: ultimaRevision == null
            ? null
            : _formatFechaCorta(ultimaRevision.fechaRevision),
        changeColor: AppTheme.warningColor,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.2,
        ),
        itemCount: stats.length,
        itemBuilder: (context, index) {
          final stat = stats[index];
          return _buildStatCard(stat, surfaceColor, borderColor, textColor);
        },
      ),
    );
  }

  Widget _buildStatCard(
    StatItem stat,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
  ) {
    return Container(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                stat.icon,
                color: stat.icon == Icons.warning
                    ? AppTheme.warningColor
                    : AppTheme.primaryColor,
              ),
              if (stat.change != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: stat.changeColor!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    stat.change!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: stat.changeColor,
                    ),
                  ),
                ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                stat.title,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFF6B7280),
                  letterSpacing: 0.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  stat.value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF111827),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActions(
    BuildContext context,
    Color surfaceColor,
    Color borderColor,
    Color textColor,
    Usuario? usuarioActual,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 12),
            child: Text(
              'ACCIONES DE CUENTA',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: const Color(0xFF6B7280),
                letterSpacing: 1.5,
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _accountActions.length,
              itemBuilder: (context, index) {
                final action = _accountActions[index];
                return _buildAccountActionItem(
                  action,
                  index < _accountActions.length - 1,
                  textColor,
                  usuarioActual,
                  context,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountActionItem(
    AccountAction action,
    bool showDivider,
    Color textColor,
    Usuario? usuarioActual,
    BuildContext context,
  ) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () async {
          if (action.title == 'Historial de Actividades') {
            // _showEditProfileDialog(context, usuarioActual);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AllActivitiesHistoryScreen(),
              ),
            );
          } else if (action.title == 'Editar Perfil') {
            // _showEditProfileDialog(context, usuarioActual);
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => CreateEditUserScreen(
                  esModoEdicion: true,
                  usuarioAEditar: usuarioActual,
                ),
              ),
            );
          } else if (action.title == 'Cerrar Sesión') {
            // Cerrar sesión
            final confirm = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text('Cerrar Sesión'),
                content: const Text('¿Está seguro de que desea cerrar sesión?'),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Cancelar'),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.errorColor,
                    ),
                    child: const Text('Sí, cerrar sesión'),
                  ),
                ],
              ),
            );

            if (context.mounted && confirm == true) {
              final authProvider = Provider.of<AuthProvider>(
                context,
                listen: false,
              );
              await authProvider.logout();
              if (context.mounted) {
                AppRoutes.goToLogin(context);
              }
            }
          }
        },
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: showDivider
              ? const BoxDecoration(
                  border: Border(
                    bottom: BorderSide(color: Color(0xFFE5E7EB), width: 1),
                  ),
                )
              : null,
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: action.iconBackground,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(action.icon, color: action.iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      action.title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: action.title == 'Cerrar Sesión'
                            ? AppTheme.errorColor
                            : textColor,
                      ),
                    ),
                    if (action.subtitle.isNotEmpty)
                      Text(
                        action.subtitle,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.primaryColor,
                        ),
                      ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: action.title == 'Cerrar Sesi?n'
                    ? AppTheme.errorColor
                    : const Color(0xFF9CA3AF),
              ),
            ],
          ),
        ),
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
            color: isActive ? const Color(0xFF135BEC) : const Color(0xFF94A3B8),
            size: 24,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
              color: isActive
                  ? const Color(0xFF135BEC)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final usuarioActual = authProvider.usuarioActual;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          height:
              MediaQuery.of(context).size.height * 0.55, // 85% de la pantalla
          color: Colors.white,
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Ajustes',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF111827),
                ),
              ),
              const SizedBox(height: 20),

              // Contenido con scroll
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      if (usuarioActual != null)
                        ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.person),
                          ),
                          title: Text(usuarioActual.nombreCompleto),
                          subtitle: Text(
                            '${_getRolDisplayName(usuarioActual.rol)} • ${usuarioActual.email}',
                            style: const TextStyle(color: Color(0xFF6B7280)),
                          ),
                        ),

                      const Divider(),

                      ListTile(
                        leading: const Icon(
                          Icons.person,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text('Perfil de Usuario'),
                        onTap: () => Navigator.pop(context),
                      ),

                      ListTile(
                        leading: const Icon(
                          Icons.cloud_upload,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text('Respaldos en la Nube'),
                        subtitle: const Text('Sincronizar y restaurar datos'),
                        trailing: const Icon(
                          Icons.open_in_new,
                          size: 16,
                          color: Colors.grey,
                        ),
                        onTap: () {
                          Navigator.pop(context);
                          AppRoutes.goToBackups(context);
                        },
                      ),

                      ListTile(
                        leading: const Icon(
                          Icons.help,
                          color: AppTheme.primaryColor,
                        ),
                        title: const Text('Ayuda y Soporte'),
                        onTap: () {
                          Navigator.pop(context);
                          // Navegar a ayuda
                        },
                      ),

                      ListTile(
                        leading: const Icon(
                          Icons.exit_to_app,
                          color: Colors.red,
                        ),
                        title: const Text(
                          'Cerrar Sesión',
                          style: TextStyle(color: Colors.red),
                        ),
                        onTap: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Cerrar Sesión'),
                              content: const Text(
                                '¿Está seguro de que desea cerrar sesión?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text('Cancelar'),
                                ),
                                ElevatedButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppTheme.errorColor,
                                  ),
                                  child: const Text('Sí, cerrar sesión'),
                                ),
                              ],
                            ),
                          );

                          if (context.mounted && confirm == true) {
                            final authProvider = Provider.of<AuthProvider>(
                              context,
                              listen: false,
                            );
                            await authProvider.logout();
                            if (context.mounted) {
                              AppRoutes.goToLogin(context);
                            }
                          }
                        },
                      ),

                      const SizedBox(height: 20),

                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cerrar'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class StatItem {
  final String title;
  final String value;
  final IconData icon;
  final String? change;
  final Color? changeColor;

  StatItem({
    required this.title,
    required this.value,
    required this.icon,
    this.change,
    this.changeColor,
  });
}

class AccountAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final Color iconBackground;

  AccountAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
  });
}

Revision? _obtenerUltimaRevision(List<Revision> revisiones) {
  if (revisiones.isEmpty) return null;
  Revision? ultima;
  for (final revision in revisiones) {
    if (ultima == null ||
        revision.fechaRevision.isAfter(ultima.fechaRevision)) {
      ultima = revision;
    }
  }
  return ultima;
}

String _formatTiempoTranscurrido(DateTime fecha) {
  final diff = DateTime.now().difference(fecha);
  if (diff.inMinutes < 1) return 'Justo ahora';
  if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'Hace ${diff.inHours} h';
  return 'Hace ${diff.inDays} d';
}

String _formatFechaCorta(DateTime fecha) {
  return '${fecha.day.toString().padLeft(2, '0')}/'
      '${fecha.month.toString().padLeft(2, '0')}';
}
