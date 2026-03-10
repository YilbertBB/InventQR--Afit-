import '../models/departamento.dart';
import '../models/equipo.dart';
import '../database/database_helper.dart';

class EscanerQRService {
  final DatabaseHelper dbHelper;

  EscanerQRService({required this.dbHelper});

  // Procesar texto del QR
  Map<String, String> parseQRText(String qrText) {
    final lines = qrText.split('\n');
    final datos = <String, String>{};

    for (var line in lines) {
      final partes = line.split(':');
      if (partes.length >= 2) {
        final clave = partes[0].trim().toLowerCase();
        final valor = partes.sublist(1).join(':').trim();
        datos[clave] = valor;
      }
    }

    return datos;
  }

  // Procesar QR y crear/actualizar equipo
  Future<Equipo> procesarQR(String qrText, String usuarioActual) async {
    final datos = parseQRText(qrText);

    // Extraer datos
    final codigoQR =
        datos['número o id'] ?? datos['numero'] ?? datos['id'] ?? '000000';
    final estado = datos['estado']?.trim() ?? 'en espera';
    final modeloEquipo = datos['equipo']?.trim() ?? 'Desconocido';
    final areaProyecto =
        datos['área / proyecto']?.trim() ??
        datos['area']?.trim() ??
        datos['proyecto']?.trim() ??
        'Sin asignar';

    // Buscar si ya existe
    final equipoExistente = await buscarEquipoPorQR(codigoQR);

    if (equipoExistente != null) {
      // Actualizar equipo existente
      return await _actualizarEquipoDesdeQR(
        equipoExistente,
        estado,
        areaProyecto,
        usuarioActual,
      );
    } else {
      // Crear nuevo equipo
      return await _crearNuevoEquipoDesdeQR(
        codigoQR,
        estado,
        modeloEquipo,
        areaProyecto,
        usuarioActual,
      );
    }
  }

