import '../database/database_helper.dart';
import '../models/trabajador.dart';

class TrabajadorService {
  final DatabaseHelper dbHelper;

  TrabajadorService({required this.dbHelper});

  // Obtener todos los trabajadores activos
  Future<List<Trabajador>> obtenerTrabajadores() async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'trabajadores',
      where: 'activo = 1',
      orderBy: 'apellidos ASC, nombres ASC',
    );

    return resultados.map((map) => Trabajador.fromMap(map)).toList();
  }

  // Obtener todos los trabajadores (incluyendo inactivos)
  Future<List<Trabajador>> obtenerTrabajadoresIncluyendoInactivos() async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'trabajadores',
      orderBy: 'apellidos ASC, nombres ASC',
    );

    return resultados.map((map) => Trabajador.fromMap(map)).toList();
  }

  // Obtener trabajador por ID
  Future<Trabajador?> obtenerTrabajadorPorId(String id) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'trabajadores',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (resultados.isEmpty) return null;
    return Trabajador.fromMap(resultados.first);
  }

  // Obtener trabajadores por departamento
  Future<List<Trabajador>> obtenerTrabajadoresPorDepartamento(
    String departamentoId,
  ) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'trabajadores',
      where: 'departamento_id = ? AND activo = 1',
      whereArgs: [departamentoId],
      orderBy: 'apellidos ASC, nombres ASC',
    );

    return resultados.map((map) => Trabajador.fromMap(map)).toList();
  }

  // Buscar trabajadores por nombre, apellido o DNI
  Future<List<Trabajador>> buscarTrabajadores(String busqueda) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'trabajadores',
      where:
          '(nombres LIKE ? OR apellidos LIKE ? OR dni LIKE ?) AND activo = 1',
      whereArgs: ['%$busqueda%', '%$busqueda%', '%$busqueda%'],
      orderBy: 'apellidos ASC, nombres ASC',
    );

    return resultados.map((map) => Trabajador.fromMap(map)).toList();
  }

  // Crear trabajador
  Future<Trabajador> crearTrabajador(Trabajador trabajador) async {
    final db = await dbHelper.database;

    // Verificar si el DNI ya existe
    final existente = await db.query(
      'trabajadores',
      where: 'dni = ?',
      whereArgs: [trabajador.dni],
    );

    if (existente.isNotEmpty) {
      throw Exception('Ya existe un trabajador con el DNI ${trabajador.dni}');
    }

    await db.insert('trabajadores', trabajador.toMap());

    // Actualizar contador del departamento
    await _actualizarContadorDepartamento(trabajador.departamentoId);

    return trabajador;
  }

  // Actualizar trabajador
  Future<void> actualizarTrabajador(Trabajador trabajador) async {
    final db = await dbHelper.database;

    // Verificar si el DNI ya existe (excepto el mismo trabajador)
    final existente = await db.query(
      'trabajadores',
      where: 'dni = ? AND id != ?',
      whereArgs: [trabajador.dni, trabajador.id],
    );

    if (existente.isNotEmpty) {
      throw Exception('Ya existe otro trabajador con el DNI ${trabajador.dni}');
    }

    // Obtener departamento anterior para actualizar contadores
    final trabajadorAnterior = await obtenerTrabajadorPorId(trabajador.id);

    await db.update(
      'trabajadores',
      trabajador.toMap(),
      where: 'id = ?',
      whereArgs: [trabajador.id],
    );

    // Actualizar contadores de departamentos
    if (trabajadorAnterior != null &&
        trabajadorAnterior.departamentoId != trabajador.departamentoId) {
      await _actualizarContadorDepartamento(trabajadorAnterior.departamentoId);
      await _actualizarContadorDepartamento(trabajador.departamentoId);
    } else {
      await _actualizarContadorDepartamento(trabajador.departamentoId);
    }
  }

  // Desactivar trabajador (soft delete)
  Future<void> desactivarTrabajador(String id) async {
    final db = await dbHelper.database;

    // Verificar si tiene equipos asignados
    final equiposAsignados = await db.query(
      'equipos',
      where: 'trabajador_id = ? AND activo = 1',
      whereArgs: [id],
    );

    if (equiposAsignados.isNotEmpty) {
      throw Exception(
        'No se puede desactivar. El trabajador tiene ${equiposAsignados.length} equipos asignados.',
      );
    }

    final trabajador = await obtenerTrabajadorPorId(id);

    await db.update(
      'trabajadores',
      {'activo': 0},
      where: 'id = ?',
      whereArgs: [id],
    );

    if (trabajador != null) {
      await _actualizarContadorDepartamento(trabajador.departamentoId);
    }
  }

  // Reactivar trabajador
  Future<void> reactivarTrabajador(String id) async {
    final db = await dbHelper.database;

    await db.update(
      'trabajadores',
      {'activo': 1},
      where: 'id = ?',
      whereArgs: [id],
    );

    final trabajador = await obtenerTrabajadorPorId(id);
    if (trabajador != null) {
      await _actualizarContadorDepartamento(trabajador.departamentoId);
    }
  }

  // Eliminar trabajador permanentemente (hard delete)
  Future<void> eliminarTrabajadorPermanente(String id) async {
    final db = await dbHelper.database;

    // Verificar si tiene equipos asignados
    final equiposAsignados = await db.query(
      'equipos',
      where: 'trabajador_id = ? AND activo = 1',
      whereArgs: [id],
    );

    if (equiposAsignados.isNotEmpty) {
      throw Exception(
        'No se puede eliminar. El trabajador tiene ${equiposAsignados.length} equipos asignados.',
      );
    }

    final trabajador = await obtenerTrabajadorPorId(id);

    await db.delete('trabajadores', where: 'id = ?', whereArgs: [id]);

    if (trabajador != null) {
      await _actualizarContadorDepartamento(trabajador.departamentoId);
    }
  }

  // Obtener estadísticas de trabajadores
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await dbHelper.database;

    final totalActivos = await db.rawQuery('''
      SELECT COUNT(*) as total FROM trabajadores WHERE activo = 1
    ''');

    final totalInactivos = await db.rawQuery('''
      SELECT COUNT(*) as total FROM trabajadores WHERE activo = 0
    ''');

    final porDepartamento = await db.rawQuery('''
      SELECT d.nombre, COUNT(t.id) as cantidad
      FROM departamentos d
      LEFT JOIN trabajadores t ON d.id = t.departamento_id AND t.activo = 1
      GROUP BY d.id
      ORDER BY cantidad DESC
    ''');

    final conEquiposAsignados = await db.rawQuery('''
      SELECT COUNT(DISTINCT trabajador_id) as cantidad
      FROM equipos
      WHERE trabajador_id IS NOT NULL AND activo = 1
    ''');

    return {
      'total_activos': totalActivos.first['total'] ?? 0,
      'total_inactivos': totalInactivos.first['total'] ?? 0,
      'por_departamento': porDepartamento,
      'con_equipos_asignados': conEquiposAsignados.first['cantidad'] ?? 0,
    };
  }

  // Actualizar contador de personal en departamento
  Future<void> _actualizarContadorDepartamento(String departamentoId) async {
    final db = await dbHelper.database;

    final count = await db.rawQuery(
      '''
      SELECT COUNT(*) as cantidad 
      FROM trabajadores 
      WHERE departamento_id = ? AND activo = 1
    ''',
      [departamentoId],
    );

    final cantidad = count.first['cantidad'] as int? ?? 0;

    await db.update(
      'departamentos',
      {'cantidad_personal': cantidad},
      where: 'id = ?',
      whereArgs: [departamentoId],
    );
  }

  // Validar DNI (formato peruano)
  bool validarDNI(String dni) {
    if (dni.length != 8) return false;
    return RegExp(r'^[0-9]+$').hasMatch(dni);
  }

  // Validar email corporativo
  bool validarEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }
}
