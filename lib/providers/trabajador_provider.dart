import 'package:flutter/material.dart';
import '../database/database_helper.dart';
import '../models/trabajador.dart';

class TrabajadorProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Trabajador> _trabajadores = [];
  bool _cargando = false;
  String? _error;

  List<Trabajador> get trabajadores => _trabajadores;
  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarTrabajadores() async {
    try {
      _cargando = true;
      notifyListeners();

      final db = await _dbHelper.database;
      final resultados = await db.query(
        'trabajadores',
        orderBy: 'apellidos ASC, nombres ASC',
      );

      _trabajadores = resultados.map((map) => Trabajador.fromMap(map)).toList();

      _cargando = false;
      _error = null;
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar trabajadores: $e';
      _cargando = false;
      notifyListeners();
    }
  }

  Future<bool> crearTrabajador(Trabajador trabajador) async {
    try {
      final db = await _dbHelper.database;

      // Verificar si DNI ya existe
      final existente = await db.query(
        'trabajadores',
        where: 'dni = ?',
        whereArgs: [trabajador.dni],
      );

      if (existente.isNotEmpty) {
        _error = 'Ya existe un trabajador con ese DNI';
        notifyListeners();
        return false;
      }

      await db.insert('trabajadores', trabajador.toMap());

      // Actualizar contador de personal en departamento
      await db.rawUpdate(
        '''
        UPDATE departamentos 
        SET cantidad_personal = (
          SELECT COUNT(*) FROM trabajadores 
          WHERE departamento_id = ? AND activo = 1
        )
        WHERE id = ?
      ''',
        [trabajador.departamentoId, trabajador.departamentoId],
      );

      // Recargar la lista
      await cargarTrabajadores();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarTrabajador(Trabajador trabajador) async {
    try {
      final db = await _dbHelper.database;

      // Obtener trabajador anterior para saber si cambió de departamento
      final trabajadorAnterior = await db.query(
        'trabajadores',
        where: 'id = ?',
        whereArgs: [trabajador.id],
      );

      if (trabajadorAnterior.isEmpty) {
        _error = 'Trabajador no encontrado';
        return false;
      }

      final anterior = Trabajador.fromMap(trabajadorAnterior.first);

      // Verificar si el DNI ya existe en otro trabajador
      final dniExistente = await db.query(
        'trabajadores',
        where: 'dni = ? AND id != ?',
        whereArgs: [trabajador.dni, trabajador.id],
      );

      if (dniExistente.isNotEmpty) {
        _error = 'Ya existe otro trabajador con ese DNI';
        notifyListeners();
        return false;
      }

      await db.update(
        'trabajadores',
        trabajador.toMap(),
        where: 'id = ?',
        whereArgs: [trabajador.id],
      );

      // Actualizar contadores de departamentos
      // Si cambió de departamento, actualizar ambos
      if (anterior.departamentoId != trabajador.departamentoId) {
        // Actualizar departamento anterior
        await db.rawUpdate(
          '''
          UPDATE departamentos 
          SET cantidad_personal = (
            SELECT COUNT(*) FROM trabajadores 
            WHERE departamento_id = ? AND activo = 1
          )
          WHERE id = ?
        ''',
          [anterior.departamentoId, anterior.departamentoId],
        );

        // Actualizar nuevo departamento
        await db.rawUpdate(
          '''
          UPDATE departamentos 
          SET cantidad_personal = (
            SELECT COUNT(*) FROM trabajadores 
            WHERE departamento_id = ? AND activo = 1
          )
          WHERE id = ?
        ''',
          [trabajador.departamentoId, trabajador.departamentoId],
        );
      }

      // Recargar la lista
      await cargarTrabajadores();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarTrabajador(String id) async {
    try {
      final db = await _dbHelper.database;

      // Obtener trabajador antes de eliminar para saber su departamento
      final trabajadorData = await db.query(
        'trabajadores',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (trabajadorData.isEmpty) {
        _error = 'Trabajador no encontrado';
        return false;
      }

      final trabajador = Trabajador.fromMap(trabajadorData.first);

      // Verificar si tiene equipos asignados
      final equiposAsignados = await db.query(
        'equipos',
        where: 'trabajador_id = ?',
        whereArgs: [id],
      );

      if (equiposAsignados.isNotEmpty) {
        _error = 'No se puede eliminar un trabajador con equipos asignados';
        notifyListeners();
        return false;
      }

      await db.delete('trabajadores', where: 'id = ?', whereArgs: [id]);

      // Actualizar contador de personal en departamento
      await db.rawUpdate(
        '''
        UPDATE departamentos 
        SET cantidad_personal = (
          SELECT COUNT(*) FROM trabajadores 
          WHERE departamento_id = ? AND activo = 1
        )
        WHERE id = ?
      ''',
        [trabajador.departamentoId, trabajador.departamentoId],
      );

      // Recargar la lista
      await cargarTrabajadores();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarEstadoTrabajador(String id, bool activo) async {
    try {
      final db = await _dbHelper.database;

      await db.update(
        'trabajadores',
        {'activo': activo ? 1 : 0},
        where: 'id = ?',
        whereArgs: [id],
      );

      // Obtener departamento del trabajador para actualizar contador
      final trabajadorData = await db.query(
        'trabajadores',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (trabajadorData.isNotEmpty) {
        final trabajador = Trabajador.fromMap(trabajadorData.first);

        // Actualizar contador de personal en departamento
        await db.rawUpdate(
          '''
          UPDATE departamentos 
          SET cantidad_personal = (
            SELECT COUNT(*) FROM trabajadores 
            WHERE departamento_id = ? AND activo = 1
          )
          WHERE id = ?
        ''',
          [trabajador.departamentoId, trabajador.departamentoId],
        );
      }

      // Recargar la lista
      await cargarTrabajadores();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<List<Trabajador>> buscarTrabajadores(String query) async {
    try {
      final db = await _dbHelper.database;

      final resultados = await db.rawQuery(
        '''
        SELECT * FROM trabajadores 
        WHERE nombres LIKE ? 
           OR apellidos LIKE ? 
           OR dni LIKE ? 
           OR cargo LIKE ?
           OR area LIKE ?
        ORDER BY apellidos ASC, nombres ASC
      ''',
        ['%$query%', '%$query%', '%$query%', '%$query%', '%$query%'],
      );

      return resultados.map((map) => Trabajador.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Trabajador>> obtenerTrabajadoresPorDepartamento(
    String departamentoId,
  ) async {
    try {
      final db = await _dbHelper.database;

      final resultados = await db.query(
        'trabajadores',
        where: 'departamento_id = ? AND activo = 1',
        whereArgs: [departamentoId],
        orderBy: 'apellidos ASC, nombres ASC',
      );

      return resultados.map((map) => Trabajador.fromMap(map)).toList();
    } catch (e) {
      return [];
    }
  }

  Future<Trabajador?> obtenerTrabajadorPorId(String id) async {
    try {
      final db = await _dbHelper.database;

      final resultados = await db.query(
        'trabajadores',
        where: 'id = ?',
        whereArgs: [id],
      );

      if (resultados.isEmpty) return null;

      return Trabajador.fromMap(resultados.first);
    } catch (e) {
      return null;
    }
  }

  // Añadir este método a lib/providers/trabajador_provider.dart

  void setResultadosBusqueda(List<Trabajador> resultados) {
    _trabajadores = resultados;
    notifyListeners();
  }

  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}
