// lib/widgets/root_guard.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/app_routes.dart';

class RootGuard extends StatelessWidget {
  final Widget child;
  final List<String>? accionesPermitidas;

  const RootGuard({super.key, required this.child, this.accionesPermitidas});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);

    // Si no es root, mostrar el child normalmente
    if (!authProvider.esUsuarioRoot) {
      return child;
    }

    // Si es root pero no debería estar activo (ya hay otros usuarios)
    if (authProvider.rootDebeEstarRestringido) {
      return _buildRootBloqueado(context);
    }

    // Root activo pero con restricciones
    return _buildRootConRestricciones(context, child);
  }

  Widget _buildRootBloqueado(BuildContext context) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.security, size: 80, color: Colors.orange),
                const SizedBox(height: 24),
                const Text(
                  'Usuario Root Bloqueado',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1F2937),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Ya existen otros usuarios en el sistema.\n'
                  'El usuario root debe cerrar sesión por seguridad.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () {
                    final authProvider = Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    );
                    authProvider.logout();
                    AppRoutes.goToLogin(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 32,
                      vertical: 16,
                    ),
                  ),
                  child: const Text('Cerrar Sesión'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRootConRestricciones(BuildContext context, Widget child) {
    return Scaffold(
      body: Stack(
        children: [
          // Mostrar el child pero con un overlay de restricciones
          child,

          // Banner informativo en la parte inferior
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.9),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Modo restringido: Solo puede crear el primer usuario administrador',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      final authProvider = Provider.of<AuthProvider>(
                        context,
                        listen: false,
                      );
                      authProvider.logout();
                      AppRoutes.goToLogin(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white,
                      minimumSize: Size.zero,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                    ),
                    child: const Text('Salir'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
