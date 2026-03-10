import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/usuario.dart';

class AuthProvider with ChangeNotifier {
  Usuario? _usuarioActual;
  bool _estaCargando = false;
  String? _errorMensaje;
  List<Usuario>? _usuarios;

  List<Usuario>? get usuarios => _usuarios;
  Usuario? get usuarioActual => _usuarioActual;
  bool get estaCargando => _estaCargando;
  String? get errorMensaje => _errorMensaje;
  bool get estaAutenticado => _usuarioActual != null;
  bool get esUsuarioRoot {
    return _usuarioActual?.username == 'root';
  }

  Future<void> inicializarDatos() async {
    await cargarUsuarios();
  }

  bool get rootDebeEstarRestringido {
    // Root está restringido si hay otros usuarios
    return _usuarios?.any((u) => u.username != 'root' && u.activo) ?? false;
  }

  bool rootPuedeRealizarAccion(String accion) {
    // Root solo puede:
    // - Ver la pantalla de creación de usuario
    // - Crear el primer usuario admin
    // - Navegar pero no modificar nada

    if (!esUsuarioRoot) return true;

    // Si root ya no debería existir, restringir todo
    if (rootDebeEstarRestringido) {
      return false;
    }

    // Acciones permitidas para root
    final accionesPermitidasRoot = [
      'ver_crear_usuario',
      'crear_primer_usuario',
      'navegar_sin_modificar',
    ];

    return accionesPermitidasRoot.contains(accion);
  }

  Future<void> actualizarListaUsuarios() async {
    await cargarUsuarios();
  }

  // Verificar si hay sesión activa
  Future<bool> verificarSesionActiva() async {
    final prefs = await SharedPreferences.getInstance();
    final usuarioId = prefs.getString('usuario_id');

    if (usuarioId == null) return false;

    final dbHelper = DatabaseHelper.instance;
    final db = await dbHelper.database;

    final resultados = await db.query(
      'usuarios',
      where: 'id = ? AND activo = 1',
      whereArgs: [usuarioId],
    );

    if (resultados.isNotEmpty) {
      _usuarioActual = Usuario.fromMap(resultados.first);
      notifyListeners();
      return true;
    }

    return false;
  }

  // Iniciar sesión

  Future<bool> login(String username, String password) async {
    try {
      _estaCargando = true;
      _errorMensaje = null;
      notifyListeners();

      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // Buscar usuario
      final resultados = await db.query(
        'usuarios',
        where: 'username = ? AND activo = 1',
        whereArgs: [username],
      );

      if (resultados.isEmpty) {
        _errorMensaje = 'Usuario no encontrado';
        _estaCargando = false;
        notifyListeners();
        return false;
      }

      final usuario = Usuario.fromMap(resultados.first);

      // Verificar contraseña
      if (usuario.passwordHash != password) {
        _errorMensaje = 'Contraseña incorrecta';
        _estaCargando = false;
        notifyListeners();
        return false;
      }

      // Guardar sesión
      _usuarioActual = usuario;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('usuario_id', usuario.id);
      await prefs.setString('usuario_rol', usuario.rol);
      await prefs.setString('usuario_nombre', usuario.nombreCompleto);
      await prefs.setString('usuario_email', usuario.email);

      // Actualizar último login
      await db.update(
        'usuarios',
        {'fecha_ultimo_login': DateTime.now().toIso8601String()},
        where: 'id = ?',
        whereArgs: [usuario.id],
      );

      // Eliminar usuario root si hay otros usuarios
      if (username != 'root') {
        await dbHelper.eliminarUsuarioRootSiHayOtrosUsuarios();
      }

      _estaCargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMensaje = 'Error al iniciar sesión: $e';
      _estaCargando = false;
      notifyListeners();
      return false;
    }
  }