  // Buscar equipo por código QR
  Future<Equipo?> buscarEquipoPorQR(String codigoQR) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'equipos',
      where: 'codigo_qr = ? AND activo = 1',
      whereArgs: [codigoQR],
    );

    if (resultados.isEmpty) return null;
    return Equipo.fromMap(resultados.first);
  }

  // Crear nuevo equipo desde QR
  Future<Equipo> _crearNuevoEquipoDesdeQR(
    String codigoQR,
    String estado,
    String modeloEquipo,
    String areaProyecto,
    String usuarioCreacion,
  ) async {
    final db = await dbHelper.database;

    // Buscar departamento por área
    final departamento = await _buscarDepartamentoPorArea(areaProyecto);

    // Crear equipo
    final equipo = Equipo(
      id: _generarId(),
      codigoQR: codigoQR,
      nombre: '$modeloEquipo - $areaProyecto',
      tipo: _determinarTipoPorModelo(modeloEquipo),
      marca: _determinarMarcaPorModelo(modeloEquipo),
      modelo: modeloEquipo,
      estado: estado,
      numeroSerie: codigoQR,
      departamentoId: departamento?.id ?? 'dep-otro-001',
      departamentoNombre: departamento?.nombre ?? areaProyecto,
      proyectoId: 'proy-general-001',
      proyectoNombre: areaProyecto,
      fechaAdquisicion: DateTime.now(),
      usuarioCreacion: usuarioCreacion,
      fechaCreacion: DateTime.now(),
    );

    // Guardar en BD
    await db.insert('equipos', equipo.toMap());

    // Actualizar contador del departamento
    if (departamento != null) {
      await _actualizarContadorDepartamento(departamento.id);
    }

    return equipo;
  }

  // Actualizar equipo existente desde QR
  Future<Equipo> _actualizarEquipoDesdeQR(
    Equipo equipoExistente,
    String nuevoEstado,
    String nuevaArea,
    String usuarioModificador,
  ) async {
    final db = await dbHelper.database;

    // Buscar nuevo departamento si cambió el área
    Departamento? nuevoDepartamento;
    if (nuevaArea != equipoExistente.departamentoNombre) {
      nuevoDepartamento = await _buscarDepartamentoPorArea(nuevaArea);
    }

    // Crear observación de la actualización
    final observaciones =
        '''
${equipoExistente.observaciones ?? ''}
--- Actualización desde QR ---
Fecha: ${DateTime.now()}
Usuario: $usuarioModificador
Estado anterior: ${equipoExistente.estado}
Estado nuevo: $nuevoEstado
Área anterior: ${equipoExistente.departamentoNombre}
Área nueva: $nuevaArea
'''
            .trim();

    // Actualizar equipo
    final equipoActualizado = equipoExistente.copyWith(
      estado: nuevoEstado,
      departamentoId: nuevoDepartamento?.id ?? equipoExistente.departamentoId,
      departamentoNombre:
          nuevoDepartamento?.nombre ?? equipoExistente.departamentoNombre,
      observaciones: observaciones,
    );

    // Guardar en BD
    await db.update(
      'equipos',
      equipoActualizado.toMap(),
      where: 'id = ?',
      whereArgs: [equipoActualizado.id],
    );

    return equipoActualizado;
  }

  // Métodos auxiliares
  Future<Departamento?> _buscarDepartamentoPorArea(String area) async {
    final db = await dbHelper.database;

    final resultados = await db.query(
      'departamentos',
      where: 'nombre LIKE ?',
      whereArgs: ['%$area%'],
    );

    if (resultados.isNotEmpty) {
      return Departamento.fromMap(resultados.first);
    }

    return null;
  }

  Future<void> _actualizarContadorDepartamento(String departamentoId) async {
    final db = await dbHelper.database;

    final count = await db.rawQuery(
      '''
      SELECT COUNT(*) as cantidad 
      FROM equipos 
      WHERE departamento_id = ? AND activo = 1
    ''',
      [departamentoId],
    );

    final cantidad = count.first['cantidad'] as int? ?? 0;

    await db.update(
      'departamentos',
      {'cantidad_equipos_asignados': cantidad},
      where: 'id = ?',
      whereArgs: [departamentoId],
    );
  }

  String _generarId() {
    return 'eq-${DateTime.now().millisecondsSinceEpoch}';
  }

  String _determinarTipoPorModelo(String modelo) {
    final modeloLower = modelo.toLowerCase();

    if (modeloLower.contains('pc') ||
        modeloLower.contains('laptop') ||
        modeloLower.contains('desktop')) {
      return 'Computadora';
    } else if (modeloLower.contains('silla')) {
      return 'Silla';
    } else if (modeloLower.contains('mesa') ||
        modeloLower.contains('escritorio')) {
      return 'Mesa';
    } else if (modeloLower.contains('teclado')) {
      return 'Teclado';
    } else if (modeloLower.contains('monitor') ||
        modeloLower.contains('pantalla')) {
      return 'Monitor';
    } else if (modeloLower.contains('mouse') || modeloLower.contains('ratón')) {
      return 'Mouse';
    } else if (modeloLower.contains('impresora')) {
      return 'Impresora';
    } else if (modeloLower.contains('router') ||
        modeloLower.contains('switch')) {
      return 'Red';
    } else {
      return 'Otro';
    }
  }

  String _determinarMarcaPorModelo(String modelo) {
    final modeloLower = modelo.toLowerCase();

    if (modeloLower.contains('dell')) {
      return 'Dell';
    }
    if (modeloLower.contains('hp')) {
      return 'HP';
    }
    if (modeloLower.contains('lenovo')) {
      return 'Lenovo';
    }
    if (modeloLower.contains('apple') || modeloLower.contains('mac')) {
      return 'Apple';
    }
    if (modeloLower.contains('asus')) {
      return 'Asus';
    }
    if (modeloLower.contains('acer')) {
      return 'Acer';
    }
    if (modeloLower.contains('logitech')) {
      return 'Logitech';
    }
    if (modeloLower.contains('microsoft')) {
      return 'Microsoft';
    }
    if (modeloLower.contains('samsung')) {
      return 'Samsung';
    }

    return 'Desconocida';
  }
}
