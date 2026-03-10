import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/traslado.dart';

class TrasladoProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  List<Traslado> _historialTraslados = [];
  bool _cargando = false;
  String? _error;

  // Getters
  List<Traslado> get historialTraslados => _historialTraslados;
  bool get cargando => _cargando;
  String? get error => _error;

  // ============================================
  // OBTENER USUARIO ACTUAL
  // ============================================

  Future<Map<String, String>> _getUsuarioActual() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final id = prefs.getString('usuario_id') ?? 'root';
      final nombre = prefs.getString('usuario_nombre') ?? 'Administrador';
      return {'id': id, 'nombre': nombre};
    } catch (e) {
      return {'id': 'root', 'nombre': 'Administrador'};
    }
  }

  // ============================================
  // TRASLADAR EQUIPO
  // ============================================

  Future<bool> trasladarEquipo({
    required String equipoId,
    required String equipoNombre,
    required String desdeDepartamentoId,
    required String desdeDepartamentoNombre,
    required String haciaDepartamentoId,
    required String haciaDepartamentoNombre,
    required String motivo,
    String? observaciones,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final ahora = DateTime.now();

      // 1. Obtener usuario actual
      final usuario = await _getUsuarioActual();

      // 2. Verificar que el equipo existe y está activo
      final equipo = await db.query(
        'equipos',
        where: 'id = ? AND activo = ?',
        whereArgs: [equipoId, 1],
      );

      if (equipo.isEmpty) {
        _error = 'El equipo no existe o está inactivo';
        return false;
      }

      // 3. Verificar que los departamentos existen
      final desdeDepto = await db.query(
        'departamentos',
        where: 'id = ?',
        whereArgs: [desdeDepartamentoId],
      );

      if (desdeDepto.isEmpty) {
        _error = 'El departamento de origen no existe';
        return false;
      }

      final haciaDepto = await db.query(
        'departamentos',
        where: 'id = ?',
        whereArgs: [haciaDepartamentoId],
      );

      if (haciaDepto.isEmpty) {
        _error = 'El departamento de destino no existe';
        return false;
      }

      // 4. Verificar que no sea el mismo departamento
      if (desdeDepartamentoId == haciaDepartamentoId) {
        _error = 'El equipo ya está en ese departamento';
        return false;
      }

      // 5. TRANSACCIÓN: Actualizar equipo + crear traslado
      await db.transaction((txn) async {
        // 5.1 Actualizar equipo
        await txn.update(
          'equipos',
          {
            'departamento_id': haciaDepartamentoId,
            'departamento_nombre': haciaDepartamentoNombre,
            // NOTA: NO se modifica trabajador_id ni fecha_asignacion
          },
          where: 'id = ?',
          whereArgs: [equipoId],
        );

        // 5.2 Crear traslado
        // final traslado = Traslado(
        //   id: Traslado.generarId(),
        //   equipoId: equipoId,
        //   equipoNombre: equipoNombre,
        //   desdeDepartamentoId: desdeDepartamentoId,
        //   desdeDepartamentoNombre: desdeDepartamentoNombre,
        //   haciaDepartamentoId: haciaDepartamentoId,
        //   haciaDepartamentoNombre: haciaDepartamentoNombre,
        //   motivo: motivo,
        //   usuarioRealizadorId: usuario['id']!,
        //   fechaTraslado: ahora,
        //   observaciones: observaciones,
        //   estado: 'completado',
        // );

        await txn.insert('traslados', {
          'id': Traslado.generarId(),
          'equipo_id': equipoId,
          'equipo_nombre': equipoNombre,
          'desde_departamento_id': desdeDepartamentoId,
          'desde_departamento_nombre': desdeDepartamentoNombre,
          'hacia_departamento_id': haciaDepartamentoId,
          'hacia_departamento_nombre': haciaDepartamentoNombre,
          'motivo': motivo,
          'usuario_realizador': usuario['id']!,
          'usuario_realizador_nombre': usuario['nombre'], // 👈 GUARDAR NOMBRE
          'fecha_traslado': ahora.toIso8601String(),
          'observaciones': observaciones,
          'estado': 'completado',
        });
      });

      // 6. Actualizar contadores de ambos departamentos
      await _actualizarContadorDepartamento(desdeDepartamentoId);
      await _actualizarContadorDepartamento(haciaDepartamentoId);

      debugPrint(
        '✅ Traslado exitoso: $equipoNombre → $haciaDepartamentoNombre',
      );

      // 7. Recargar historial
      await cargarHistorialTraslados();

      return true;
    } catch (e) {
      _error = 'Error al trasladar equipo: ${e.toString()}';
      debugPrint('❌ Error trasladando equipo: $e');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================
  // OBTENER HISTORIAL POR EQUIPO
  // ============================================

  Future<List<Traslado>> obtenerHistorialPorEquipo(String equipoId) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'traslados',
        where: 'equipo_id = ?',
        whereArgs: [equipoId],
        orderBy: 'fecha_traslado DESC',
      );

      return resultados.map((map) => Traslado.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error cargando historial de traslados: $e');
      return [];
    }
  }

  // ============================================
  // OBTENER HISTORIAL POR DEPARTAMENTO
  // ============================================

  Future<List<Traslado>> obtenerHistorialPorDepartamento(
    String departamentoId,
  ) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'traslados',
        where: 'desde_departamento_id = ? OR hacia_departamento_id = ?',
        whereArgs: [departamentoId, departamentoId],
        orderBy: 'fecha_traslado DESC',
      );

      return resultados.map((map) => Traslado.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error cargando historial de departamento: $e');
      return [];
    }
  }

  // ============================================
  // CARGAR HISTORIAL COMPLETO
  // ============================================

  Future<void> cargarHistorialTraslados() async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'traslados',
        orderBy: 'fecha_traslado DESC',
        limit: 50,
      );

      _historialTraslados = resultados
          .map((map) => Traslado.fromMap(map))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando historial de traslados: $e');
    }
  }

  // ============================================
  // ACTUALIZAR CONTADOR DE DEPARTAMENTO
  // ============================================

  Future<void> _actualizarContadorDepartamento(String departamentoId) async {
    try {
      final db = await _dbHelper.database;

      await db.rawUpdate(
        '''
        UPDATE departamentos 
        SET cantidad_equipos_asignados = (
          SELECT COUNT(*) FROM equipos 
          WHERE departamento_id = ? AND activo = 1
        )
        WHERE id = ?
        ''',
        [departamentoId, departamentoId],
      );
    } catch (e) {
      debugPrint('Error actualizando contador de departamento: $e');
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
