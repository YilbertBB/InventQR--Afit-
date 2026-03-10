import 'package:flutter/material.dart';
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

      // Recargar la lista
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

      // Recargar la lista
      await cargarDepartamentos();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> eliminarDepartamento(String id) async {
    try {
      final db = await _dbHelper.database;

      await db.delete('departamentos', where: 'id = ?', whereArgs: [id]);

      // Recargar la lista
      await cargarDepartamentos();

      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }
}
