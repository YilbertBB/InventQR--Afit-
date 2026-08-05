import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import '../database/database_helper.dart';
import '../models/departamento.dart';

class DepartamentoProvider with ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Departamento> _departamentos = [];
  bool _cargando = false;
  String? _error;

  List<Departamento> get departamentos =>
      _departamentos.where((d) => d.id != 'sin-departamento').toList();

  bool get cargando => _cargando;
  String? get error => _error;

  Future<void> cargarDepartamentos() async {
    try {
      _error = null;
      _cargando = true;
      notifyListeners();

      final db = await _dbHelper.database;
      final resultados = await db.query('departamentos', orderBy: 'nombre ASC');

      _departamentos = resultados
          .map((map) => Departamento.fromMap(map))
          .toList();
      _cargando = false;
      notifyListeners();
    } catch (e) {
      _error = 'Error al cargar departamentos: $e';
      _cargando = false;
      notifyListeners();
    }
  }

  // ✅ Método para verificar si un ID de departamento existe (útil para validaciones)
  Future<bool> existeDepartamento(String id) async {
    try {
      final db = await _dbHelper.database;
      final resultado = await db.query(
        'departamentos',
        where: 'id = ?',
        whereArgs: [id],
      );
      return resultado.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  // ✅ Obtener nombre del departamento (con manejo especial para sin-departamento)
  String getNombreDepartamento(String? id) {
    if (id == null || id.isEmpty || id == 'sin-departamento') {
      return ''; // No mostrar nada
    }

    final depto = _departamentos.firstWhere(
      (d) => d.id == id,
      orElse: () => Departamento(id: '', nombre: ''),
    );
    return depto.nombre;
  }

  Future<bool> crearDepartamento(String nombre) async {
    try {
      final db = await _dbHelper.database;

      // Verificar si ya existe
      final existente = await db.query(
        'departamentos',
        where: 'nombre = ?',
        whereArgs: [nombre],
      );

      if (existente.isNotEmpty) {
        throw Exception('Ya existe un departamento con ese nombre');
      }

      final nuevoDepartamento = Departamento(
        id: Departamento.generarId(),
        nombre: nombre,
        cantidadEquiposAsignados: 0,
        cantidadPersonal: 0,
      );

      await db.insert('departamentos', nuevoDepartamento.toMap());

      _error = null;
      await cargarDepartamentos();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> actualizarDepartamento(Departamento departamento) async {
    try {
      final db = await _dbHelper.database;

      await db.update(
        'departamentos',
        departamento.toMap(),
        where: 'id = ?',
        whereArgs: [departamento.id],
      );

      _error = null;
      await cargarDepartamentos();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarDepartamento(String id, {bool forzar = false}) async {
    try {
      _error = null;

      if (id == 'sin-departamento') {
        throw Exception('No se puede eliminar el departamento predeterminado.');
      }

      final db = await _dbHelper.database;

      if (!forzar) {
        final equiposCount = Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) AS count FROM equipos WHERE departamento_id = ? AND activo = 1',
                [id],
              ),
            ) ??
            0;
        if (equiposCount > 0) {
          throw Exception(
            'No se puede eliminar el departamento porque tiene equipos asignados. Primero reubique los equipos.',
          );
        }

        final trabajadoresCount = Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) AS count FROM trabajadores WHERE departamento_id = ? AND activo = 1',
                [id],
              ),
            ) ??
            0;
        if (trabajadoresCount > 0) {
          throw Exception(
            'No se puede eliminar el departamento porque tiene trabajadores asignados. Primero reubique los trabajadores.',
          );
        }

        final trasladosCount = Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) AS count FROM traslados WHERE desde_departamento_id = ? OR hacia_departamento_id = ?',
                [id, id],
              ),
            ) ??
            0;
        if (trasladosCount > 0) {
          throw Exception(
            'No se puede eliminar el departamento porque está vinculado a traslados registrados.',
          );
        }

        final revisionesCount = Sqflite.firstIntValue(
              await db.rawQuery(
                'SELECT COUNT(*) AS count FROM revisiones WHERE departamento_id = ?',
                [id],
              ),
            ) ??
            0;
        if (revisionesCount > 0) {
          throw Exception(
            'No se puede eliminar el departamento porque tiene revisiones asociadas.',
          );
        }
      }

      await db.transaction((txn) async {
        if (forzar) {
          await txn.update(
            'equipos',
            {
              'departamento_id': 'sin-departamento',
              'departamento_nombre': 'Sin departamento',
            },
            where: 'departamento_id = ?',
            whereArgs: [id],
          );

          await txn.update(
            'trabajadores',
            {
              'departamento_id': 'sin-departamento',
              'departamento_nombre': 'Sin departamento',
            },
            where: 'departamento_id = ?',
            whereArgs: [id],
          );

          await txn.update(
            'traslados',
            {
              'desde_departamento_id': 'sin-departamento',
              'desde_departamento_nombre': 'Sin departamento',
            },
            where: 'desde_departamento_id = ?',
            whereArgs: [id],
          );

          await txn.update(
            'traslados',
            {
              'hacia_departamento_id': 'sin-departamento',
              'hacia_departamento_nombre': 'Sin departamento',
            },
            where: 'hacia_departamento_id = ?',
            whereArgs: [id],
          );

          await txn.update(
            'revisiones',
            {
              'departamento_id': 'sin-departamento',
              'departamento_nombre': 'Sin departamento',
            },
            where: 'departamento_id = ?',
            whereArgs: [id],
          );
        }

        final eliminados = await txn.delete(
          'departamentos',
          where: 'id = ?',
          whereArgs: [id],
        );

        if (eliminados == 0) {
          throw Exception('No se encontró el departamento para eliminar.');
        }
      });

      await cargarDepartamentos();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
