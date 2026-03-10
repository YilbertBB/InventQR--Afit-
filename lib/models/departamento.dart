import 'package:uuid/uuid.dart';

class Departamento {
  final String id;
  final String nombre;
  final int cantidadEquiposAsignados;
  final int cantidadPersonal;

  Departamento({
    required this.id,
    required this.nombre,
    this.cantidadEquiposAsignados = 0,
    this.cantidadPersonal = 0,
  });

  // toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'cantidad_equipos_asignados': cantidadEquiposAsignados,
      'cantidad_personal': cantidadPersonal,
    };
  }

  // fromMap
  factory Departamento.fromMap(Map<String, dynamic> map) {
    return Departamento(
      id: map['id'] as String,
      nombre: map['nombre'] as String,
      cantidadEquiposAsignados: map['cantidad_equipos_asignados'] as int? ?? 0,
      cantidadPersonal: map['cantidad_personal'] as int? ?? 0,
    );
  }

  // copyWith
  Departamento copyWith({
    String? id,
    String? nombre,
    int? cantidadEquiposAsignados,
    int? cantidadPersonal,
  }) {
    return Departamento(
      id: id ?? this.id,
      nombre: nombre ?? this.nombre,
      cantidadEquiposAsignados:
          cantidadEquiposAsignados ?? this.cantidadEquiposAsignados,
      cantidadPersonal: cantidadPersonal ?? this.cantidadPersonal,
    );
  }

  // Métodos adicionales
  bool get tieneEquipos => cantidadEquiposAsignados > 0;
  bool get tienePersonal => cantidadPersonal > 0;

  // Método estático para generar IDs
  static String generarId() {
    return 'dep-${DateTime.now().millisecondsSinceEpoch}-${const Uuid().v4().substring(0, 8)}';
  }

  // Validación
  bool get esValido => nombre.isNotEmpty && nombre.length >= 3;

  // Para mostrar en UI
  String get infoResumen {
    return '$cantidadEquiposAsignados equipos, $cantidadPersonal personas';
  }
}
