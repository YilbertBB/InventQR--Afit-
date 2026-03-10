import 'package:uuid/uuid.dart';

class Traslado {
  final String id;
  final String equipoId;
  final String equipoNombre;
  final String desdeDepartamentoId;
  final String desdeDepartamentoNombre;
  final String haciaDepartamentoId;
  final String haciaDepartamentoNombre;
  final String motivo;
  final String usuarioRealizadorId;
  final String? usuarioRealizadorNombre; // 👈 NUEVO CAMPO
  final DateTime fechaTraslado;
  final String? observaciones;
  final String estado;

  Traslado({
    required this.id,
    required this.equipoId,
    required this.equipoNombre,
    required this.desdeDepartamentoId,
    required this.desdeDepartamentoNombre,
    required this.haciaDepartamentoId,
    required this.haciaDepartamentoNombre,
    required this.motivo,
    required this.usuarioRealizadorId,
    this.usuarioRealizadorNombre, // 👈 NUEVO
    required this.fechaTraslado,
    this.observaciones,
    required this.estado,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'equipo_id': equipoId,
      'equipo_nombre': equipoNombre,
      'desde_departamento_id': desdeDepartamentoId,
      'desde_departamento_nombre': desdeDepartamentoNombre,
      'hacia_departamento_id': haciaDepartamentoId,
      'hacia_departamento_nombre': haciaDepartamentoNombre,
      'motivo': motivo,
      'usuario_realizador': usuarioRealizadorId,
      'usuario_realizador_nombre': usuarioRealizadorNombre, // 👈 NUEVO
      'fecha_traslado': fechaTraslado.toIso8601String(),
      'observaciones': observaciones,
      'estado': estado,
    };
  }

  factory Traslado.fromMap(Map<String, dynamic> map) {
    return Traslado(
      id: map['id'] as String,
      equipoId: map['equipo_id'] as String,
      equipoNombre: map['equipo_nombre'] as String,
      desdeDepartamentoId: map['desde_departamento_id'] as String,
      desdeDepartamentoNombre: map['desde_departamento_nombre'] as String,
      haciaDepartamentoId: map['hacia_departamento_id'] as String,
      haciaDepartamentoNombre: map['hacia_departamento_nombre'] as String,
      motivo: map['motivo'] as String,
      usuarioRealizadorId: map['usuario_realizador'] as String,
      usuarioRealizadorNombre:
          map['usuario_realizador_nombre'] as String?, // 👈 NUEVO
      fechaTraslado: DateTime.parse(map['fecha_traslado'] as String),
      observaciones: map['observaciones'] as String?,
      estado: map['estado'] as String,
    );
  }

  static String generarId() =>
      'tra-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4().substring(0, 4)}';
}
