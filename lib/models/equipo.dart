import 'package:uuid/uuid.dart';

class Equipo {
  final String id;
  final String codigoQR;
  final String nombre;
  final String tipo;
  final String marca;
  final String modelo;
  final String estado;
  final String numeroSerie;
  final String departamentoId;
  final String? departamentoNombre;
  final String proyectoId;
  final String? proyectoNombre;
  final String? trabajadorId;
  final String? trabajadorNombre;
  final DateTime fechaAdquisicion;
  final DateTime? fechaAsignacion;
  final String usuarioCreacion;
  final DateTime fechaCreacion;
  final bool activo;
  final String? observaciones;
  final double? costo;
  final DateTime? fechaGarantia;

  Equipo({
    required this.id,
    required this.codigoQR,
    required this.nombre,
    required this.tipo,
    required this.marca,
    required this.modelo,
    required this.estado,
    required this.numeroSerie,
    required this.departamentoId,
    this.departamentoNombre,
    required this.proyectoId,
    this.proyectoNombre,
    this.trabajadorId,
    this.trabajadorNombre,
    required this.fechaAdquisicion,
    this.fechaAsignacion,
    required this.usuarioCreacion,
    required this.fechaCreacion,
    this.activo = true,
    this.observaciones,
    this.costo,
    this.fechaGarantia,
  });

  // toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'codigo_qr': codigoQR,
      'nombre': nombre,
      'tipo': tipo,
      'marca': marca,
      'modelo': modelo,
      'estado': estado,
      'numero_serie': numeroSerie,
      'departamento_id': departamentoId,
      'departamento_nombre': departamentoNombre,
      'proyecto_id': proyectoId,
      'proyecto_nombre': proyectoNombre,
      'trabajador_id': trabajadorId,
      'trabajador_nombre': trabajadorNombre,
      'fecha_adquisicion': fechaAdquisicion.toIso8601String(),
      'fecha_asignacion': fechaAsignacion?.toIso8601String(),
      'usuario_creacion': usuarioCreacion,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'activo': activo ? 1 : 0,
      'observaciones': observaciones,
      'costo': costo,
      'fecha_garantia': fechaGarantia?.toIso8601String(),
    };
  }

  // fromMap
  factory Equipo.fromMap(Map<String, dynamic> map) {
    return Equipo(
      id: map['id'] as String,
      codigoQR: map['codigo_qr'] as String,
      nombre: map['nombre'] as String,
      tipo: map['tipo'] as String,
      marca: map['marca'] as String,
      modelo: map['modelo'] as String,
      estado: map['estado'] as String,
      numeroSerie: map['numero_serie'] as String,
      departamentoId: map['departamento_id'] as String,
      departamentoNombre: map['departamento_nombre'] as String?,
      proyectoId: map['proyecto_id'] as String,
      proyectoNombre: map['proyecto_nombre'] as String?,
      trabajadorId: map['trabajador_id'] as String?,
      trabajadorNombre: map['trabajador_nombre'] as String?,
      fechaAdquisicion: DateTime.parse(map['fecha_adquisicion'] as String),
      fechaAsignacion: map['fecha_asignacion'] != null
          ? DateTime.parse(map['fecha_asignacion'] as String)
          : null,
      usuarioCreacion: map['usuario_creacion'] as String,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      activo: (map['activo'] as int) == 1,
      observaciones: map['observaciones'] as String?,
      costo: map['costo']?.toDouble(),
      fechaGarantia: map['fecha_garantia'] != null
          ? DateTime.parse(map['fecha_garantia'] as String)
          : null,
    );
  }

  // copyWith
  Equipo copyWith({
    String? id,
    String? codigoQR,
    String? nombre,
    String? tipo,
    String? marca,
    String? modelo,
    String? estado,
    String? numeroSerie,
    String? departamentoId,
    String? departamentoNombre,
    String? proyectoId,
    String? proyectoNombre,
    String? trabajadorId,
    String? trabajadorNombre,
    DateTime? fechaAdquisicion,
    DateTime? fechaAsignacion,
    String? usuarioCreacion,
    DateTime? fechaCreacion,
    bool? activo,
    String? observaciones,
    double? costo,
    DateTime? fechaGarantia,
  }) {
    return Equipo(
      id: id ?? this.id,
      codigoQR: codigoQR ?? this.codigoQR,
      nombre: nombre ?? this.nombre,
      tipo: tipo ?? this.tipo,
      marca: marca ?? this.marca,
      modelo: modelo ?? this.modelo,
      estado: estado ?? this.estado,
      numeroSerie: numeroSerie ?? this.numeroSerie,
      departamentoId: departamentoId ?? this.departamentoId,
      departamentoNombre: departamentoNombre ?? this.departamentoNombre,
      proyectoId: proyectoId ?? this.proyectoId,
      proyectoNombre: proyectoNombre ?? this.proyectoNombre,
      trabajadorId: trabajadorId ?? this.trabajadorId,
      trabajadorNombre: trabajadorNombre ?? this.trabajadorNombre,
      fechaAdquisicion: fechaAdquisicion ?? this.fechaAdquisicion,
      fechaAsignacion: fechaAsignacion ?? this.fechaAsignacion,
      usuarioCreacion: usuarioCreacion ?? this.usuarioCreacion,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      activo: activo ?? this.activo,
      observaciones: observaciones ?? this.observaciones,
      costo: costo ?? this.costo,
      fechaGarantia: fechaGarantia ?? this.fechaGarantia,
    );
  }

  // ============================================
  // ✅ HELPERS CORREGIDOS
  // ============================================

  /// ¿El equipo está asignado a algún trabajador?
  bool get estaAsignado => trabajadorId != null && trabajadorId!.isNotEmpty;

  /// Información resumida para mostrar en UI
  String get infoResumida => '$nombre ($codigoQR) - $estado';

  /// ✅ ¿Es un equipo temporal del escáner? (SOLO por el ID)
  bool get esTemporal => id.startsWith('temp-');

  /// ✅ ¿Es una edición real? (existe en BD - SOLO por el ID)
  bool get esEdicionReal => id.startsWith('eq-');

  /// ✅ ¿Tiene departamento asignado?
  bool get tieneDepartamento =>
      departamentoId.isNotEmpty && departamentoId != 'sin-departamento';

  /// ✅ ¿Está sin departamento?
  bool get sinDepartamento =>
      departamentoId.isEmpty || departamentoId == 'sin-departamento';

  /// Generar ID único para nuevo equipo
  static String generarId() =>
      'eq-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4().substring(0, 4)}';
}
