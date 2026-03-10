class Trabajador {
  final String id;
  final String nombres;
  final String apellidos;
  final String dni;
  final String cargo;
  final String departamentoId;
  final String? departamentoNombre;
  final String area;
  final String? telefono;
  final String? emailCorporativo;
  final DateTime fechaIngreso;
  final bool activo;
  final DateTime fechaCreacion;
  final String? usuarioCreacion;
  final String? fotoUrl;

  Trabajador({
    required this.id,
    required this.nombres,
    required this.apellidos,
    required this.dni,
    required this.cargo,
    required this.departamentoId,
    this.departamentoNombre,
    required this.area,
    this.telefono,
    this.emailCorporativo,
    required this.fechaIngreso,
    this.activo = true,
    required this.fechaCreacion,
    this.usuarioCreacion,
    this.fotoUrl,
  });

  // toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombres': nombres,
      'apellidos': apellidos,
      'dni': dni,
      'cargo': cargo,
      'departamento_id': departamentoId,
      'departamento_nombre': departamentoNombre,
      'area': area,
      'telefono': telefono,
      'email_corporativo': emailCorporativo,
      'fecha_ingreso': fechaIngreso.toIso8601String(),
      'activo': activo ? 1 : 0,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'usuario_creacion': usuarioCreacion,
      'foto_url': fotoUrl,
    };
  }

  // fromMap
  factory Trabajador.fromMap(Map<String, dynamic> map) {
    return Trabajador(
      id: map['id'] as String,
      nombres: map['nombres'] as String,
      apellidos: map['apellidos'] as String,
      dni: map['dni'] as String,
      cargo: map['cargo'] as String,
      departamentoId: map['departamento_id'] as String,
      departamentoNombre: map['departamento_nombre'] as String?,
      area: map['area'] as String,
      telefono: map['telefono'] as String?,
      emailCorporativo: map['email_corporativo'] as String?,
      fechaIngreso: DateTime.parse(map['fecha_ingreso'] as String),
      activo: (map['activo'] as int) == 1,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      usuarioCreacion: map['usuario_creacion'] as String?,
      fotoUrl: map['foto_url'] as String?,
    );
  }

  // copyWith
  Trabajador copyWith({
    String? id,
    String? nombres,
    String? apellidos,
    String? dni,
    String? cargo,
    String? departamentoId,
    String? departamentoNombre,
    String? area,
    String? telefono,
    String? emailCorporativo,
    DateTime? fechaIngreso,
    bool? activo,
    DateTime? fechaCreacion,
    String? usuarioCreacion,
    String? fotoUrl,
  }) {
    return Trabajador(
      id: id ?? this.id,
      nombres: nombres ?? this.nombres,
      apellidos: apellidos ?? this.apellidos,
      dni: dni ?? this.dni,
      cargo: cargo ?? this.cargo,
      departamentoId: departamentoId ?? this.departamentoId,
      departamentoNombre: departamentoNombre ?? this.departamentoNombre,
      area: area ?? this.area,
      telefono: telefono ?? this.telefono,
      emailCorporativo: emailCorporativo ?? this.emailCorporativo,
      fechaIngreso: fechaIngreso ?? this.fechaIngreso,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      usuarioCreacion: usuarioCreacion ?? this.usuarioCreacion,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }

  // Métodos adicionales
  String get nombreCompleto => '$nombres $apellidos';
  String get infoCargo => '$cargo - ${departamentoNombre ?? "Sin depto"}';

  static String generarId() => 'tra-${DateTime.now().millisecondsSinceEpoch}';
}
