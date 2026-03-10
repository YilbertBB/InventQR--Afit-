import 'package:uuid/uuid.dart';

class Asignacion {
  final String id;
  final String equipoId;
  final String equipoNombre;
  final String trabajadorId;
  final String trabajadorNombre;
  final DateTime fechaAsignacion;
  final String? motivoAsignacion;
  final String usuarioAsignadorId;
  final String? usuarioAsignadorNombre;
  final DateTime? fechaDesasignacion;
  final String? motivoDesasignacion;
  final String estado; // 'activa', 'finalizada'

  Asignacion({
    required this.id,
    required this.equipoId,
    required this.equipoNombre,
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.fechaAsignacion,
    this.motivoAsignacion,
    required this.usuarioAsignadorId,
    this.usuarioAsignadorNombre,
    this.fechaDesasignacion,
    this.motivoDesasignacion,
    required this.estado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'equipo_nombre': equipoNombre,
      'trabajador_id': trabajadorId,
      'trabajador_nombre': trabajadorNombre,
      'fecha_asignacion': fechaAsignacion.toIso8601String(),
      'motivo_asignacion': motivoAsignacion,
      'usuario_asignador': usuarioAsignadorId,
      'usuario_asignador_nombre': usuarioAsignadorNombre,
      'fecha_desasignacion': fechaDesasignacion?.toIso8601String(),
      'motivo_desasignacion': motivoDesasignacion,
      'estado': estado,
    };
  }

  factory Asignacion.fromMap(Map<String, dynamic> map) {
    return Asignacion(
      id: map['id'] as String,
      equipoId: map['equipo_id'] as String,
      equipoNombre: map['equipo_nombre'] as String,
      trabajadorId: map['trabajador_id'] as String,
      trabajadorNombre: map['trabajador_nombre'] as String,
      fechaAsignacion: DateTime.parse(map['fecha_asignacion'] as String),
      motivoAsignacion: map['motivo_asignacion'] as String?,
      usuarioAsignadorId: map['usuario_asignador'] as String,
      usuarioAsignadorNombre: map['usuario_asignador_nombre'] as String?,
      fechaDesasignacion: map['fecha_desasignacion'] != null
          ? DateTime.parse(map['fecha_desasignacion'] as String)
          : null,
      motivoDesasignacion: map['motivo_desasignacion'] as String?,
      estado: map['estado'] as String,
    );
  }

  bool get estaActiva => estado == 'activa';

  static String generarId() =>
      'asig-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4().substring(0, 4)}';
}
