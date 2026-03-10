import '../database/database_helper.dart';
import '../models/departamento.dart';

class DepartamentoService {
  final DatabaseHelper dbHelper;

  DepartamentoService({required this.dbHelper});

  // Obtener todos los departamentos
  Future<List<Departamento>> obtenerDepartamentos() async {
    final db = await dbHelper.database;

    final resultados = await db.query('departamentos', orderBy: 'nombre ASC');

    return resultados.map((map) => Departamento.fromMap(map)).toList();
  }

  // Obtener departamento por ID
  Future<Departamento?> obtenerDepartamentoPorId(String id) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'departamentos',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (resultados.isEmpty) return null;
    return Departamento.fromMap(resultados.first);
  }

  // Crear nuevo departamento
  Future<Departamento> crearDepartamento(String nombre) async {
    final db = await dbHelper.database;

    final departamento = Departamento(
      id: Departamento.generarId(),
      nombre: nombre,
      cantidadEquiposAsignados: 0,
      cantidadPersonal: 0,
    );

    await db.insert('departamentos', departamento.toMap());

    return departamento;
  }

  // Actualizar departamento
  Future<void> actualizarDepartamento(Departamento departamento) async {
    final db = await dbHelper.database;

    await db.update(
      'departamentos',
      departamento.toMap(),
      where: 'id = ?',
      whereArgs: [departamento.id],
    );
  }

  // Eliminar departamento
  Future<bool> eliminarDepartamento(String id) async {
    final db = await dbHelper.database;

    // Verificar si el departamento tiene equipos asignados
    final equiposResult = await db.query(
      'equipos',
      where: 'departamento_id = ? AND activo = 1',
      whereArgs: [id],
    );

    if (equiposResult.isNotEmpty) {
      throw Exception(
        'No se puede eliminar el departamento porque tiene equipos asignados. Primero reubique los equipos.',
      );
    }

    // Verificar si el departamento tiene trabajadores
    final trabajadoresResult = await db.query(
      'trabajadores',
      where: 'departamento_id = ? AND activo = 1',
      whereArgs: [id],
    );

    if (trabajadoresResult.isNotEmpty) {
      throw Exception(
        'No se puede eliminar el departamento porque tiene trabajadores asignados. Primero reubique los trabajadores.',
      );
    }

    // Eliminar el departamento
    final eliminados = await db.delete(
      'departamentos',
      where: 'id = ?',
      whereArgs: [id],
    );

    return eliminados > 0;
  }

  // Buscar departamentos por nombre
  Future<List<Departamento>> buscarDepartamentos(String busqueda) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'departamentos',
      where: 'nombre LIKE ?',
      whereArgs: ['%$busqueda%'],
      orderBy: 'nombre ASC',
    );

    return resultados.map((map) => Departamento.fromMap(map)).toList();
  }

  // Verificar si el nombre ya existe
  Future<bool> existeDepartamentoConNombre(String nombre) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'departamentos',
      where: 'nombre = ?',
      whereArgs: [nombre],
    );

    return resultados.isNotEmpty;
  }

  // Obtener estadísticas de departamentos
  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await dbHelper.database;

    final totalDepartamentos = await db.rawQuery('''
      SELECT COUNT(*) as total FROM departamentos
    ''');

    final equiposPorDepartamento = await db.rawQuery('''
      SELECT d.nombre, COUNT(e.id) as cantidad_equipos
      FROM departamentos d
      LEFT JOIN equipos e ON d.id = e.departamento_id AND e.activo = 1
      GROUP BY d.id
      ORDER BY cantidad_equipos DESC
    ''');

    final trabajadoresPorDepartamento = await db.rawQuery('''
      SELECT d.nombre, COUNT(t.id) as cantidad_trabajadores
      FROM departamentos d
      LEFT JOIN trabajadores t ON d.id = t.departamento_id AND t.activo = 1
      GROUP BY d.id
      ORDER BY cantidad_trabajadores DESC
    ''');

    return {
      'total_departamentos': totalDepartamentos.first['total'] ?? 0,
      'equipos_por_departamento': equiposPorDepartamento,
      'trabajadores_por_departamento': trabajadoresPorDepartamento,
    };
  }

  // Obtener departamentos con más equipos
  Future<List<Map<String, dynamic>>> obtenerTopDepartamentos(int limite) async {
    final db = await dbHelper.database;

    final resultados = await db.rawQuery(
      '''
      SELECT d.nombre, d.cantidad_equipos_asignados
      FROM departamentos d
      ORDER BY d.cantidad_equipos_asignados DESC
      LIMIT ?
    ''',
      [limite],
    );

    return resultados.toList();
  }

  // Actualizar contadores de un departamento
  Future<void> actualizarContadoresDepartamento(String departamentoId) async {
    final db = await dbHelper.database;

    // Contar equipos activos en el departamento
    final equiposCount = await db.rawQuery(
      '''
      SELECT COUNT(*) as cantidad 
      FROM equipos 
      WHERE departamento_id = ? AND activo = 1
    ''',
      [departamentoId],
    );

    // Contar trabajadores activos en el departamento
    final trabajadoresCount = await db.rawQuery(
      '''
      SELECT COUNT(*) as cantidad 
      FROM trabajadores 
      WHERE departamento_id = ? AND activo = 1
    ''',
      [departamentoId],
    );

    final cantidadEquipos = equiposCount.first['cantidad'] as int? ?? 0;
    final cantidadTrabajadores =
        trabajadoresCount.first['cantidad'] as int? ?? 0;

    // Actualizar departamento
    await db.update(
      'departamentos',
      {
        'cantidad_equipos_asignados': cantidadEquipos,
        'cantidad_personal': cantidadTrabajadores,
      },
      where: 'id = ?',
      whereArgs: [departamentoId],
    );
  }
}
