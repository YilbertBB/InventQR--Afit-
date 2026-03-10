class Usuario {
  final String id;
  final String username;
  final String passwordHash;
  final String nombreCompleto;
  final String email;
  final String rol;
  final String? departamento;
  final String telefono;
  final bool activo;
  final DateTime fechaCreacion;
  final DateTime? fechaUltimoLogin;
  final String? fotoUrl;

  Usuario({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.nombreCompleto,
    required this.email,
    required this.rol,
    this.departamento,
    required this.telefono,
    this.activo = true,
    required this.fechaCreacion,
    this.fechaUltimoLogin,
    this.fotoUrl,
  });

  // toMap
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password_hash': passwordHash,
      'nombre_completo': nombreCompleto,
      'email': email,
      'rol': rol,
      'departamento': departamento,
      'telefono': telefono,
      'activo': activo ? 1 : 0,
      'fecha_creacion': fechaCreacion.toIso8601String(),
      'fecha_ultimo_login': fechaUltimoLogin?.toIso8601String(),
      'foto_url': fotoUrl,
    };
  }

  // fromMap
  factory Usuario.fromMap(Map<String, dynamic> map) {
    return Usuario(
      id: map['id'] as String,
      username: map['username'] as String,
      passwordHash: map['password_hash'] as String,
      nombreCompleto: map['nombre_completo'] as String,
      email: map['email'] as String,
      rol: map['rol'] as String,
      departamento: map['departamento'] as String?,
      telefono: map['telefono'] as String,
      activo: (map['activo'] as int) == 1,
      fechaCreacion: DateTime.parse(map['fecha_creacion'] as String),
      fechaUltimoLogin: map['fecha_ultimo_login'] != null
          ? DateTime.parse(map['fecha_ultimo_login'] as String)
          : null,
      fotoUrl: map['foto_url'] as String?,
    );
  }

  // copyWith
  Usuario copyWith({
    String? id,
    String? username,
    String? passwordHash,
    String? nombreCompleto,
    String? email,
    String? rol,
    String? departamento,
    String? telefono,
    bool? activo,
    DateTime? fechaCreacion,
    DateTime? fechaUltimoLogin,
    String? fotoUrl,
  }) {
    return Usuario(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      nombreCompleto: nombreCompleto ?? this.nombreCompleto,
      email: email ?? this.email,
      rol: rol ?? this.rol,
      departamento: departamento ?? this.departamento,
      telefono: telefono ?? this.telefono,
      activo: activo ?? this.activo,
      fechaCreacion: fechaCreacion ?? this.fechaCreacion,
      fechaUltimoLogin: fechaUltimoLogin ?? this.fechaUltimoLogin,
      fotoUrl: fotoUrl ?? this.fotoUrl,
    );
  }

  // Métodos adicionales
  bool tienePermiso(String permiso) {
    final permisosPorRol = {
      'admin': [
        'todo',
        'gestion_usuarios',
        'gestion_equipos',
        'exportar',
        'importar',
        'trasladar',
        'auditar',
      ],
      'supervisor': [
        'gestion_equipos',
        'exportar',
        'importar',
        'trasladar',
        'auditar',
      ],
      'auditor': ['leer', 'escanear', 'auditar', 'exportar_reportes'],
      'empleado': ['leer', 'escanear'],
    };

    return permisosPorRol[rol]?.contains('todo') == true ||
        permisosPorRol[rol]?.contains(permiso) == true;
  }

  // Factory para usuario root
  factory Usuario.root() {
    final ahora = DateTime.now();
    return Usuario(
      id: 'root-user-001',
      username: 'root',
      passwordHash: 'root', // En producción, usar hash seguro
      nombreCompleto: 'Administrador Principal',
      email: 'root@empresa.com',
      rol: 'admin',
      departamento: 'Sistemas',
      telefono: '000-000000',
      fechaCreacion: ahora,
    );
  }

  static String generarId() => 'usr-${DateTime.now().millisecondsSinceEpoch}';
}
