import 'package:uuid/uuid.dart';

class Revision {
  final String id;
  final String departamentoId;
  final String departamentoNombre;
  final String usuarioAuditorId;
  final String? usuarioAuditorNombre;
  final DateTime fechaRevision;
  final DateTime? fechaFinalizacion;
  final String estado; // 'en_curso', 'completada', 'cancelada'
  final int totalEquipos;
  final int equiposEncontrados;
  final int equiposFaltantes;
  final String? observaciones;
  final int equiposSobrantes; // Equipos escaneados que no pertenecen al depto
  final int equiposCorrectos;

  Revision({
    required this.id,
    required this.departamentoId,
    required this.departamentoNombre,
    required this.usuarioAuditorId,
    this.usuarioAuditorNombre,
    required this.fechaRevision,
    this.fechaFinalizacion,
    required this.estado,
    this.totalEquipos = 0,
    this.equiposEncontrados = 0,
    this.equiposFaltantes = 0,
    this.observaciones,
    this.equiposSobrantes = 0,
    this.equiposCorrectos = 0,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'departamento_id': departamentoId,
      'departamento_nombre': departamentoNombre,
      'usuario_auditor': usuarioAuditorId,
      'usuario_auditor_nombre': usuarioAuditorNombre,
      'fecha_revision': fechaRevision.toIso8601String(),
      'fecha_finalizacion': fechaFinalizacion?.toIso8601String(),
      'estado': estado,
      'total_equipos': totalEquipos,
      'equipos_encontrados': equiposEncontrados,
      'equipos_faltantes': equiposFaltantes,
      'observaciones': observaciones,
      'equipos_sobrantes': equiposSobrantes,
      'equipos_correctos': equiposCorrectos,
    };
  }

  factory Revision.fromMap(Map<String, dynamic> map) {
    return Revision(
      id: map['id'] as String,
      departamentoId: map['departamento_id'] as String,
      departamentoNombre: map['departamento_nombre'] as String,
      usuarioAuditorId: map['usuario_auditor'] as String,
      usuarioAuditorNombre: map['usuario_auditor_nombre'] as String?,
      fechaRevision: DateTime.parse(map['fecha_revision'] as String),
      fechaFinalizacion: map['fecha_finalizacion'] != null
          ? DateTime.parse(map['fecha_finalizacion'] as String)
          : null,
      estado: map['estado'] as String,
      totalEquipos: map['total_equipos'] as int? ?? 0,
      equiposEncontrados: map['equipos_encontrados'] as int? ?? 0,
      equiposFaltantes: map['equipos_faltantes'] as int? ?? 0,
      observaciones: map['observaciones'] as String?,
      equiposSobrantes: map['equipos_sobrantes'] as int? ?? 0,
      equiposCorrectos: map['equipos_correctos'] as int? ?? 0,
    );
  }

  // ✅ NUEVO: copyWith
  Revision copyWith({
    String? id,
    String? departamentoId,
    String? departamentoNombre,
    String? usuarioAuditorId,
    String? usuarioAuditorNombre,
    DateTime? fechaRevision,
    DateTime? fechaFinalizacion,
    String? estado,
    int? totalEquipos,
    int? equiposEncontrados,
    int? equiposFaltantes,
    String? observaciones,
    int? equiposSobrantes,
    int? equiposCorrectos,
  }) {
    return Revision(
      id: id ?? this.id,
      departamentoId: departamentoId ?? this.departamentoId,
      departamentoNombre: departamentoNombre ?? this.departamentoNombre,
      usuarioAuditorId: usuarioAuditorId ?? this.usuarioAuditorId,
      usuarioAuditorNombre: usuarioAuditorNombre ?? this.usuarioAuditorNombre,
      fechaRevision: fechaRevision ?? this.fechaRevision,
      fechaFinalizacion: fechaFinalizacion ?? this.fechaFinalizacion,
      estado: estado ?? this.estado,
      totalEquipos: totalEquipos ?? this.totalEquipos,
      equiposEncontrados: equiposEncontrados ?? this.equiposEncontrados,
      equiposFaltantes: equiposFaltantes ?? this.equiposFaltantes,
      observaciones: observaciones ?? this.observaciones,
      equiposSobrantes: equiposSobrantes ?? this.equiposSobrantes,
      equiposCorrectos: equiposCorrectos ?? this.equiposCorrectos,
    );
  }

  bool get estaEnCurso => estado == 'en_curso';
  bool get estaCompletada => estado == 'completada';
  bool get estaCancelada => estado == 'cancelada';
  bool get hayDiscrepancias => equiposFaltantes > 0 || equiposSobrantes > 0;

  double get porcentajeCompletado {
    if (totalEquipos == 0) return 0;
    return (equiposEncontrados / totalEquipos) * 100;
  }

  static String generarId() =>
      'rev-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4().substring(0, 4)}';

  String get resumenReporte {
    if (estado != 'completada') return 'Revisión en curso';
    return '$equiposCorrectos correctos, $equiposFaltantes faltantes, $equiposSobrantes sobrantes';
  }
}
