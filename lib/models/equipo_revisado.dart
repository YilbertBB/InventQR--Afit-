import 'package:uuid/uuid.dart';

class EquipoRevisado {
  final String id;
  final String revisionId;
  final String equipoId;
  final String nombreEquipo;
  final String codigoQR;
  final bool encontrado;
  final bool enAreaCorrecta;
  final String? observaciones;
  final DateTime fechaEscaneo;
  final String? trabajadorAsignado;
  final bool esEquipoForaneo;

  EquipoRevisado({
    required this.id,
    required this.revisionId,
    required this.equipoId,
    required this.nombreEquipo,
    required this.codigoQR,
    this.encontrado = true,
    this.enAreaCorrecta = true,
    this.observaciones,
    required this.fechaEscaneo,
    this.trabajadorAsignado,
    this.esEquipoForaneo = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'revision_id': revisionId,
      'equipo_id': equipoId,
      'nombre_equipo': nombreEquipo,
      'codigo_qr': codigoQR,
      'encontrado': encontrado ? 1 : 0,
      'en_area_correcta': enAreaCorrecta ? 1 : 0,
      'observaciones': observaciones,
      'fecha_escaneo': fechaEscaneo.toIso8601String(),
      'trabajador_asignado': trabajadorAsignado,
      'es_equipo_foraneo': esEquipoForaneo ? 1 : 0,
    };
  }

  factory EquipoRevisado.fromMap(Map<String, dynamic> map) {
    return EquipoRevisado(
      id: map['id'] as String,
      revisionId: map['revision_id'] as String,
      equipoId: map['equipo_id'] as String,
      nombreEquipo: map['nombre_equipo'] as String,
      codigoQR: map['codigo_qr'] as String,
      encontrado: (map['encontrado'] as int) == 1,
      enAreaCorrecta: (map['en_area_correcta'] as int) == 1,
      observaciones: map['observaciones'] as String?,
      fechaEscaneo: DateTime.parse(map['fecha_escaneo'] as String),
      trabajadorAsignado: map['trabajador_asignado'] as String?,
      esEquipoForaneo: (map['es_equipo_foraneo'] as int? ?? 0) == 1,
    );
  }

  bool get esFaltante => !encontrado;
  bool get estaFueraDeArea => !enAreaCorrecta;
  bool get esEquipoCorrecto => encontrado && !esEquipoForaneo;
  bool get esEquipoFaltante => !encontrado;
  bool get esEquipoSobrante => encontrado && esEquipoForaneo;

  static String generarId() =>
      'eqr-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4().substring(0, 4)}';

  String get tipoDiscrepancia {
    if (esEquipoFaltante) return 'FALTANTE';
    if (esEquipoSobrante) return 'SOBRANTE';
    return 'CORRECTO';
  }
}
