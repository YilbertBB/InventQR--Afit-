import '../models/usuario.dart';

class PermissionGuard {
  static bool canAccess(Usuario? usuario, String permiso) {
    if (usuario == null) return false;
    return usuario.tienePermiso(permiso);
  }
}
