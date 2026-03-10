import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path_provider/path_provider.dart';
import '../models/usuario.dart';

class DatabaseHelper {
  // Singleton
  DatabaseHelper._privateConstructor();
  static final DatabaseHelper instance = DatabaseHelper._privateConstructor();

  static Database? _database;

  // Configuración - VERSIÓN 1 (desde cero)
  static const String _databaseName = 'inventario_empresa.db';
  static const int _databaseVersion = 1; // ✅ VERSIÓN 1

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    Directory documentsDirectory = await getApplicationDocumentsDirectory();
    String path = join(documentsDirectory.path, _databaseName);

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onConfigure: _onConfigure,
    );
  }

  Future<void> _onConfigure(Database db) async {
    await db.execute('PRAGMA foreign_keys = ON');
  }

  Future<void> _onCreate(Database db, int version) async {
    // Crear todas las tablas en orden correcto
    await _createTablas(db);

    // Insertar datos iniciales
    await _insertDatosIniciales(db);
  }

  Future<void> _createTablas(Database db) async {
    // 1. Tabla de Departamentos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS departamentos(
        id TEXT PRIMARY KEY,
        nombre TEXT NOT NULL,
        cantidad_equipos_asignados INTEGER NOT NULL DEFAULT 0,
        cantidad_personal INTEGER NOT NULL DEFAULT 0
      )
    ''');

    // 2. Tabla de Usuarios
    await db.execute('''
      CREATE TABLE IF NOT EXISTS usuarios(
        id TEXT PRIMARY KEY,
        username TEXT UNIQUE NOT NULL,
        password_hash TEXT NOT NULL,
        nombre_completo TEXT NOT NULL,
        email TEXT,
        rol TEXT NOT NULL,
        departamento TEXT,
        telefono TEXT,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        fecha_ultimo_login TEXT,
        foto_url TEXT
      )
    ''');

    // 3. Tabla de Trabajadores
    await db.execute('''
      CREATE TABLE IF NOT EXISTS trabajadores(
        id TEXT PRIMARY KEY,
        nombres TEXT NOT NULL,
        apellidos TEXT NOT NULL,
        dni TEXT UNIQUE NOT NULL,
        cargo TEXT NOT NULL,
        departamento_id TEXT NOT NULL,
        departamento_nombre TEXT,
        area TEXT NOT NULL,
        telefono TEXT,
        email_corporativo TEXT,
        fecha_ingreso TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        fecha_creacion TEXT NOT NULL,
        usuario_creacion TEXT,
        foto_url TEXT,
        FOREIGN KEY (departamento_id) REFERENCES departamentos(id)
      )
    ''');

    // 4. Tabla de Equipos
    await db.execute('''
      CREATE TABLE IF NOT EXISTS equipos(
        id TEXT PRIMARY KEY,
        codigo_qr TEXT UNIQUE NOT NULL,
        nombre TEXT NOT NULL,
        tipo TEXT NOT NULL,
        marca TEXT NOT NULL,
        modelo TEXT NOT NULL,
        estado TEXT NOT NULL,
        numero_serie TEXT NOT NULL,
        departamento_id TEXT NOT NULL,
        departamento_nombre TEXT,
        proyecto_id TEXT,
        proyecto_nombre TEXT,
        trabajador_id TEXT,
        trabajador_nombre TEXT,
        fecha_adquisicion TEXT NOT NULL,
        fecha_asignacion TEXT,
        usuario_creacion TEXT NOT NULL,
        fecha_creacion TEXT NOT NULL,
        activo INTEGER NOT NULL DEFAULT 1,
        observaciones TEXT,
        costo REAL,
        fecha_garantia TEXT,
        FOREIGN KEY (departamento_id) REFERENCES departamentos(id),
        FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS asignaciones(
        id TEXT PRIMARY KEY,
        equipo_id TEXT NOT NULL,
        equipo_nombre TEXT NOT NULL,
        trabajador_id TEXT NOT NULL,
        trabajador_nombre TEXT NOT NULL,
        fecha_asignacion TEXT NOT NULL,
        motivo_asignacion TEXT,
        usuario_asignador TEXT NOT NULL,
        usuario_asignador_nombre TEXT,
        fecha_desasignacion TEXT,
        motivo_desasignacion TEXT,
        estado TEXT NOT NULL,
        FOREIGN KEY (equipo_id) REFERENCES equipos(id),
        FOREIGN KEY (trabajador_id) REFERENCES trabajadores(id)
      )
    ''');

    // 6. Tabla de Traslados
    await db.execute('''
      CREATE TABLE IF NOT EXISTS traslados(
        id TEXT PRIMARY KEY,
        equipo_id TEXT NOT NULL,
        equipo_nombre TEXT NOT NULL,
        desde_departamento_id TEXT NOT NULL,
        desde_departamento_nombre TEXT NOT NULL,
        hacia_departamento_id TEXT NOT NULL,
        hacia_departamento_nombre TEXT NOT NULL,
        motivo TEXT NOT NULL,
        usuario_realizador TEXT NOT NULL,
        usuario_realizador_nombre TEXT,
        fecha_traslado TEXT NOT NULL,
        observaciones TEXT,
        estado TEXT NOT NULL,
        FOREIGN KEY (equipo_id) REFERENCES equipos(id),
        FOREIGN KEY (desde_departamento_id) REFERENCES departamentos(id),
        FOREIGN KEY (hacia_departamento_id) REFERENCES departamentos(id)
      )
    ''');

    await db.execute('''
  CREATE TABLE IF NOT EXISTS revisiones(
    id TEXT PRIMARY KEY,
    departamento_id TEXT NOT NULL,
    departamento_nombre TEXT NOT NULL,
    usuario_auditor TEXT NOT NULL,
    usuario_auditor_nombre TEXT,             
    fecha_revision TEXT NOT NULL,
    fecha_finalizacion TEXT,                
    estado TEXT NOT NULL,                   
    total_equipos INTEGER NOT NULL DEFAULT 0,
    equipos_encontrados INTEGER NOT NULL DEFAULT 0,
    equipos_faltantes INTEGER NOT NULL DEFAULT 0,
    equipos_sobrantes INTEGER NOT NULL DEFAULT 0,
    equipos_correctos INTEGER NOT NULL DEFAULT 0,
    observaciones TEXT,
    FOREIGN KEY (departamento_id) REFERENCES departamentos(id)
  )
''');

    // 8. Tabla de Equipos Revisados - VERSIÓN ACTUALIZADA
    await db.execute('''
  CREATE TABLE IF NOT EXISTS equipos_revisados(
    id TEXT PRIMARY KEY,
    revision_id TEXT NOT NULL,
    equipo_id TEXT NOT NULL,
    nombre_equipo TEXT NOT NULL,
    codigo_qr TEXT NOT NULL,
    encontrado INTEGER NOT NULL DEFAULT 0,
    en_area_correcta INTEGER NOT NULL DEFAULT 1,
    es_equipo_foraneo INTEGER NOT NULL DEFAULT 0,
    observaciones TEXT,
    fecha_escaneo TEXT NOT NULL,
    trabajador_asignado TEXT,               
    FOREIGN KEY (revision_id) REFERENCES revisiones(id),
    FOREIGN KEY (equipo_id) REFERENCES equipos(id)
  )
''');

    // 9. Tabla de Configuración
    await db.execute('''
      CREATE TABLE IF NOT EXISTS configuracion(
        clave TEXT PRIMARY KEY,
        valor TEXT NOT NULL,
        fecha_actualizacion TEXT NOT NULL
      )
    ''');
  }

  Future<void> _insertDatosIniciales(Database db) async {
    final ahora = DateTime.now().toIso8601String();

    // 1. Insertar usuario root
    await _insertUsuarioRoot(db, ahora);

    // ✅ 2. Insertar departamento "Sin departamento" por defecto
    await _insertDepartamentoSinAsignar(db);

    // 2. Insertar configuración inicial
    await _insertConfiguracionInicial(db, ahora);
  }

  Future<void> _insertUsuarioRoot(Database db, String fechaActual) async {
    final usuarioRoot = Usuario.root();

    // Verificar si ya existe
    final existente = await db.query(
      'usuarios',
      where: 'username = ?',
      whereArgs: [usuarioRoot.username],
    );

    if (existente.isEmpty) {
      await db.insert('usuarios', usuarioRoot.toMap());
    } else {}
  }

  Future<void> _insertDepartamentoSinAsignar(Database db) async {
    try {
      // Verificar si ya existe
      final existente = await db.query(
        'departamentos',
        where: 'id = ?',
        whereArgs: ['sin-departamento'],
      );

      if (existente.isEmpty) {
        await db.insert('departamentos', {
          'id': 'sin-departamento',
          'nombre': 'Sin departamento',
          'cantidad_equipos_asignados': 0,
          'cantidad_personal': 0,
        });
      }
    } catch (e) {
      debugPrint('Error al insertar departamento "Sin departamento": $e');
    }
  }

  Future<void> _insertConfiguracionInicial(
    Database db,
    String fechaActual,
  ) async {
    final configuraciones = [
      {
        'clave': 'app_version',
        'valor': '1.0.0',
        'fecha_actualizacion': fechaActual,
      },
      {
        'clave': 'empresa_nombre',
        'valor': 'Empresa de Software S.A.',
        'fecha_actualizacion': fechaActual,
      },
      {
        'clave': 'root_eliminado',
        'valor': 'false',
        'fecha_actualizacion': fechaActual,
      },
      {
        'clave': 'exportar_path',
        'valor': '/storage/emulated/0/Download/Inventario',
        'fecha_actualizacion': fechaActual,
      },
      {
        'clave': 'ultima_sincronizacion',
        'valor': fechaActual,
        'fecha_actualizacion': fechaActual,
      },
    ];

    for (var config in configuraciones) {
      try {
        await db.insert('configuracion', config);
      } catch (e) {
        // Ignorar si ya existe
      }
    }
  }

  // ============================================
  // MÉTODOS DE UTILIDAD - CONSERVAR TODOS
  // ============================================

  Future<void> limpiarBaseDeDatos() async {
    final db = await database;
    await db.delete('equipos_revisados');
    await db.delete('revisiones');
    await db.delete('traslados');
    await db.delete('asignaciones');
    await db.delete('equipos');
    await db.delete('trabajadores');

    await db.update(
      'usuarios',
      {'activo': 0},
      where: 'username != ?',
      whereArgs: ['root'],
    );
  }

  Future<void> resetearContadores() async {
    final db = await database;
    await db.rawUpdate('''
      UPDATE departamentos 
      SET cantidad_equipos_asignados = 0, cantidad_personal = 0
    ''');
    await _recalcularContadores(db);
  }

  Future<void> _recalcularContadores(Database db) async {
    final equiposPorDepto = await db.rawQuery('''
      SELECT departamento_id, COUNT(*) as cantidad 
      FROM equipos 
      WHERE activo = 1 
      GROUP BY departamento_id
    ''');

    for (var row in equiposPorDepto) {
      await db.update(
        'departamentos',
        {'cantidad_equipos_asignados': row['cantidad']},
        where: 'id = ?',
        whereArgs: [row['departamento_id']],
      );
    }

    final trabajadoresPorDepto = await db.rawQuery('''
      SELECT departamento_id, COUNT(*) as cantidad 
      FROM trabajadores 
      WHERE activo = 1 
      GROUP BY departamento_id
    ''');

    for (var row in trabajadoresPorDepto) {
      await db.update(
        'departamentos',
        {'cantidad_personal': row['cantidad']},
        where: 'id = ?',
        whereArgs: [row['departamento_id']],
      );
    }
  }

  Future<Map<String, dynamic>> obtenerEstadisticas() async {
    final db = await database;

    final totalEquipos = await db.rawQuery('''
      SELECT COUNT(*) as total FROM equipos WHERE activo = 1
    ''');

    final equiposPorEstado = await db.rawQuery('''
      SELECT estado, COUNT(*) as cantidad 
      FROM equipos 
      WHERE activo = 1 
      GROUP BY estado
    ''');

    final equiposPorTipo = await db.rawQuery('''
      SELECT tipo, COUNT(*) as cantidad 
      FROM equipos 
      WHERE activo = 1 
      GROUP BY tipo
    ''');

    final equiposAsignados = await db.rawQuery('''
      SELECT COUNT(*) as cantidad 
      FROM equipos 
      WHERE activo = 1 AND trabajador_id IS NOT NULL
    ''');

    final totalTrabajadores = await db.rawQuery('''
      SELECT COUNT(*) as total FROM trabajadores WHERE activo = 1
    ''');

    final totalDepartamentos = await db.rawQuery('''
      SELECT COUNT(*) as total FROM departamentos
    ''');

    return {
      'total_equipos': totalEquipos.first['total'] ?? 0,
      'equipos_por_estado': equiposPorEstado,
      'equipos_por_tipo': equiposPorTipo,
      'equipos_asignados': equiposAsignados.first['cantidad'] ?? 0,
      'total_trabajadores': totalTrabajadores.first['total'] ?? 0,
      'total_departamentos': totalDepartamentos.first['total'] ?? 0,
      'fecha_consulta': DateTime.now().toIso8601String(),
    };
  }

  Future<void> backupDatabase(String filePath) async {
    final originalPath = '${await getDatabasesPath()}/$_databaseName';
    final backupFile = File(filePath);
    final originalFile = File(originalPath);

    if (await originalFile.exists()) {
      await originalFile.copy(backupFile.path);
    }
  }

  Future<void> restoreDatabase(String filePath) async {
    final backupFile = File(filePath);

    if (await backupFile.exists()) {
      final dbPath = '${await getDatabasesPath()}/$_databaseName';
      final dbFile = File(dbPath);

      await backupFile.copy(dbFile.path);

      if (_database != null) {
        await _database!.close();
        _database = null;
      }
    }
  }

  Future<void> exportarTablaCSV(String tabla, String filePath) async {
    final db = await database;
    final resultados = await db.query(tabla);

    if (resultados.isEmpty) {
      throw Exception('La tabla $tabla está vacía');
    }

    final columnas = resultados.first.keys.toList();
    final csvContent = StringBuffer();

    csvContent.writeln(columnas.join(','));

    for (var fila in resultados) {
      final valores = columnas.map((columna) {
        final valor = fila[columna];
        if (valor is String) {
          return '"${valor.replaceAll('"', '""')}"';
        }
        return valor.toString();
      }).toList();

      csvContent.writeln(valores.join(','));
    }

    final file = File(filePath);
    await file.writeAsString(csvContent.toString());
  }

  Future<bool> verificarIntegridad() async {
    try {
      final db = await database;

      final tablasEsperadas = [
        'departamentos',
        'usuarios',
        'trabajadores',
        'equipos',
        'asignaciones',
        'traslados',
        'revisiones',
        'equipos_revisados',
        'configuracion',
      ];

      for (var tabla in tablasEsperadas) {
        final resultado = await db.rawQuery(
          "SELECT name FROM sqlite_master WHERE type='table' AND name='$tabla'",
        );
        if (resultado.isEmpty) {
          return false;
        }
      }

      final root = await db.query(
        'usuarios',
        where: 'username = ? AND activo = 1',
        whereArgs: ['root'],
      );

      if (root.isEmpty) {
        return false;
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  Future<void> eliminarUsuarioRootSiHayOtrosUsuarios() async {
    final db = await database;

    final otrosUsuarios = await db.rawQuery(
      '''
      SELECT COUNT(*) as cantidad 
      FROM usuarios 
      WHERE username != ? AND activo = 1
    ''',
      ['root'],
    );

    final cantidadOtros = otrosUsuarios.first['cantidad'] as int? ?? 0;

    if (cantidadOtros > 0) {
      await db.delete('usuarios', where: 'username = ?', whereArgs: ['root']);

      await db.update(
        'configuracion',
        {
          'valor': 'true',
          'fecha_actualizacion': DateTime.now().toIso8601String(),
        },
        where: 'clave = ?',
        whereArgs: ['root_eliminado'],
      );
    }
  }
}
