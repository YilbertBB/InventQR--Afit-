import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/asignacion.dart';
import '../models/equipo.dart';

class AsignacionProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Asignacion> _asignacionesActivas = [];
  List<Asignacion> _historialAsignaciones = [];
  bool _cargando = false;
  String? _error;

  // Getters
  List<Asignacion> get asignacionesActivas => _asignacionesActivas;
  List<Asignacion> get historialAsignaciones => _historialAsignaciones;
  bool get cargando => _cargando;
  String? get error => _error;

  // ============================================
  // OBTENER USUARIO ACTUAL DESDE SHAREDPREFERENCES
  // ============================================

  Future<Map<String, String>> _getUsuarioActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('usuario_id') ?? 'root';
      final nombre = prefs.getString('usuario_nombre') ?? 'Administrador';
      return {'id': id, 'nombre': nombre};
    } catch (e) {
      debugPrint('Error obteniendo usuario actual: $e');
      return {'id': 'root', 'nombre': 'Administrador'};
    }
  }

  // ============================================
  // ASIGNAR EQUIPO A TRABAJADOR
  // ============================================

  Future<bool> asignarEquipo({
    required String equipoId,
    required String equipoNombre,
    required String trabajadorId,
    required String trabajadorNombre,
    String? motivo,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final ahora = DateTime.now();

      // 1. Obtener usuario actual
      final usuario = await _getUsuarioActual();

      // 2. Verificar que el equipo existe y NO está asignado
      final equipo = await db.query(
        'equipos',
        where: 'id = ? AND activo = 1',
        whereArgs: [equipoId],
      );

      if (equipo.isEmpty) {
        _error = 'El equipo no existe o está inactivo';
        return false;
      }

      final equipoData = Equipo.fromMap(equipo.first);
      if (equipoData.estaAsignado) {
        _error = 'El equipo ya está asignado a otro trabajador';
        return false;
      }

      // 3. Verificar que el trabajador existe y está activo
      final trabajador = await db.query(
        'trabajadores',
        where: 'id = ? AND activo = 1',
        whereArgs: [trabajadorId],
      );

      if (trabajador.isEmpty) {
        _error = 'El trabajador no existe o está inactivo';
        return false;
      }

      // 4. TRANSACCIÓN: Actualizar equipo + crear asignación
      await db.transaction((txn) async {
        // 4.1 Actualizar equipo
        await txn.update(
          'equipos',
          {
            'trabajador_id': trabajadorId,
            'trabajador_nombre': trabajadorNombre,
            'fecha_asignacion': ahora.toIso8601String(),
          },
          where: 'id = ?',
          whereArgs: [equipoId],
        );

        // 4.2 Crear asignación
        final asignacion = Asignacion(
          id: Asignacion.generarId(),
          equipoId: equipoId,
          equipoNombre: equipoNombre,
          trabajadorId: trabajadorId,
          trabajadorNombre: trabajadorNombre,
          fechaAsignacion: ahora,
          motivoAsignacion: motivo,
          usuarioAsignadorId: usuario['id']!,
          usuarioAsignadorNombre: usuario['nombre'],
          estado: 'activa',
        );

        await txn.insert('asignaciones', asignacion.toMap());
      });

      debugPrint('✅ Asignación exitosa: $equipoNombre → $trabajadorNombre');

      // 5. Recargar datos
      await cargarAsignacionesActivas();

      return true;
    } catch (e) {
      _error = 'Error al asignar equipo: ${e.toString()}';
      debugPrint('❌ Error asignando equipo: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================
  // DESASIGNAR EQUIPO
  // ============================================

  Future<bool> desasignarEquipo({
    required String equipoId,
    String? motivo,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final ahora = DateTime.now();

      final asignacionesActivas = await db.query(
        'asignaciones',
        where: 'equipo_id = ? AND estado = ?',
        whereArgs: [equipoId, 'activa'],
      );

      if (asignacionesActivas.isEmpty) {
        _error = 'No hay asignación activa para este equipo';
        return false;
      }

      final asignacionId = asignacionesActivas.first['id'] as String;

      // 3. TRANSACCIÓN: Actualizar equipo + cerrar asignación
      await db.transaction((txn) async {
        // 3.1 Limpiar equipo
        await txn.update(
          'equipos',
          {
            'trabajador_id': null,
            'trabajador_nombre': null,
            'fecha_asignacion': null,
          },
          where: 'id = ?',
          whereArgs: [equipoId],
        );

        // 3.2 Cerrar asignación
        await txn.update(
          'asignaciones',
          {
            'fecha_desasignacion': ahora.toIso8601String(),
            'motivo_desasignacion': motivo ?? 'Desasignación manual',
            'estado': 'finalizada',
          },
          where: 'id = ?',
          whereArgs: [asignacionId],
        );
      });

      debugPrint('✅ Desasignación exitosa: $equipoId');

      // 4. Recargar datos
      await cargarAsignacionesActivas();
      await cargarHistorialAsignaciones();

      return true;
    } catch (e) {
      _error = 'Error al desasignar equipo: ${e.toString()}';
      debugPrint('❌ Error desasignando equipo: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================
  // CARGAR ASIGNACIONES ACTIVAS
  // ============================================

  Future<void> cargarAsignacionesActivas() async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'asignaciones',
        where: 'estado = ?',
        whereArgs: ['activa'],
        orderBy: 'fecha_asignacion DESC',
      );

      _asignacionesActivas = resultados
          .map((map) => Asignacion.fromMap(map))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando asignaciones activas: $e');
    }
  }

  // ============================================
  // CARGAR HISTORIAL POR EQUIPO
  // ============================================

  Future<List<Asignacion>> obtenerHistorialPorEquipo(String equipoId) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'asignaciones',
        where: 'equipo_id = ?',
        whereArgs: [equipoId],
        orderBy: 'fecha_asignacion DESC',
      );

      return resultados.map((map) => Asignacion.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error cargando historial de equipo: $e');
      return [];
    }
  }

  // ============================================
  // CARGAR HISTORIAL POR TRABAJADOR
  // ============================================

  Future<List<Asignacion>> obtenerHistorialPorTrabajador(
    String trabajadorId,
  ) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'asignaciones',
        where: 'trabajador_id = ?',
        whereArgs: [trabajadorId],
        orderBy: 'fecha_asignacion DESC',
      );

      return resultados.map((map) => Asignacion.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error cargando historial de trabajador: $e');
      return [];
    }
  }

  // ============================================
  // CARGAR HISTORIAL COMPLETO
  // ============================================

  Future<void> cargarHistorialAsignaciones() async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'asignaciones',
        orderBy: 'fecha_asignacion DESC',
        limit: 50,
      );

      _historialAsignaciones = resultados
          .map((map) => Asignacion.fromMap(map))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando historial de asignaciones: $e');
    }
  }

  // ============================================
  // OBTENER ASIGNACIÓN ACTIVA POR EQUIPO
  // ============================================

  Future<Asignacion?> obtenerAsignacionActiva(String equipoId) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'asignaciones',
        where: 'equipo_id = ? AND estado = ?',
        whereArgs: [equipoId, 'activa'],
      );

      if (resultados.isNotEmpty) {
        return Asignacion.fromMap(resultados.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo asignación activa: $e');
      return null;
    }
  }

  // ============================================
  // ESTADÍSTICAS DE ASIGNACIONES
  // ============================================

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    try {
      final db = await _dbHelper.database;

      final totalActivas = await db.rawQuery('''
        SELECT COUNT(*) as cantidad FROM asignaciones WHERE estado = 'activa'
      ''');

      final totalHistorial = await db.rawQuery('''
        SELECT COUNT(*) as cantidad FROM asignaciones
      ''');

      final asignacionesHoy = await db.rawQuery('''
        SELECT COUNT(*) as cantidad FROM asignaciones 
        WHERE date(fecha_asignacion) = date('now')
      ''');

      return {
        'activas': totalActivas.first['cantidad'] ?? 0,
        'total': totalHistorial.first['cantidad'] ?? 0,
        'hoy': asignacionesHoy.first['cantidad'] ?? 0,
      };
    } catch (e) {
      debugPrint('Error obteniendo estadísticas: $e');
      return {'activas': 0, 'total': 0, 'hoy': 0};
    }
  }

  // ============================================
  // LIMPIAR ERROR
  // ============================================

  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}