  // Cerrar sesión
  Future<void> logout() async {
    try {
      // 1. Limpiar SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('usuario_id');
      await prefs.remove('usuario_rol');
      await prefs.remove('usuario_nombre');

      // 2. Limpiar datos en memoria
      _usuarioActual = null;
      _errorMensaje = null;

      // 3. Notificar a los listeners
      notifyListeners();
    } catch (e) {
      _errorMensaje = 'Error al cerrar sesión: $e';
      notifyListeners();
      throw Exception(_errorMensaje);
    }
  }

  // Crear nuevo usuario
  Future<bool> crearUsuario(Usuario usuario) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // Verificar si el username ya existe
      final existente = await db.query(
        'usuarios',
        where: 'username = ?',
        whereArgs: [usuario.username],
      );

      if (existente.isNotEmpty) {
        _errorMensaje = 'El nombre de usuario ya existe';
        return false;
      }

      // Insertar nuevo usuario
      await db.insert('usuarios', usuario.toMap());

      // ACTUALIZAR LA LISTA DE USUARIOS INMEDIATAMENTE
      await cargarListaUsuarios(); // AÑADE ESTA LÍNEA

      // Si se creó un usuario nuevo (no root), eliminar root
      if (usuario.username != 'root') {
        await dbHelper.eliminarUsuarioRootSiHayOtrosUsuarios();
        if (_usuarioActual?.username == 'root') {
          return true; // Indicará que debe cerrarse sesión
        }
      }

