import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../database/database_helper.dart';
import '../models/equipo.dart';
import '../models/trabajador.dart';

class EquipoProvider extends ChangeNotifier {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;
  final String _instanceId = DateTime.now().millisecondsSinceEpoch.toString();

  List<Equipo> _equipos = [];
  List<Equipo> _equiposFiltrados = [];
  String? _error;
  bool _cargando = false;

  // Filtros
  String? _filtroEstado;
  String? _filtroTipo;
  String? _filtroDepartamento;
  String? _terminoBusqueda;

  // ============================================
  // GETTERS
  // ============================================

  // List<Equipo> get equipos {
  //   debugPrint(
  //     'ðŸ” get equipos llamado en instancia $_instanceId - devolviendo ${_equipos.length}',
  //   );
  //   return _filtrosActivos ? _equiposFiltrados : _equipos;
  // }

  List<Equipo> get equipos {
    if (_filtrosActivos && _equiposFiltrados.isNotEmpty) {
      return _equiposFiltrados;
    }
    return _equipos;
  }

  String? get error => _error;
  bool get cargando => _cargando;
  bool get _filtrosActivos =>
      _filtroEstado != null ||
      _filtroTipo != null ||
      _filtroDepartamento != null ||
      (_terminoBusqueda?.isNotEmpty ?? false);

  EquipoProvider() {
    debugPrint('ðŸ†• INSTANCIA CREADA: $_instanceId');
  }

  // ============================================
  // CRUD PRINCIPAL
  // ============================================

  /// Cargar todos los equipos activos
  Future<void> cargarEquipos() async {
    debugPrint(
      'ðŸ“ž cargarEquipos() llamado en instancia $_instanceId - estado actual: ${_equipos.length}',
    );

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'equipos',
        where: 'activo = ?',
        whereArgs: [1],
        orderBy: 'fecha_creacion DESC',
      );

      _equipos = result.map((map) => Equipo.fromMap(map)).toList();
      _aplicarFiltrosLocal();

