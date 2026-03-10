import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/app_routes.dart';
import '../providers/auth_provider.dart';
import '../services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String _mensajeEstado = 'Inicializando...';
  bool _permisosConcedidos = false;
  bool _carpetasCreadas = false;

  @override
  void initState() {
    super.initState();
    _inicializarApp();
  }

  Future<void> _inicializarApp() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);

    // 1️⃣ SOLICITAR PERMISOS DE ALMACENAMIENTO
    setState(() {
      _mensajeEstado = 'Solicitando permisos de almacenamiento...';
    });

    final tienePermisos =
        await StorageService.solicitarPermisosAlmacenamiento();

    setState(() {
      _permisosConcedidos = tienePermisos;
    });

    if (tienePermisos) {
      // 2️⃣ CREAR CARPETAS DE LA APP
      setState(() {
        _mensajeEstado = 'Creando carpetas de la aplicación...';
      });

      try {
        await StorageService.inicializarCarpetas();
        setState(() {
          _carpetasCreadas = true;
          _mensajeEstado = 'Carpetas creadas correctamente';
        });
        debugPrint('✅ Carpetas de la app creadas');
      } catch (e) {
        debugPrint('❌ Error creando carpetas: $e');
        setState(() {
          _mensajeEstado = 'Error al crear carpetas';
        });
      }
    } else {
      setState(() {
        _mensajeEstado =
            'Permisos denegados - Algunas funciones serán limitadas';
      });

      // Opcional: Mostrar diálogo explicativo
      _mostrarDialogoPermisos();
    }

    // 3️⃣ INICIALIZAR DATOS DEL PROVIDER
    setState(() {
      _mensajeEstado = 'Cargando datos...';
    });

    await authProvider.inicializarDatos();

    // 4️⃣ VERIFICAR SESIÓN ACTIVA
    setState(() {
      _mensajeEstado = 'Verificando sesión...';
    });

    final tieneSesion = await authProvider.verificarSesionActiva();

    // 5️⃣ ESPERAR UN POCO Y NAVEGAR
    await Future.delayed(const Duration(milliseconds: 1500));

    if (mounted) {
      if (tieneSesion) {
        AppRoutes.goToDashboard(context);
      } else {
        final prefs = await SharedPreferences.getInstance();
        final isFirstTime = prefs.getBool('is_first_time') ?? true;
        if (isFirstTime) {
          AppRoutes.goToWelcome(context);
        } else {
          AppRoutes.goToLogin(context);
        }
      }
    }
  }

  void _mostrarDialogoPermisos() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permisos necesarios'),
        content: const Text(
          'La aplicación necesita permisos de almacenamiento para guardar:\n\n'
          '• Copias de seguridad de la base de datos\n'
          '• Archivos Excel exportados\n'
          '• Códigos QR generados\n\n'
          'Puedes conceder los permisos desde la configuración de la app.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continuar sin permisos'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              openAppSettings(); // Abrir configuración de la app
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            child: const Text('Abrir configuración'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryColor,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo o ícono
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.inventory_2,
                  size: 80,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 20),

              // Nombre de la app
              const Text(
                'InventQR',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),

              const Text(
                'Control de Activos TI',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 40),

              // Indicador de progreso
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 24),

              // Mensaje de estado
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _mensajeEstado,
                  style: const TextStyle(color: Colors.white, fontSize: 14),
                ),
              ),
              const SizedBox(height: 16),

              // Indicadores de progreso específicos
              Column(
                children: [
                  _buildStatusIndicator(
                    'Permisos de almacenamiento',
                    _permisosConcedidos,
                  ),
                  const SizedBox(height: 8),
                  _buildStatusIndicator('Carpetas de la app', _carpetasCreadas),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator(String texto, bool completado) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          completado ? Icons.check_circle : Icons.pending,
          size: 16,
          color: completado ? Colors.green[300] : Colors.orange[300],
        ),
        const SizedBox(width: 8),
        Text(
          texto,
          style: TextStyle(
            color: completado ? Colors.green[100] : Colors.orange[100],
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
