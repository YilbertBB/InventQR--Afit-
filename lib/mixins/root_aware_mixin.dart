import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../core/app_routes.dart';

mixin RootAwareMixin {
  bool verificarAccionRoot(BuildContext context, String accion) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // Si no es root, permitir
    if (!authProvider.esUsuarioRoot) return true;

    // Si es root pero no debería estar activo, bloquear
    if (authProvider.rootDebeEstarRestringido) {
      _mostrarDialogoRootBloqueado(context);
      return false;
    }

    // Verificar si la acción está permitida para root
    final permitida = authProvider.rootPuedeRealizarAccion(accion);

    if (!permitida) {
      _mostrarDialogoAccionNoPermitida(context);
    }

    return permitida;
  }

  void _mostrarDialogoRootBloqueado(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.orange),
            SizedBox(width: 10),
            Text('Acceso Restringido'),
          ],
        ),
        content: const Text(
          'El usuario root ya no está disponible porque existen otros usuarios en el sistema.\n\nPor favor, inicie sesión con un usuario administrador.',
        ),
        actions: [
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
            ),
            child: const Text('Cerrar Sesión'),
          ),
        ],
      ),
    );
  }

  void _mostrarDialogoAccionNoPermitida(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'El usuario root solo puede crear el primer usuario administrador',
        ),
        backgroundColor: Colors.orange,
        duration: Duration(seconds: 3),
      ),
    );
  }
}