      return true;
    } catch (e) {
      _errorMensaje = 'Error al crear usuario: $e';
      return false;
    }
  }

  Future<bool> crearUsuarioConVerificacion(Usuario usuario) async {
    final resultado = await crearUsuario(usuario);

    if (resultado &&
        _usuarioActual?.username == 'root' &&
        usuario.username != 'root') {
      // El usuario actual es root y se creó otro usuario, cerrar sesión
      await logout();
      return true;
    }

    return resultado;
  }

  // Verificar permisos
  bool tienePermiso(String permiso) {
    return _usuarioActual?.tienePermiso(permiso) ?? false;
  }

  Future<void> cargarListaUsuarios() async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      final resultados = await db.query('usuarios', orderBy: 'nombre_completo');

      _usuarios = resultados.map((map) => Usuario.fromMap(map)).toList();
      notifyListeners();
    } catch (e) {
      _usuarios = [];
      notifyListeners();
    }
  }

  // Modifica el método cargarUsuarios existente para usar el nuevo:
  Future<void> cargarUsuarios() async {
    await cargarListaUsuarios();
  }

  // Limpiar errores
  void limpiarError() {
    _errorMensaje = null;
    notifyListeners();
  }

  // Actualizar perfil
  // Actualizar perfil - VERSIÓN CORREGIDA
  Future<bool> actualizarPerfil(Usuario usuarioActualizado) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // Verificar si el usuario existe
      final resultados = await db.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioActualizado.id],
      );

      if (resultados.isEmpty) {
        _errorMensaje = 'Usuario no encontrado';
        return false;
      }

      // Actualizar en la base de datos
      await db.update(
        'usuarios',
        usuarioActualizado.toMap(),
        where: 'id = ?',
        whereArgs: [usuarioActualizado.id],
      );

      // ✅ **SOLO actualizar usuarioActual si es el mismo usuario logueado**
      if (_usuarioActual != null &&
          _usuarioActual!.id == usuarioActualizado.id) {
        // Actualizar solo si es el mismo usuario
        _usuarioActual = usuarioActualizado;

        // También actualizar SharedPreferences si es necesario
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('usuario_id', usuarioActualizado.id);
        await prefs.setString('usuario_rol', usuarioActualizado.rol);
        await prefs.setString(
          'usuario_nombre',
          usuarioActualizado.nombreCompleto,
        );
        await prefs.setString('usuario_email', usuarioActualizado.email);
      } else {}

      // Actualizar la lista de usuarios
      await cargarListaUsuarios();

      notifyListeners();
      return true;
    } catch (e) {
      _errorMensaje = 'Error al actualizar perfil: $e';
      return false;
    }
  }

  // Eliminar usuario
  Future<bool> eliminarUsuario(String usuarioId) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // Verificar si el usuario existe
      final resultados = await db.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
      );

      if (resultados.isEmpty) {
        _errorMensaje = 'Usuario no encontrado';
        return false;
      }

      // NO permitir eliminar al usuario actual
      if (_usuarioActual?.id == usuarioId) {
        _errorMensaje = 'No puedes eliminar tu propia cuenta';
        return false;
      }

      // NO permitir eliminar todos los usuarios admin
      final usuarioAEliminar = Usuario.fromMap(resultados.first);
      if (usuarioAEliminar.rol == 'admin') {
        // Contar cuántos administradores quedan
        final adminResultados = await db.query(
          'usuarios',
          where: 'rol = ? AND activo = 1',
          whereArgs: ['admin'],
        );

        if (adminResultados.length <= 1) {
          _errorMensaje = 'No se puede eliminar el único administrador activo';
          return false;
        }
      }

      // Eliminar usuario (físicamente o marcar como inactivo)
      // Opción 1: Eliminar físicamente
      await db.delete('usuarios', where: 'id = ?', whereArgs: [usuarioId]);

      // Opción 2: Marcar como inactivo (recomendado para mantener historial)
      /*
    await db.update(
      'usuarios',
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [usuarioId],
    );
    */

      // Actualizar la lista de usuarios
      await cargarListaUsuarios();

      return true;
    } catch (e) {
      _errorMensaje = 'Error al eliminar usuario: $e';
      return false;
    }
  }

  // Desactivar usuario (alternativa más segura)
  Future<bool> desactivarUsuario(String usuarioId) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // Verificar si el usuario existe
      final resultados = await db.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
      );

      if (resultados.isEmpty) {
        _errorMensaje = 'Usuario no encontrado';
        return false;
      }

      // NO permitir desactivar al usuario actual
      if (_usuarioActual?.id == usuarioId) {
        _errorMensaje = 'No puedes desactivar tu propia cuenta';
        return false;
      }

      final usuarioADesactivar = Usuario.fromMap(resultados.first);

      // NO permitir desactivar todos los usuarios admin
      if (usuarioADesactivar.rol == 'admin' && usuarioADesactivar.activo) {
        final adminResultados = await db.query(
          'usuarios',
          where: 'rol = ? AND activo = 1',
          whereArgs: ['admin'],
        );

        if (adminResultados.length <= 1) {
          _errorMensaje =
              'No se puede desactivar el único administrador activo';
          return false;
        }
      }

      // Marcar como inactivo
      await db.update(
        'usuarios',
        {'activo': 0},
        where: 'id = ?',
        whereArgs: [usuarioId],
      );

      // Actualizar la lista de usuarios
      await cargarListaUsuarios();

      return true;
    } catch (e) {
      _errorMensaje = 'Error al desactivar usuario: $e';
      return false;
    }
  }

  // En auth_provider.dart, añade este método:

  Future<bool> reactivarUsuario(String usuarioId) async {
    try {
      final dbHelper = DatabaseHelper.instance;
      final db = await dbHelper.database;

      // Verificar si el usuario existe
      final resultados = await db.query(
        'usuarios',
        where: 'id = ?',
        whereArgs: [usuarioId],
      );

      if (resultados.isEmpty) {
        _errorMensaje = 'Usuario no encontrado';
        return false;
      }

      final usuario = Usuario.fromMap(resultados.first);

      // Si el usuario ya está activo, no hacer nada
      if (usuario.activo) {
        return true;
      }

      // Reactivar usuario
      await db.update(
        'usuarios',
        {'activo': 1},
        where: 'id = ?',
        whereArgs: [usuarioId],
      );

      // Actualizar la lista de usuarios
      await cargarListaUsuarios();

      return true;
    } catch (e) {
      _errorMensaje = 'Error al reactivar usuario: $e';
      return false;
    }
  }
}
