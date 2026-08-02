import 'package:afit_prueba1/models/usuario.dart';
import 'package:afit_prueba1/utils/permission_guard.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PermissionGuard', () {
    test('permite el acceso a gestión de inventario para administradores', () {
      final admin = Usuario(
        id: '1',
        username: 'admin',
        passwordHash: 'hash',
        nombreCompleto: 'Administrador',
        email: 'admin@test.com',
        rol: 'admin',
        telefono: '123456789',
        fechaCreacion: DateTime.now(),
      );

      expect(PermissionGuard.canAccess(admin, 'gestion_equipos'), isTrue);
      expect(PermissionGuard.canAccess(admin, 'importar'), isTrue);
      expect(PermissionGuard.canAccess(admin, 'trasladar'), isTrue);
    });

    test('bloquea el acceso a gestión de inventario para empleados', () {
      final empleado = Usuario(
        id: '2',
        username: 'empleado',
        passwordHash: 'hash',
        nombreCompleto: 'Empleado',
        email: 'empleado@test.com',
        rol: 'empleado',
        telefono: '987654321',
        fechaCreacion: DateTime.now(),
      );

      expect(PermissionGuard.canAccess(empleado, 'gestion_equipos'), isFalse);
      expect(PermissionGuard.canAccess(empleado, 'importar'), isFalse);
      expect(PermissionGuard.canAccess(empleado, 'trasladar'), isFalse);
    });
  });
}