      debugPrint(
        'ðŸ“Š Resultado BD en instancia $_instanceId: ${_equipos.length} equipos',
      );
    } catch (e) {
      _error = 'Error al cargar equipos: ${e.toString()}';
      debugPrint('âŒ Error cargando equipos en instancia $_instanceId: $e');
    } finally {
      _cargando = false;
      notifyListeners();
    }
  }

  /// Crear nuevo equipo
  Future<bool> crearEquipo(Equipo equipo) async {
    debugPrint('ðŸ“ crearEquipo() llamado en instancia $_instanceId');

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;

      // Verificar si el cÃ³digo QR ya existe
      final existente = await db.query(
        'equipos',
        where: 'codigo_qr = ?',
        whereArgs: [equipo.codigoQR],
      );

      if (existente.isNotEmpty) {
        final activoExistente = (existente.first['activo'] as int? ?? 1) == 1;
        _error = activoExistente
            ? 'Ya existe un equipo con este c\u00f3digo QR'
            : 'Ya existe un equipo inactivo con este c\u00f3digo QR. React\u00edvalo o usa otro c\u00f3digo.';
        return false;
      }

      await db.insert('equipos', equipo.toMap());

      // Actualizar contador de equipos en departamento
      await _actualizarContadorDepartamento(equipo.departamentoId);

      // Recargar equipos
      await cargarEquipos();

      return true;
    } catch (e) {
      _error = 'Error al crear equipo: ${e.toString()}';
      debugPrint('âŒ Error creando equipo en instancia $_instanceId: $e');
      return false;
    } finally {
      _cargando = false;
    }
  }

  /// Actualizar equipo existente
  Future<bool> actualizarEquipo(Equipo equipo) async {
    debugPrint('ðŸ“ actualizarEquipo() llamado en instancia $_instanceId');

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;

      // Obtener equipo anterior para saber si cambiÃ³ de departamento
      final equipoAnterior = await db.query(
        'equipos',
        where: 'id = ?',
        whereArgs: [equipo.id],
      );

      if (equipoAnterior.isEmpty) {
        _error = 'Equipo no encontrado';
        return false;
      }

      // Verificar si el cÃ³digo QR ya existe en OTRO equipo
      final existente = await db.query(
        'equipos',
        where: 'codigo_qr = ? AND id != ?',
        whereArgs: [equipo.codigoQR, equipo.id],
      );

      if (existente.isNotEmpty) {
        _error = 'Ya existe otro equipo con este cÃ³digo QR';
        return false;
      }

      await db.update(
        'equipos',
        equipo.toMap(),
        where: 'id = ?',
        whereArgs: [equipo.id],
      );

      // Actualizar contadores si cambiÃ³ de departamento
      if (equipoAnterior.isNotEmpty) {
        final anterior = Equipo.fromMap(equipoAnterior.first);
        if (anterior.departamentoId != equipo.departamentoId) {
          await _actualizarContadorDepartamento(anterior.departamentoId);
          await _actualizarContadorDepartamento(equipo.departamentoId);
        } else {
          await _actualizarContadorDepartamento(equipo.departamentoId);
        }
      }

      await cargarEquipos();
      return true;
    } catch (e) {
      _error = 'Error al actualizar equipo: ${e.toString()}';
      debugPrint('âŒ Error actualizando equipo en instancia $_instanceId: $e');
      return false;
    } finally {
      _cargando = false;
      // cargarEquipos() ya notifica
    }
  }

  /// Eliminar equipo (borrado lÃ³gico si tiene historial)
  Future<bool> eliminarEquipo(String equipoId) async {
    debugPrint('ðŸ—‘ï¸ eliminarEquipo() llamado en instancia $_instanceId');

    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final db = await _dbHelper.database;

      // Obtener informaciÃ³n del equipo antes de eliminarlo
      final equipoData = await db.query(
        'equipos',
        where: 'id = ?',
        whereArgs: [equipoId],
      );

      if (equipoData.isEmpty) {
        _error = 'Equipo no encontrado';
        return false;
      }

      final equipo = Equipo.fromMap(equipoData.first);
      final departamentoId = equipo.departamentoId;

      // Verificar si tiene asignaciones
      final asignaciones = await db.query(
        'asignaciones',
        where: 'equipo_id = ?',
        whereArgs: [equipoId],
      );

      if (asignaciones.isNotEmpty) {
        // Si tiene historial, hacer borrado lÃ³gico
        await db.update(
          'equipos',
          {'activo': 0},
          where: 'id = ?',
          whereArgs: [equipoId],
        );
      } else {
        // Si no tiene historial, borrado fÃ­sico
        await db.delete('equipos', where: 'id = ?', whereArgs: [equipoId]);
      }

      // Actualizar contador del departamento
      await _actualizarContadorDepartamento(departamentoId);

      await cargarEquipos();
      return true;
    } catch (e) {
      _error = 'Error al eliminar equipo: ${e.toString()}';
      debugPrint('âŒ Error eliminando equipo en instancia $_instanceId: $e');
      return false;
    } finally {
      _cargando = false;
      // cargarEquipos() ya notifica
    }
  }

  // ============================================
  // BÃšSQUEDA Y FILTROS
  // ============================================

  /// Buscar equipos por tÃ©rmino
  Future<List<Equipo>> buscarEquipos(String termino) async {
    _terminoBusqueda = termino;

    if (termino.isEmpty) {
      _aplicarFiltrosLocal();
      notifyListeners();
      return _equipos;
    }

    try {
      final db = await _dbHelper.database;
      final resultados = await db.query(
        'equipos',
        where: '''
          activo = 1 AND (
            nombre LIKE ? OR 
            codigo_qr LIKE ? OR 
            numero_serie LIKE ? OR
            departamento_nombre LIKE ? OR
            trabajador_nombre LIKE ? OR
            proyecto_nombre LIKE ? OR
            marca LIKE ? OR
            modelo LIKE ?
          )
        ''',
        whereArgs: [
          '%$termino%',
          '%$termino%',
          '%$termino%',
          '%$termino%',
          '%$termino%',
          '%$termino%',
          '%$termino%',
          '%$termino%',
        ],
        orderBy: 'fecha_creacion DESC',
      );

      final equiposEncontrados = resultados
          .map((map) => Equipo.fromMap(map))
          .toList();

      _equiposFiltrados = equiposEncontrados;
      _aplicarFiltrosLocal();
      notifyListeners();

      return equiposEncontrados;
    } catch (e) {
      debugPrint('Error buscando equipos: $e');
      return [];
    }
  }

  /// Aplicar filtros
  void aplicarFiltros({String? estado, String? tipo, String? departamento}) {
    _filtroEstado = estado;
    _filtroTipo = tipo;
    _filtroDepartamento = departamento;
    _aplicarFiltrosLocal();
    notifyListeners();
  }

  void _aplicarFiltrosLocal() {
    List<Equipo> base = _terminoBusqueda?.isNotEmpty ?? false
        ? _equiposFiltrados
        : _equipos;

    _equiposFiltrados = base.where((equipo) {
      // Filtro por estado
      if (_filtroEstado != null &&
          _filtroEstado!.toLowerCase() != 'todos' &&
          equipo.estado.toLowerCase() != _filtroEstado!.toLowerCase()) {
        return false;
      }

      // Filtro por tipo
      if (_filtroTipo != null &&
          equipo.tipo.toLowerCase() != _filtroTipo!.toLowerCase()) {
        return false;
      }

      // Filtro por departamento
      if (_filtroDepartamento != null &&
          equipo.departamentoId != _filtroDepartamento) {
        return false;
      }

      return true;
    }).toList();
  }

  void limpiarFiltros() {
    _filtroEstado = null;
    _filtroTipo = null;
    _filtroDepartamento = null;
    _terminoBusqueda = null;
    _equiposFiltrados = [];
    notifyListeners();
  }

  // ============================================
  // MÃ‰TODOS PARA TRABAJADORES
  // ============================================

  /// Obtener trabajadores por departamento
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
      debugPrint('Error obteniendo trabajadores por departamento: $e');
      return [];
    }
  }

  // ============================================
  // MÃ‰TODOS AUXILIARES
  // ============================================

  /// Actualizar contador de equipos en departamento
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

  /// Obtener equipo por ID
  Future<Equipo?> obtenerEquipoPorId(String id) async {
    try {
      final db = await _dbHelper.database;
      final result = await db.query(
        'equipos',
        where: 'id = ? AND activo = ?',
        whereArgs: [id, 1],
      );

      if (result.isNotEmpty) {
        return Equipo.fromMap(result.first);
      }
      return null;
    } catch (e) {
      debugPrint('Error obteniendo equipo: $e');
      return null;
    }
  }

  // ============================================
  // SISTEMA DE GENERACIÃ“N DE QR
  // ============================================

  /// Generar cÃ³digo QR Ãºnico
  Future<String> generarCodigoQRUnico() async {
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecond;
    final codigo = 'EQ-$timestamp-$random';

    final disponible = await codigoQRDisponible(codigo);
    if (disponible) return codigo;

    return 'EQ-${DateTime.now().millisecondsSinceEpoch}-${DateTime.now().microsecond}${DateTime.now().second}';
  }

  /// Verificar disponibilidad de cÃ³digo QR
  Future<bool> codigoQRDisponible(String codigoQR, [String? equipoId]) async {
    try {
      final db = await _dbHelper.database;

      String where;
      List<dynamic> whereArgs;

      if (equipoId != null) {
        where = 'codigo_qr = ? AND id != ?';
        whereArgs = [codigoQR, equipoId];
      } else {
        where = 'codigo_qr = ?';
        whereArgs = [codigoQR];
      }

      final existente = await db.query(
        'equipos',
        where: where,
        whereArgs: whereArgs,
      );

      return existente.isEmpty;
    } catch (e) {
      debugPrint('Error verificando cÃ³digo QR: $e');
      return false;
    }
  }

  /// QR con formato de inventario secuencial
  Future<String> generarQRInventario({String prefijo = 'INV'}) async {
    final now = DateTime.now();
    final anio = now.year;
    final mes = now.month.toString().padLeft(2, '0');

    try {
      final db = await _dbHelper.database;
      final resultado = await db.rawQuery('''
        SELECT codigo_qr FROM equipos 
        WHERE codigo_qr LIKE '${prefijo.toUpperCase()}-$anio-$mes-%'
        ORDER BY codigo_qr DESC LIMIT 1
      ''');

      int siguiente = 1;

      if (resultado.isNotEmpty) {
        final ultimoQR = resultado.first['codigo_qr'] as String;
        final partes = ultimoQR.split('-');
        if (partes.length >= 4) {
          final ultimoNumero = int.tryParse(partes[3]) ?? 0;
          siguiente = ultimoNumero + 1;
        }
      }

      final secuencia = siguiente.toString().padLeft(4, '0');
      return '${prefijo.toUpperCase()}-$anio-$mes-$secuencia';
    } catch (e) {
      debugPrint('Error generando QR inventario: $e');
      return 'INV-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// QR con UUID v4
  String generarQRUUID() => const Uuid().v4();

  /// QR numÃ©rico simple secuencial
  Future<String> generarQRNumerico({int longitud = 6}) async {
    try {
      final db = await _dbHelper.database;
      final resultados = await db.query('equipos');

      int maxNumero = 0;

      for (var equipo in resultados) {
        final qr = equipo['codigo_qr'] as String;
        if (RegExp(r'^\d+$').hasMatch(qr)) {
          final numero = int.tryParse(qr) ?? 0;
          if (numero > maxNumero) maxNumero = numero;
        }
      }

      return (maxNumero + 1).toString().padLeft(longitud, '0');
    } catch (e) {
      debugPrint('Error generando QR numÃ©rico: $e');
      return '1'.padLeft(longitud, '0');
    }
  }

  /// QR con timestamp
  String generarQRTimestamp() {
    final now = DateTime.now();
    final fecha =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final hora =
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}${now.second.toString().padLeft(2, '0')}';
    return 'QR-$fecha-$hora';
  }

  /// QR semÃ¡ntico basado en tipo y nombre
  Future<String> generarQRSemantico({
    required String tipo,
    required String? proyecto,
    String? departamento,
  }) async {
    String tipoAbr = tipo.length > 4
        ? tipo.substring(0, 4).toUpperCase()
        : tipo.toUpperCase();

    String? ubicacion;
    if (proyecto != null && proyecto.isNotEmpty) {
      ubicacion = proyecto.replaceAll(' ', '').toUpperCase();
      if (ubicacion.length > 6) ubicacion = ubicacion.substring(0, 6);
    } else if (departamento != null && departamento.isNotEmpty) {
      ubicacion = departamento.replaceAll(' ', '').toUpperCase();
      if (ubicacion.length > 6) ubicacion = ubicacion.substring(0, 6);
    } else {
      ubicacion = 'GEN';
    }

    try {
      final db = await _dbHelper.database;
      final patron = '$tipoAbr-$ubicacion-%';
      final resultados = await db.query(
        'equipos',
        where: 'codigo_qr LIKE ?',
        whereArgs: [patron],
      );

      int maxNumero = 0;

      for (var equipo in resultados) {
        final qr = equipo['codigo_qr'] as String;
        final partes = qr.split('-');
        if (partes.length >= 3) {
          final ultimoNumero = int.tryParse(partes[2]) ?? 0;
          if (ultimoNumero > maxNumero) maxNumero = ultimoNumero;
        }
      }

      final secuencia = (maxNumero + 1).toString().padLeft(3, '0');
      return '$tipoAbr-$ubicacion-$secuencia';
    } catch (e) {
      debugPrint('Error generando QR semÃ¡ntico: $e');
      return '$tipoAbr-${DateTime.now().millisecondsSinceEpoch}';
    }
  }

  /// QR recomendado segÃºn contexto
  Future<String> generarQRRecomendado({
    String? tipo,
    String? proyecto,
    String? departamento,
  }) async {
    try {
      if (tipo != null && tipo.isNotEmpty) {
        return await generarQRSemantico(
          tipo: tipo,
          proyecto: proyecto,
          departamento: departamento,
        );
      }

      final qrInventario = await generarQRInventario();
      final disponible = await codigoQRDisponible(qrInventario);

      if (disponible) return qrInventario;

      return generarQRUUID();
    } catch (e) {
      debugPrint('Error generando QR recomendado: $e');
      return generarQRUUID();
    }
  }

  // ============================================
  // ESTADÃSTICAS Y DEBUG
  // ============================================

  /// Obtener estadÃ­sticas rÃ¡pidas
  Map<String, dynamic> obtenerEstadisticasRapidas() {
    final total = _equipos.length;
    final asignados = _equipos.where((e) => e.estaAsignado).length;
    final disponibles = _equipos
        .where((e) => !e.estaAsignado && e.estado.toLowerCase() == 'activo')
        .length;
    final enEspera = _equipos
        .where((e) => e.estado.toLowerCase() == 'en espera')
        .length;
    final mantenimiento = _equipos
        .where((e) => e.estado.toLowerCase() == 'mantenimiento')
        .length;
    final baja = _equipos.where((e) => e.estado.toLowerCase() == 'baja').length;

    return {
      'total': total,
      'asignados': asignados,
      'disponibles': disponibles,
      'en_espera': enEspera,
      'mantenimiento': mantenimiento,
      'baja': baja,
    };
  }

  /// Debug del estado
  void debugEstado() {
    debugPrint('ðŸ“Š Estado del Provider $_instanceId:');
    debugPrint('   - equipos: ${_equipos.length}');
    debugPrint('   - cargando: $_cargando');
    debugPrint('   - error: $_error');
    debugPrint('   - filtros activos: $_filtrosActivos');
  }

  /// Limpiar error
  void limpiarError() {
    _error = null;
    notifyListeners();
  }
}

