import 'package:afit_prueba1/providers/departamento_provider.dart';
import 'package:afit_prueba1/providers/equipo_provider.dart';
import 'package:afit_prueba1/providers/revision_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter/foundation.dart';

import 'core/app_routes.dart';
import 'database/database_helper.dart';
import 'providers/asignacion_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/trabajador_provider.dart';
import 'providers/traslado_provider.dart';

const _lastActivityKey = 'idle_last_activity_ms';
const _timeoutKey = 'idle_timeout_ms';
const _sessionExpiredKey = 'session_expired';
const _logoutTaskUniqueName = 'idle_logout_task';
const _logoutTaskName = 'idle_logout_task';

bool get _isAndroid =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    WidgetsFlutterBinding.ensureInitialized();
    final prefs = await SharedPreferences.getInstance();
    final lastMs = prefs.getInt(_lastActivityKey);
    final timeoutMs = prefs.getInt(_timeoutKey);

    if (lastMs == null || timeoutMs == null) {
      return Future.value(true);
    }

    final last = DateTime.fromMillisecondsSinceEpoch(lastMs);
    final diff = DateTime.now().difference(last);
    if (diff.inMilliseconds >= timeoutMs) {
      await prefs.remove('usuario_id');
      await prefs.remove('usuario_rol');
      await prefs.remove('usuario_nombre');
      await prefs.remove('usuario_email');
      await prefs.setBool(_sessionExpiredKey, true);
    }

    return Future.value(true);
  });
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar base de datos
  await DatabaseHelper.instance.database;

  if (_isAndroid) {
    await Workmanager().initialize(callbackDispatcher);
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => TrabajadorProvider()),
        ChangeNotifierProvider(create: (_) => DepartamentoProvider()),
        ChangeNotifierProvider(create: (_) => EquipoProvider()),
        ChangeNotifierProvider(create: (_) => AsignacionProvider()),
        ChangeNotifierProvider(create: (_) => TrasladoProvider()),
        ChangeNotifierProvider(create: (_) => RevisionProvider()),
      ],
      child: IdleTimeout(
        timeout: const Duration(hours: 1),
        child: MaterialApp(
          title: 'Gestión de Inventario TI',
          theme: ThemeData(
            primarySwatch: Colors.blue,
            visualDensity: VisualDensity.adaptivePlatformDensity,
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF135BEC),
              elevation: 2,
            ),
          ),
          // Usa SplashScreen como ruta inicial
          initialRoute: '/',
          routes: AppRoutes.routes(),
          navigatorKey: AppRoutes.navigatorKey,
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}

class IdleTimeout extends StatefulWidget {
  const IdleTimeout({super.key, required this.child, required this.timeout});

  final Widget child;
  final Duration timeout;

  @override
  State<IdleTimeout> createState() => _IdleTimeoutState();
}

class _IdleTimeoutState extends State<IdleTimeout> with WidgetsBindingObserver {
  Timer? _checkTimer;
  DateTime _lastActivity = DateTime.now();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _persistTimeout();
    _restoreLastActivity();
    _startPeriodicCheck();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _checkTimer?.cancel();
    super.dispose();
  }

  void _startPeriodicCheck() {
    _checkTimer?.cancel();
    _checkTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => _checkIdle(),
    );
  }

  Future<void> _restoreLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    final savedMs = prefs.getInt(_lastActivityKey);
    if (savedMs != null) {
      _lastActivity = DateTime.fromMillisecondsSinceEpoch(savedMs);
    }
    await _checkIdle();
  }

  Future<void> _persistTimeout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_timeoutKey, widget.timeout.inMilliseconds);
  }

  Future<void> _persistLastActivity() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActivityKey, _lastActivity.millisecondsSinceEpoch);
  }

  void _markActivity() {
    _lastActivity = DateTime.now();
    _persistLastActivity();
  }

  Future<void> _handleTimeout() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.estaAutenticado) {
      return;
    }

    await authProvider.logout();
    if (!mounted) return;
    AppRoutes.goToLogin(context);
  }

  Future<void> _checkIdle() async {
    if (!mounted) return;
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.estaAutenticado) return;

    final diff = DateTime.now().difference(_lastActivity);
    if (diff >= widget.timeout) {
      await _handleTimeout();
    }
  }

  Future<void> _scheduleBackgroundLogout() async {
    if (!_isAndroid) return;
    final authProvider = context.read<AuthProvider>();
    if (!authProvider.estaAutenticado) return;

    final diff = DateTime.now().difference(_lastActivity);
    var delay = widget.timeout - diff;
    if (delay.isNegative) {
      delay = const Duration(seconds: 1);
    }

    await Workmanager().registerOneOffTask(
      _logoutTaskUniqueName,
      _logoutTaskName,
      existingWorkPolicy: ExistingWorkPolicy.replace,
      initialDelay: delay,
      constraints: Constraints(
        networkType: NetworkType.notRequired,
        requiresBatteryNotLow: false,
        requiresCharging: false,
        requiresDeviceIdle: false,
        requiresStorageNotLow: false,
      ),
    );
  }

  Future<void> _cancelBackgroundLogout() async {
    if (!_isAndroid) return;
    await Workmanager().cancelByUniqueName(_logoutTaskUniqueName);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _cancelBackgroundLogout();
      _checkIdle();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _persistLastActivity();
      _scheduleBackgroundLogout();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Focus(
      autofocus: true,
      onKeyEvent: (_, _) {
        _markActivity();
        return KeyEventResult.ignored;
      },
      child: Listener(
        behavior: HitTestBehavior.translucent,
        onPointerDown: (_) => _markActivity(),
        onPointerMove: (_) => _markActivity(),
        onPointerUp: (_) => _markActivity(),
        onPointerCancel: (_) => _markActivity(),
        child: widget.child,
      ),
    );
  }
}
