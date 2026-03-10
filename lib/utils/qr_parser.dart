import 'package:flutter/material.dart';

class QRParser {
  static Map<String, String> parseViejoFormato(String qrCode) {
    final cleaned = qrCode.trim().replaceAll(
      RegExp(r',+$'),
      '',
    ); // Elimina comas al final
    final partes = cleaned.split(',').map((e) => e.trim()).toList();

    debugPrint('🔍 QR original: "$qrCode"');
    debugPrint('🔍 QR limpio: "$cleaned"');
    debugPrint('🔍 Partes: $partes (${partes.length})');

    // Si tiene 4 partes, es el formato viejo
    if (partes.length == 4) {
      return {
        'estado': partes[0],
        'nombre': partes[1],
        'id': partes[2],
        'area': partes[3],
        'codigo_qr': qrCode, // Guardamos el QR original
      };
    }

    // Si tiene menos partes pero la primera es un estado conocido
    if (partes.isNotEmpty && _esEstadoValido(partes[0])) {
      return {
        'estado': partes[0],
        'nombre': partes.length > 1 ? partes[1] : '',
        'id': partes.length > 2 ? partes[2] : '',
        'area': partes.length > 3 ? partes[3] : '',
        'codigo_qr': qrCode,
      };
    }

    // Si no, devolvemos solo el código (formato estándar)
    return {'codigo_qr': qrCode};
  }

  /// Verifica si un string es un estado válido
  static bool _esEstadoValido(String texto) {
    final estados = ['en espera', 'activo', 'mantenimiento', 'baja', 'espera'];
    return estados.contains(texto.toLowerCase().trim());
  }

  /// Determina si es un QR con formato viejo
  static bool esFormatoViejo(String qrCode) {
    final cleaned = qrCode.trim().replaceAll(RegExp(r',+$'), '');
    final partes = cleaned.split(',').map((e) => e.trim()).toList();

    // Es formato viejo si:
    // 1. Tiene exactamente 4 partes
    // 2. O tiene menos partes pero la primera es un estado válido
    if (partes.length == 4) return true;
    if (partes.isNotEmpty && _esEstadoValido(partes[0])) return true;

    return false;
  }

  /// Extrae el código QR para búsqueda (el ID numérico)
  static String getCodigoBusqueda(String qrCode) {
    final cleaned = qrCode.trim().replaceAll(RegExp(r',+$'), '');
    final partes = cleaned.split(',').map((e) => e.trim()).toList();

    if (partes.length >= 3) {
      return partes[2]; // El ID numérico (52802966)
    }
    return qrCode; // El QR completo
  }
}
