import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../models/equipo.dart';
import '../providers/equipo_provider.dart';
import '../providers/revision_provider.dart';
import '../providers/auth_provider.dart';
import '../utils/qr_parser.dart';
import '../utils/permission_guard.dart';
import 'inventory/add_asset_screen.dart';
import 'inventory/asset_details_screen.dart';
import 'inventory/transfer_screen.dart';
import '../core/app_theme.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    this.modoRevision = false,
    this.modoTraslado = false,
    this.modoAsignacion = false,
    this.departamentoDestinoId,
    this.departamentoDestinoNombre,
  });
  final bool modoRevision;
  final bool modoTraslado; // ← NUEVO
  final String? departamentoDestinoId; // ← NUEVO - ID del departamento destino
  final String? departamentoDestinoNombre;
  final bool modoAsignacion;
  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  final MobileScannerController _controller = MobileScannerController(
    formats: [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
    torchEnabled: false,
    autoStart: true,
  );

  bool _isProcessing = false;
  String? _lastScannedCode;
  bool _isScannerPaused = false;
  late final AnimationController _scanLineController;
  late final Animation<double> _scanLineAnimation;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_puedeEscanear()) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No tiene permisos para escanear QR'),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
            ),
          );
          Navigator.pop(context);
        }
        return;
      }
    });

    _scanLineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _scanLineAnimation = Tween<double>(begin: 0, end: 240).animate(
      CurvedAnimation(parent: _scanLineController, curve: Curves.easeInOut),
    );
    _scanLineController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanLineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  bool _puedeEscanear() {
    final authProvider = context.read<AuthProvider>();
    return PermissionGuard.canAccess(authProvider.usuarioActual, 'escanear');
  }

  void _mostrarSinPermisos(String mensaje) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(mensaje),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _onBarcodeDetected(BuildContext context, BarcodeCapture capture) async {
    if (_isProcessing) return;

    final barcode = capture.barcodes.firstOrNull;
    if (barcode == null) return;

    final String? qrCode = barcode.rawValue;
    if (qrCode == null || qrCode.isEmpty) return;

    if (_lastScannedCode == qrCode) return;
    _lastScannedCode = qrCode;

    setState(() => _isProcessing = true);
    await _pauseScanner();
    if (!context.mounted) return;

    debugPrint('📱 QR Escaneado: $qrCode');
    debugPrint('📱 Modo asignación: ${widget.modoAsignacion}');
    debugPrint('📱 Modo traslado: ${widget.modoTraslado}');

    try {
      // ============================================
      // MODO REVISIÓN
      // ============================================
      if (widget.modoRevision) {
        if (!_puedeEscanear() || !PermissionGuard.canAccess(context.read<AuthProvider>().usuarioActual, 'auditar')) {
          _mostrarSinPermisos('No tiene permisos para auditar equipos');
          return;
        }

        final revisionProvider = Provider.of<RevisionProvider>(
          context,
          listen: false,
        );

        if (!revisionProvider.hayRevisionActiva) {
          _showErrorDialog(
            qrCode,
            error: 'No hay una revisión activa',
            esErrorRevision: true,
          );
          setState(() => _isProcessing = false);
          return;
        }

        final registrado = await revisionProvider.registrarEquipoEscaneado(
          codigoEscaneado: qrCode,
        );
        if (!context.mounted) return;

        if (registrado && mounted) {
          HapticFeedback.heavyImpact();
          _showSuccessAnimation(qrCode, esRevision: true);

          await Future.delayed(const Duration(milliseconds: 600));
          if (!context.mounted) return;

          if (context.mounted) {
            Navigator.pop(context, true);
          }
        } else if (mounted) {
          _showErrorDialog(
            qrCode,
            error: revisionProvider.error ?? 'Error al registrar equipo',
            esErrorRevision: true,
          );
        }
      }
      // ============================================
      // MODO ASIGNACIÓN A TRABAJADOR (NUEVO)
      // ============================================
      else if (widget.modoAsignacion) {
        if (!PermissionGuard.canAccess(context.read<AuthProvider>().usuarioActual, 'gestion_equipos')) {
          _mostrarSinPermisos('No tiene permisos para gestionar equipos');
          return;
        }

        final equipoProvider = Provider.of<EquipoProvider>(
          context,
          listen: false,
        );

        // 1. Determinar el código de búsqueda
        final codigoBusqueda = QRParser.getCodigoBusqueda(qrCode);

        // 2. Buscar el equipo
        Equipo? equipoEncontrado;

        // Buscar en la lista cargada primero
        final equipos = equipoProvider.equipos;
        if (equipos.isNotEmpty) {
          try {
            equipoEncontrado = equipos.firstWhere(
              (e) =>
                  e.codigoQR.contains(codigoBusqueda) ||
                  e.numeroSerie.contains(codigoBusqueda) ||
                  e.id.contains(codigoBusqueda),
            );
          } catch (e) {
            debugPrint('⚠️ Equipo no encontrado en lista (asignación): $e');
          }
        }

        // Si no está en la lista, buscar en BD
        if (equipoEncontrado == null) {
          final resultados = await equipoProvider.buscarEquipos(codigoBusqueda);
          if (!context.mounted) return;
          if (resultados.isNotEmpty) {
            equipoEncontrado = resultados.first;
          }
        }

        HapticFeedback.heavyImpact();

        if (equipoEncontrado != null && mounted) {
          debugPrint('✅ Equipo encontrado - modo asignación');

          _showSuccessAnimation(qrCode, esAsignacion: true);

          await Future.delayed(const Duration(milliseconds: 600));
          if (!context.mounted) return;

          if (context.mounted) {
            // ✅ Devolver el equipo encontrado
            Navigator.pop(context, equipoEncontrado);
          }
        } else if (QRParser.esFormatoViejo(qrCode) && mounted) {
          // QR viejo no registrado - preguntar qué hacer
          final datos = QRParser.parseViejoFormato(qrCode);
          _showDialogNuevoEquipoAsignacion(datos);
        } else {
          // QR no registrado
          debugPrint('❌ QR no registrado: $qrCode');
          _showErrorDialogAsignacion(qrCode);
        }
      }
      // ============================================
      // MODO TRASLADO
      // ============================================
      else if (widget.modoTraslado) {
        if (!PermissionGuard.canAccess(context.read<AuthProvider>().usuarioActual, 'trasladar')) {
          _mostrarSinPermisos('No tiene permisos para trasladar equipos');
          return;
        }

        final equipoProvider = Provider.of<EquipoProvider>(
          context,
          listen: false,
        );

        final codigoBusqueda = QRParser.getCodigoBusqueda(qrCode);
        Equipo? equipoEncontrado;

        final equipos = equipoProvider.equipos;
        if (equipos.isNotEmpty) {
          try {
            equipoEncontrado = equipos.firstWhere(
              (e) =>
                  e.codigoQR.contains(codigoBusqueda) ||
                  e.numeroSerie.contains(codigoBusqueda) ||
                  e.id.contains(codigoBusqueda),
            );
          } catch (e) {
            debugPrint('⚠️ Equipo no encontrado en lista (traslado): $e');
          }
        }

        if (equipoEncontrado == null) {
          final resultados = await equipoProvider.buscarEquipos(codigoBusqueda);
          if (!context.mounted) return;
          if (resultados.isNotEmpty) {
            equipoEncontrado = resultados.first;
          }
        }

        HapticFeedback.heavyImpact();

        if (equipoEncontrado != null && mounted) {
          _showSuccessAnimation(qrCode);

          await Future.delayed(const Duration(milliseconds: 600));
          if (!context.mounted) return;

          if (context.mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => TransferScreen(
                  equipoId: equipoEncontrado!.id,
                  equipoNombre: equipoEncontrado.nombre,
                  departamentoActualId: equipoEncontrado.departamentoId,
                  departamentoActualNombre: equipoEncontrado.departamentoNombre,
                  destinoId: widget.departamentoDestinoId,
                  destinoNombre: widget.departamentoDestinoNombre,
                ),
              ),
            );
          }
        } else if (QRParser.esFormatoViejo(qrCode) && mounted) {
          final datos = QRParser.parseViejoFormato(qrCode);
          _showDialogNuevoEquipoTraslado(datos);
        } else {
          _showErrorDialogTraslado(qrCode);
        }
      }
      // ============================================
      // MODO NORMAL (ir a detalle)
      // ============================================
      else {
        final equipoProvider = Provider.of<EquipoProvider>(
          context,
          listen: false,
        );

        final codigoBusqueda = QRParser.getCodigoBusqueda(qrCode);
        Equipo? equipoEncontrado;

        final equipos = equipoProvider.equipos;
        if (equipos.isNotEmpty) {
          try {
            equipoEncontrado = equipos.firstWhere(
              (e) =>
                  e.codigoQR.contains(codigoBusqueda) ||
                  e.numeroSerie.contains(codigoBusqueda) ||
                  e.id.contains(codigoBusqueda),
            );
          } catch (e) {
            debugPrint('⚠️ Equipo no encontrado en lista (modo normal): $e');
          }
        }

        if (equipoEncontrado == null) {
          final resultados = await equipoProvider.buscarEquipos(codigoBusqueda);
          if (!context.mounted) return;
          if (resultados.isNotEmpty) {
            equipoEncontrado = resultados.first;
          }
        }

        HapticFeedback.heavyImpact();

        if (equipoEncontrado != null && mounted) {
          _showSuccessAnimation(qrCode);

          await Future.delayed(const Duration(milliseconds: 600));
          if (!context.mounted) return;

          if (context.mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) =>
                    AssetDetailScreen(equipoId: equipoEncontrado!.id),
              ),
            ).then((_) {
              if (!context.mounted) return;

              Provider.of<EquipoProvider>(
                context,
                listen: false,
              ).cargarEquipos();

              setState(() {
                _isProcessing = false;
                _lastScannedCode = null;
              });
              _resumeScanner();
            });
          }
        } else if (QRParser.esFormatoViejo(qrCode) && mounted) {
          final datos = QRParser.parseViejoFormato(qrCode);
          _showNuevoEquipoDialog(datos);
        } else {
          debugPrint('❌ QR no registrado: $qrCode');
          _showErrorDialog(qrCode);
        }
      }
    } catch (e) {
      debugPrint('❌ Error procesando QR: $e');
      if (mounted) {
        _showErrorDialog(qrCode, error: e.toString());
      }
    } finally {
      if (!widget.modoRevision &&
          !widget.modoTraslado &&
          !widget.modoAsignacion) {
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() => _isProcessing = false);
            _lastScannedCode = null;
          }
        });
      }
    }
  }

  Future<void> _pauseScanner() async {
    if (_isScannerPaused) return;
    _isScannerPaused = true;
    try {
      await _controller.stop();
    } catch (_) {
      // ignore
    }
  }

  Future<void> _resumeScanner() async {
    if (!_isScannerPaused || !mounted) return;
    _isScannerPaused = false;
    try {
      await _controller.start();
    } catch (_) {
      // ignore
    }
  }

  // scanner_screen.dart - Agregar estos métodos

  /// ✅ Diálogo para nuevo equipo en modo asignación
  void _showDialogNuevoEquipoAsignacion(Map<String, String> datos) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
            SizedBox(width: 12),
            Text('QR No Registrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este código QR no está registrado en el inventario.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos detectados:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDato('📌 Estado', datos['estado'] ?? ''),
                  _buildDato('🖥️ Nombre', datos['nombre'] ?? ''),
                  _buildDato('🔢 ID', datos['id'] ?? ''),
                  _buildDato('📍 Área', datos['area'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Quieres crear este equipo y luego asignarlo?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedCode = null;
                });
                _resumeScanner();
              }
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedCode = null;
                });
                _resumeScanner();
              }
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _irACrearEquipoAsignacion(datos);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Crear y Asignar'),
          ),
        ],
      ),
    );
  }

  /// ✅ Crear equipo temporal y devolverlo para asignación
  void _irACrearEquipoAsignacion(Map<String, String> datos) {
    String tipo = 'Otro';
    final nombre = datos['nombre']?.toLowerCase() ?? '';

    if (nombre.contains('pc') ||
        nombre.contains('computador') ||
        nombre.contains('laptop')) {
      tipo = 'Computadora';
    } else if (nombre.contains('silla')) {
      tipo = 'Silla';
    } else if (nombre.contains('mesa') || nombre.contains('escritorio')) {
      tipo = 'Mesa';
    } else if (nombre.contains('teclado')) {
      tipo = 'Teclado';
    } else if (nombre.contains('monitor') || nombre.contains('pantalla')) {
      tipo = 'Monitor';
    } else if (nombre.contains('mouse') || nombre.contains('ratón')) {
      tipo = 'Mouse';
    }

    final equipoTemporal = Equipo(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      codigoQR: datos['codigo_qr']!,
      nombre: datos['nombre']?.isNotEmpty == true
          ? datos['nombre']!
          : 'Nuevo Equipo',
      tipo: tipo,
      marca: 'Sin marca',
      modelo: 'Sin modelo',
      estado: datos['estado']?.toLowerCase() ?? 'en espera',
      numeroSerie: datos['id'] ?? '',
      departamentoId: '',
      proyectoId: '',
      fechaAdquisicion: DateTime.now(),
      usuarioCreacion: 'usuario_actual',
      fechaCreacion: DateTime.now(),
      activo: true,
      proyectoNombre: datos['area'],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssetScreen(equipo: equipoTemporal),
      ),
    ).then((result) {
      if (result == true && mounted) {
        // Después de crear, obtener el equipo y devolverlo
        final equipoProvider = Provider.of<EquipoProvider>(
          context,
          listen: false,
        );
        final nuevoEquipo = equipoProvider.equipos.firstWhere(
          (e) => e.codigoQR == equipoTemporal.codigoQR,
          orElse: () => throw Exception('Equipo no encontrado'),
        );
        Navigator.pop(context, nuevoEquipo);
      }
    });
  }

  /// ✅ Diálogo de error para modo asignación
  void _showErrorDialogAsignacion(String qrCode) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('QR No Registrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este código QR no corresponde a ningún equipo.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                qrCode,
                style: const TextStyle(fontSize: 12, fontFamily: 'RobotoMono'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedCode = null;
                });
                _resumeScanner();
              }
            },
            child: const Text('Reintentar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  /// ✅ Modificar _showSuccessAnimation para incluir modo asignación
  void _showSuccessAnimation(
    String qrCode, {
    bool esRevision = false,
    bool esAsignacion = false,
  }) {
    String titulo = '¡QR Válido!';
    Color color = Colors.green;

    if (esRevision) {
      titulo = '¡Equipo Registrado!';
      color = AppTheme.primaryColor;
    } else if (esAsignacion) {
      titulo = '¡Equipo Encontrado!';
      color = AppTheme.primaryColor;
    }

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 64),
              const SizedBox(height: 16),
              Text(
                titulo,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                qrCode.length > 20 ? '${qrCode.substring(0, 20)}...' : qrCode,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                  fontFamily: 'RobotoMono',
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        Navigator.pop(context);
      }
    });
  }

  // ✅ Diálogo para nuevo equipo en modo traslado
  void _showDialogNuevoEquipoTraslado(Map<String, String> datos) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
            SizedBox(width: 12),
            Text('QR No Registrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este código QR no está registrado en el inventario.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos detectados:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDato('📌 Estado', datos['estado'] ?? ''),
                  _buildDato('🖥️ Nombre', datos['nombre'] ?? ''),
                  _buildDato('🔢 ID', datos['id'] ?? ''),
                  _buildDato('📍 Área', datos['area'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Quieres agregar este equipo al inventario y trasladarlo?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedCode = null;
                });
                _resumeScanner();
              }
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _irACrearEquipoTraslado(datos);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Crear y Trasladar'),
          ),
        ],
      ),
    );
  }

  // ✅ Crear equipo temporal y luego ir a traslado
  void _irACrearEquipoTraslado(Map<String, String> datos) {
    String tipo = 'Otro';
    final nombre = datos['nombre']?.toLowerCase() ?? '';

    if (nombre.contains('pc') ||
        nombre.contains('computador') ||
        nombre.contains('laptop')) {
      tipo = 'Computadora';
    } else if (nombre.contains('silla')) {
      tipo = 'Silla';
    } else if (nombre.contains('mesa') || nombre.contains('escritorio')) {
      tipo = 'Mesa';
    } else if (nombre.contains('teclado')) {
      tipo = 'Teclado';
    } else if (nombre.contains('monitor') || nombre.contains('pantalla')) {
      tipo = 'Monitor';
    } else if (nombre.contains('mouse') || nombre.contains('ratón')) {
      tipo = 'Mouse';
    }

    final equipoTemporal = Equipo(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      codigoQR: datos['codigo_qr']!,
      nombre: datos['nombre']?.isNotEmpty == true
          ? datos['nombre']!
          : 'Nuevo Equipo',
      tipo: tipo,
      marca: 'Sin marca',
      modelo: 'Sin modelo',
      estado: datos['estado']?.toLowerCase() ?? 'en espera',
      numeroSerie: datos['id'] ?? '',
      departamentoId: '',
      proyectoId: '',
      fechaAdquisicion: DateTime.now(),
      usuarioCreacion: 'usuario_actual',
      fechaCreacion: DateTime.now(),
      activo: true,
      proyectoNombre: datos['area'],
    );

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssetScreen(equipo: equipoTemporal),
      ),
    ).then((result) {
      if (result == true && mounted) {
        // Después de crear, ir a traslado
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => TransferScreen(
              equipoId: equipoTemporal.id,
              equipoNombre: equipoTemporal.nombre,
              departamentoActualId: '',
              departamentoActualNombre: '',
              destinoId: widget.departamentoDestinoId,
              destinoNombre: widget.departamentoDestinoNombre,
            ),
          ),
        );
      }
    });
  }

  // ✅ Diálogo de error para modo traslado
  void _showErrorDialogTraslado(String qrCode) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red, size: 28),
            SizedBox(width: 12),
            Text('QR No Registrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este código QR no corresponde a ningún equipo.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: SelectableText(
                qrCode,
                style: const TextStyle(fontSize: 12, fontFamily: 'RobotoMono'),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No puedes trasladar un equipo que no existe.',
              style: TextStyle(fontSize: 12, color: Colors.red),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedCode = null;
                });
                _resumeScanner();
              }
            },
            child: const Text('Reintentar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  void _showNuevoEquipoDialog(Map<String, String> datos) {
    debugPrint('📋 Mostrando diálogo con datos: $datos');

    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (dialogContext) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.add_circle, color: AppTheme.primaryColor, size: 28),
            SizedBox(width: 12),
            Text('QR No Registrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Este código QR no está registrado en el inventario.',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Datos detectados:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildDato('📌 Estado', datos['estado'] ?? ''),
                  _buildDato('🖥️ Nombre', datos['nombre'] ?? ''),
                  _buildDato('🔢 ID', datos['id'] ?? ''),
                  _buildDato('📍 Área', datos['area'] ?? ''),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '¿Quieres agregar este equipo al inventario?',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              debugPrint('❌ Usuario canceló');
              Navigator.pop(dialogContext);
            },
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              debugPrint('✅ Usuario aceptó - Creando equipo...');
              Navigator.pop(dialogContext); // Cerrar diálogo
              _irACrearEquipo(datos);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
              foregroundColor: Colors.white,
            ),
            child: const Text('Agregar Equipo'),
          ),
        ],
      ),
    );
  }

  Widget _buildDato(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              label,
              style: const TextStyle(fontSize: 11, color: Color(0xFF64748b)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value.isNotEmpty ? value : '—',
              style: TextStyle(
                fontSize: 12,
                fontWeight: value.isNotEmpty
                    ? FontWeight.w600
                    : FontWeight.normal,
                color: value.isNotEmpty ? Colors.black : Colors.grey,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // En scanner_screen.dart - método _irACrearEquipo

  void _irACrearEquipo(Map<String, String> datos) {
    debugPrint('📦 Datos para nuevo equipo: $datos');
    // Extraer posible tipo del nombre
    String tipo = 'Otro';
    final nombre = datos['nombre']?.toLowerCase() ?? '';

    if (nombre.contains('pc') ||
        nombre.contains('computador') ||
        nombre.contains('laptop')) {
      tipo = 'Computadora';
    } else if (nombre.contains('silla')) {
      tipo = 'Silla';
    } else if (nombre.contains('mesa') || nombre.contains('escritorio')) {
      tipo = 'Mesa';
    } else if (nombre.contains('teclado')) {
      tipo = 'Teclado';
    } else if (nombre.contains('monitor') || nombre.contains('pantalla')) {
      tipo = 'Monitor';
    } else if (nombre.contains('mouse') || nombre.contains('ratón')) {
      tipo = 'Mouse';
    }

    final equipoTemporal = Equipo(
      id: 'temp-${DateTime.now().millisecondsSinceEpoch}',
      codigoQR: datos['codigo_qr']!, // ← QR original
      nombre: datos['nombre']?.isNotEmpty == true
          ? datos['nombre']! // ← "PC-I5"
          : 'Nuevo Equipo',
      tipo: tipo, // ← Detectado del nombre
      marca: 'Sin marca',
      modelo: 'Sin modelo',
      estado: datos['estado']?.toLowerCase() ?? 'en espera', // ← "en espera"
      numeroSerie: datos['id'] ?? '', // ← "52802966"
      departamentoId: '',
      proyectoId: '',
      fechaAdquisicion: DateTime.now(),
      usuarioCreacion: 'usuario_actual',
      fechaCreacion: DateTime.now(),
      activo: true,
      proyectoNombre: datos['area'], // ← "desarrollo 2"
    );

    debugPrint('✅ Equipo temporal creado:');
    debugPrint('   Nombre: ${equipoTemporal.nombre}');
    debugPrint('   Estado: ${equipoTemporal.estado}');
    debugPrint('   ID: ${equipoTemporal.numeroSerie}');
    debugPrint('   Área: ${equipoTemporal.proyectoNombre}');

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddAssetScreen(equipo: equipoTemporal),
      ),
    ).then((result) {
      if (result == true) {
        debugPrint('✅ Equipo guardado');

        // ✅ SIMPLEMENTE VOLVER (NO recargar aquí)
        if (mounted) {
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _lastScannedCode = null;
          });
          _resumeScanner();
        }
      }
    });
  }

  void _showErrorDialog(
    String qrCode, {
    String? error,
    bool esErrorRevision = false,
  }) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.8),
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              esErrorRevision ? Icons.warning : Icons.error_outline,
              color: esErrorRevision ? Colors.orange : Colors.red,
              size: 28,
            ),
            const SizedBox(width: 12),
            Text(esErrorRevision ? 'Error en Revisión' : 'QR No Registrado'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              esErrorRevision
                  ? 'No se pudo registrar el equipo en la revisión.'
                  : 'Este código QR no corresponde a ningún equipo en el inventario.',
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Código escaneado:',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 4),
                  SelectableText(
                    qrCode,
                    style: const TextStyle(
                      fontSize: 12,
                      fontFamily: 'RobotoMono',
                    ),
                  ),
                ],
              ),
            ),
            if (error != null) ...[
              const SizedBox(height: 12),
              Text(
                'Error: $error',
                style: TextStyle(
                  fontSize: 12,
                  color: esErrorRevision ? Colors.orange : Colors.red,
                ),
              ),
            ],
            if (esErrorRevision) ...[
              const SizedBox(height: 16),
              const Text(
                'Consejos:\n• El equipo ya pudo haber sido escaneado\n• Verifica que estás en la revisión correcta',
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedCode = null;
                });
                _resumeScanner();
              }
            },
            child: const Text('Reintentar'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              if (esErrorRevision && mounted) {
                setState(() {
                  _isProcessing = false;
                  _lastScannedCode = null;
                });
                _resumeScanner();
              }
              if (!esErrorRevision) {
                Navigator.pop(context); // Solo cerrar scanner si no es revisión
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Escanear QR', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) {
              final torchState = state.torchState;
              final isTorchOn = torchState == TorchState.on;
              final isTorchAvailable = torchState != TorchState.unavailable;

              return IconButton(
                icon: Icon(
                  isTorchOn ? Icons.flash_on : Icons.flash_off,
                  color: isTorchOn
                      ? Colors.yellow
                      : (isTorchAvailable ? Colors.grey : Colors.grey[800]),
                ),
                onPressed: isTorchAvailable
                    ? () => _controller.toggleTorch()
                    : null,
              );
            },
          ),
          ValueListenableBuilder<MobileScannerState>(
            valueListenable: _controller,
            builder: (context, state, child) {
              final cameraFacing = state.cameraDirection;
              final isBackCamera = cameraFacing == CameraFacing.back;

              final availableCameras = state.availableCameras ?? 0;
              if (availableCameras < 2) {
                return const SizedBox.shrink();
              }

              return IconButton(
                icon: Icon(
                  isBackCamera ? Icons.camera_rear : Icons.camera_front,
                  color: Colors.white,
                ),
                onPressed: () => _controller.switchCamera(),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) => _onBarcodeDetected(context, capture),
          ),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.5),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Stack(
                children: [
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: AnimatedBuilder(
                      animation: _scanLineAnimation,
                      builder: (context, child) {
                        return Container(
                          margin: EdgeInsets.only(
                            top: _scanLineAnimation.value,
                          ),
                          height: 2,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFF135BEC,
                                ).withValues(alpha: 0.5),
                                blurRadius: 8,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  ..._buildScanCorners(),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 50,
            left: 0,
            right: 0,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.qr_code_scanner,
                        color: Colors.white,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _isProcessing
                            ? 'Procesando...'
                            : 'Coloca el código QR en el recuadro',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (_isProcessing)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.primaryColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildScanCorners() {
    const cornerRadius = Radius.circular(16);
    return [
      Positioned(
        top: -2,
        left: -2,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.primaryColor, width: 4),
              left: BorderSide(color: AppTheme.primaryColor, width: 4),
            ),
            borderRadius: const BorderRadius.only(topLeft: cornerRadius),
          ),
        ),
      ),
      Positioned(
        top: -2,
        right: -2,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: AppTheme.primaryColor, width: 4),
              right: BorderSide(color: AppTheme.primaryColor, width: 4),
            ),
            borderRadius: const BorderRadius.only(topRight: cornerRadius),
          ),
        ),
      ),
      Positioned(
        bottom: -2,
        left: -2,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.primaryColor, width: 4),
              left: BorderSide(color: AppTheme.primaryColor, width: 4),
            ),
            borderRadius: const BorderRadius.only(bottomLeft: cornerRadius),
          ),
        ),
      ),
      Positioned(
        bottom: -2,
        right: -2,
        child: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppTheme.primaryColor, width: 4),
              right: BorderSide(color: AppTheme.primaryColor, width: 4),
            ),
            borderRadius: const BorderRadius.only(bottomRight: cornerRadius),
          ),
        ),
      ),
    ];
  }
}
