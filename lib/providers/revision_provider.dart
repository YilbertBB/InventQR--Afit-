import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../database/database_helper.dart';
import '../models/equipo.dart';
import '../models/revision.dart';
import '../models/equipo_revisado.dart';
import '../utils/qr_parser.dart';

class RevisionProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Revision? _revisionActual;
  List<EquipoRevisado> _equiposRevisados = [];
  List<Equipo> _equiposDepartamento = [];
  List<Revision> _historialRevisiones = [];

  bool _cargando = false;
  String? _error;

  // Getters
  Revision? get revisionActual => _revisionActual;
  List<EquipoRevisado> get equiposRevisados => _equiposRevisados;
  List<Equipo> get equiposDepartamento => _equiposDepartamento;
  List<Revision> get historialRevisiones => _historialRevisiones;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get hayRevisionActiva =>
      _revisionActual != null && _revisionActual!.estaEnCurso;

  // Estadísticas
  int get totalEquipos => _equiposDepartamento.length;
  int get equiposEscaneados => _equiposRevisados.length;
  int get equiposFaltantes => totalEquipos - equiposEscaneados;
  int get equiposFueraDeArea =>
      _equiposRevisados.where((e) => e.estaFueraDeArea).length;
  double get porcentajeProgreso =>
      totalEquipos == 0 ? 0 : (equiposEscaneados / totalEquipos) * 100;

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
  // INICIAR NUEVA REVISIÓN
  // ============================================

  Future<bool> iniciarRevision({
    required String departamentoId,
    required String departamentoNombre,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      // 1. Obtener usuario actual
      final usuario = await _getUsuarioActual();

      // 2. Cargar equipos del departamento
      await cargarEquiposDepartamento(departamentoId);

      // 3. Crear nueva revisión
      final revision = Revision(
        id: Revision.generarId(),
        departamentoId: departamentoId,
        departamentoNombre: departamentoNombre,
        usuarioAuditorId: usuario['id']!,
        usuarioAuditorNombre: usuario['nombre'],
        fechaRevision: DateTime.now(),
        estado: 'en_curso',
        totalEquipos: _equiposDepartamento.length,
      );

      final db = await _dbHelper.database;
      await db.insert('revisiones', revision.toMap());

      _revisionActual = revision;
      _equiposRevisados = [];

      debugPrint('✅ Revisión iniciada: ${revision.id} - $departamentoNombre');

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al iniciar revisión: ${e.toString()}';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================
  // CARGAR EQUIPOS DEL DEPARTAMENTO
  // ============================================

  Future<void> cargarEquiposDepartamento(String departamentoId) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'equipos',
        where: 'departamento_id = ? AND activo = 1',
        whereArgs: [departamentoId],
        orderBy: 'nombre ASC',
      );

      _equiposDepartamento = resultados
          .map((map) => Equipo.fromMap(map))
          .toList();

      debugPrint('📦 Equipos cargados: ${_equiposDepartamento.length}');
      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando equipos: $e');
    }
  }

  // ============================================
  // REGISTRAR EQUIPO ESCANEADO
  // ============================================
  Future<bool> registrarEquipoEscaneado({
    required String
    codigoEscaneado, // El QR escaneado (puede ser viejo formato)
    bool encontrado = true,
    String? observaciones,
  }) async {
    if (_revisionActual == null) {
      _error = 'No hay una revisión activa';
      return false;
    }

    try {
      // 1. Parsear el QR (maneja formato viejo)
      final parsedQR = QRParser.parseViejoFormato(codigoEscaneado);
      final codigoBusqueda = QRParser.getCodigoBusqueda(codigoEscaneado);

      debugPrint('📱 QR Parseado: $parsedQR');
      debugPrint('🔍 Código de búsqueda: $codigoBusqueda');

      // 2. Buscar el equipo por código QR
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'equipos',
        where: 'codigo_qr LIKE ? AND activo = 1',
        whereArgs: ['%$codigoBusqueda%'], // Búsqueda flexible
      );

      Equipo? equipoEncontrado;
      if (resultados.isNotEmpty) {
        equipoEncontrado = Equipo.fromMap(resultados.first);
      }

      // 3. Caso 1: El equipo existe en BD
      if (equipoEncontrado != null) {
        // Verificar si ya fue escaneado
        if (_equiposRevisados.any((e) => e.equipoId == equipoEncontrado!.id)) {
          _error = 'Este equipo ya fue registrado';
          return false;
        }

        // Determinar si está en el departamento correcto
        final enAreaCorrecta =
            equipoEncontrado.departamentoId == _revisionActual!.departamentoId;

        // Determinar si es equipo foráneo
        final esEquipoForaneo =
            equipoEncontrado.departamentoId != _revisionActual!.departamentoId;

        final equipoRevisado = EquipoRevisado(
          id: EquipoRevisado.generarId(),
          revisionId: _revisionActual!.id,
          equipoId: equipoEncontrado.id,
          nombreEquipo: equipoEncontrado.nombre,
          codigoQR: codigoEscaneado,
          encontrado: true,
          enAreaCorrecta: enAreaCorrecta,
          esEquipoForaneo: esEquipoForaneo,
          observaciones: observaciones,
          fechaEscaneo: DateTime.now(),
          trabajadorAsignado: equipoEncontrado.trabajadorNombre,
        );

        await db.insert('equipos_revisados', equipoRevisado.toMap());
        _equiposRevisados.add(equipoRevisado);

        debugPrint('✅ Equipo registrado: ${equipoEncontrado.nombre}');
        if (esEquipoForaneo) {
          debugPrint('⚠️ Equipo de otro departamento!');
        }
      }
      // 4. Caso 2: Equipo no existe en BD (QR nuevo o desconocido)
      else {
        // Verificar si ya se escaneó este código
        if (_equiposRevisados.any((e) => e.codigoQR == codigoEscaneado)) {
          _error = 'Este código QR ya fue registrado';
          return false;
        }

        // Registrar como equipo desconocido
        final equipoRevisado = EquipoRevisado(
          id: EquipoRevisado.generarId(),
          revisionId: _revisionActual!.id,
          equipoId: 'desconocido-${DateTime.now().millisecondsSinceEpoch}',
          nombreEquipo: parsedQR['nombre'] ?? 'EQUIPO DESCONOCIDO',
          codigoQR: codigoEscaneado,
          encontrado: true,
          enAreaCorrecta: false,
          esEquipoForaneo:
              true, // Se considera foráneo porque no está en BD del depto
          observaciones: observaciones ?? 'QR no registrado en base de datos',
          fechaEscaneo: DateTime.now(),
          trabajadorAsignado: null,
        );

        await db.insert('equipos_revisados', equipoRevisado.toMap());
        _equiposRevisados.add(equipoRevisado);

        debugPrint('⚠️ QR no registrado en BD: $codigoEscaneado');
      }

      // Actualizar todos los contadores
      await _actualizarContadoresCompletos();

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al registrar equipo: ${e.toString()}';
      debugPrint('❌ $_error');
      return false;
    }
  }

  // ============================================
  // ACTUALIZAR CONTADORES COMPLETOS (MEJORADO)
  // ============================================

  Future<void> _actualizarContadoresCompletos() async {
    if (_revisionActual == null) return;

    try {
      final db = await _dbHelper.database;

      // Calcular todos los tipos
      final equiposCorrectos = _equiposRevisados
          .where((e) => e.esEquipoCorrecto)
          .length;

      final equiposFaltantes = _equiposRevisados
          .where((e) => e.esEquipoFaltante)
          .length;

      final equiposSobrantes = _equiposRevisados
          .where((e) => e.esEquipoSobrante)
          .length;

      final equiposEncontrados = equiposCorrectos + equiposSobrantes;

      await db.update(
        'revisiones',
        {
          'equipos_encontrados': equiposEncontrados,
          'equipos_faltantes': equiposFaltantes,
          'equipos_sobrantes': equiposSobrantes,
          'equipos_correctos': equiposCorrectos,
        },
        where: 'id = ?',
        whereArgs: [_revisionActual!.id],
      );

      _revisionActual = _revisionActual!.copyWith(
        equiposEncontrados: equiposEncontrados,
        equiposFaltantes: equiposFaltantes,
        equiposSobrantes: equiposSobrantes,
        equiposCorrectos: equiposCorrectos,
      );

      notifyListeners();
    } catch (e) {
      debugPrint('Error actualizando contadores: $e');
    }
  }

  // ============================================
  // REGISTRAR EQUIPO FALTANTE (MANUAL)
  // ============================================

  // Future<bool> registrarEquipoFaltante(Equipo equipo) async {
  //   return registrarEquipoEscaneado(
  //     equipoId: equipo.id,
  //     codigoQR: equipo.codigoQR,
  //     encontrado: false,
  //     codigoEscaneado: ,
  //     enAreaCorrecta: false,
  //     observaciones: 'Equipo no encontrado durante la revisión',
  //   );
  // }

  // ============================================
  // ACTUALIZAR CONTADORES DE LA REVISIÓN
  // ============================================

  // Future<void> _actualizarContadoresRevision() async {x

  // ============================================
  // FINALIZAR REVISIÓN
  // ============================================

  Future<bool> finalizarRevision({String? observaciones}) async {
    if (_revisionActual == null) {
      _error = 'No hay una revisión activa';
      return false;
    }

    _cargando = true;
    notifyListeners();

    try {
      final db = await _dbHelper.database;

      await db.update(
        'revisiones',
        {
          'estado': 'completada',
          'fecha_finalizacion': DateTime.now().toIso8601String(),
          'observaciones': observaciones,
        },
        where: 'id = ?',
        whereArgs: [_revisionActual!.id],
      );

      _revisionActual = _revisionActual!.copyWith(
        estado: 'completada',
        fechaFinalizacion: DateTime.now(),
        observaciones: observaciones,
      );

      debugPrint('✅ Revisión finalizada: ${_revisionActual!.id}');

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al finalizar revisión: ${e.toString()}';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================
  // CANCELAR REVISIÓN
  // ============================================

  Future<bool> cancelarRevision() async {
    if (_revisionActual == null) return false;

    try {
      final db = await _dbHelper.database;

      await db.update(
        'revisiones',
        {
          'estado': 'cancelada',
          'fecha_finalizacion': DateTime.now().toIso8601String(),
        },
        where: 'id = ?',
        whereArgs: [_revisionActual!.id],
      );

      _revisionActual = null;
      _equiposRevisados = [];
      _equiposDepartamento = [];

      debugPrint('❌ Revisión cancelada');
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('Error cancelando revisión: $e');
      return false;
    }
  }

  // ============================================
  // LIMPIAR REVISIÓN ACTUAL
  // ============================================

  void limpiarRevisionActual() {
    _revisionActual = null;
    _equiposRevisados = [];
    _equiposDepartamento = [];
    notifyListeners();
  }

  // ============================================
  // CARGAR HISTORIAL DE REVISIONES
  // ============================================

  Future<void> cargarHistorialRevisiones() async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'revisiones',
        orderBy: 'fecha_revision DESC',
        limit: 50,
      );

      _historialRevisiones = resultados
          .map((map) => Revision.fromMap(map))
          .toList();

      notifyListeners();
    } catch (e) {
      debugPrint('Error cargando historial: $e');
    }
  }

  // ============================================
  // REANUDAR REVISIÓN EN CURSO
  // ============================================

  Future<bool> reanudarRevision(String revisionId) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'revisiones',
        where: 'id = ?',
        whereArgs: [revisionId],
        limit: 1,
      );

      if (resultados.isEmpty) {
        _error = 'Revisión no encontrada';
        return false;
      }

      final revision = Revision.fromMap(resultados.first);
      if (!revision.estaEnCurso) {
        _error = 'La revisión no está en progreso';
        return false;
      }

      await cargarEquiposDepartamento(revision.departamentoId);

      final revisados = await db.query(
        'equipos_revisados',
        where: 'revision_id = ?',
        whereArgs: [revisionId],
        orderBy: 'fecha_escaneo DESC',
      );

      _equiposRevisados =
          revisados.map((map) => EquipoRevisado.fromMap(map)).toList();
      _revisionActual = revision;

      notifyListeners();
      return true;
    } catch (e) {
      _error = 'Error al reanudar revisión: ${e.toString()}';
      debugPrint('❌ $_error');
      return false;
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  // ============================================
  // OBTENER REVISIONES POR DEPARTAMENTO
  // ============================================

  Future<List<Revision>> obtenerRevisionesPorDepartamento(
    String departamentoId,
  ) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'revisiones',
        where: 'departamento_id = ?',
        whereArgs: [departamentoId],
        orderBy: 'fecha_revision DESC',
      );

      return resultados.map((map) => Revision.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error cargando revisiones: $e');
      return [];
    }
  }

  // ============================================
  // OBTENER REPORTE COMPLETO DE LA REVISIÓN ACTUAL
  // ============================================

  Map<String, dynamic> obtenerReporteActual() {
    if (_revisionActual == null) return {};

    final equiposCorrectosList = _equiposRevisados
        .where((e) => e.esEquipoCorrecto)
        .toList();

    final equiposFaltantesList = _equiposDepartamento
        .where(
          (equipo) => !_equiposRevisados.any((e) => e.equipoId == equipo.id),
        )
        .toList();

    final equiposSobrantesList = _equiposRevisados
        .where((e) => e.esEquipoSobrante)
        .toList();

    return {
      'revision': _revisionActual,
      'correctos': equiposCorrectosList,
      'faltantes': equiposFaltantesList,
      'sobrantes': equiposSobrantesList,
      'resumen': {
        'total_depto': _equiposDepartamento.length,
        'total_escaneados': _equiposRevisados.length,
        'correctos': equiposCorrectosList.length,
        'faltantes': equiposFaltantesList.length,
        'sobrantes': equiposSobrantesList.length,
        'porcentaje': totalEquipos == 0
            ? 0
            : ((equiposCorrectosList.length / totalEquipos) * 100),
      },
    };
  }

  // ============================================
  // MÉTODO PARA REGISTRO MANUAL (SIN ESCANEO)
  // ============================================

  Future<bool> registrarEquipoManual(String codigoQR) {
    return registrarEquipoEscaneado(codigoEscaneado: codigoQR);
  }

  // ============================================
  // OBTENER EQUIPOS REVISADOS POR REVISIÓN
  // ============================================

  Future<List<EquipoRevisado>> obtenerEquiposRevisados(
    String revisionId,
  ) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'equipos_revisados',
        where: 'revision_id = ?',
        whereArgs: [revisionId],
        orderBy: 'fecha_escaneo DESC',
      );

      return resultados.map((map) => EquipoRevisado.fromMap(map)).toList();
    } catch (e) {
      debugPrint('Error cargando equipos revisados: $e');
      return [];
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
