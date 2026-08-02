import 'package:afit_prueba1/screen/workers/workers_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/equipo_provider.dart';
import '../screen/auth/create_user_screen.dart';
import '../screen/inventory/add_asset_screen.dart';
import '../screen/reports/audit_history_screen.dart';
import '../screen/backup/backup_management_screen.dart';
import '../screen/dashboard/dashboard_screen.dart';
import '../screen/departments/departments_screen.dart';
import '../screen/inventory/history_screen.dart';
import '../screen/inventory/history_traslado_screen.dart';
import '../screen/inventory/import_excel_screen.dart';
import '../screen/inventory/inventory_screen.dart';
import '../screen/auth/login_screen.dart';
import '../screen/auth/profile_screen.dart';
import '../screen/reports/report_screen.dart';
import '../screen/reports/revision_progreso_page.dart';
import '../screen/scanner_screen.dart';
import '../screen/reports/seleccionar_departamento_page.dart';
import '../screen/splash_screen.dart';
import '../screen/inventory/transfer_screen.dart';
import '../screen/auth/user_list_screen.dart';
import '../screen/welcome_screen.dart';
import '../providers/auth_provider.dart';
import '../utils/permission_guard.dart';

class AppRoutes {
  // Ruta inicial
  static const String initial = '/';
  // Rutas de autenticación
  static const String welcome = '/welcome';
  static const String login = '/login';

  // Rutas principales
  static const String dashboard = '/dashboard';
  static const String inventory = '/inventory';
  static const String addAsset = '/add-asset';
  static const String trasladarUtencilio = '/trasladar-utencilio';
  static const String historialTraslado = '/historial-traslado';
  static const String addDepartamento = '/add-departamento';
  static const String scanner = '/scanner';
  static const String missingReport = '/missing-report';
  static const String progresoReport = '/progreso-report';
  static const String importExcel = '/import-excel';

  // Nuevas rutas
  static const String departments = '/departments';
  static const String selectDepartments = '/select-departments';
  static const String inventoryDepartments = '/inventory-departments';
  static const String assetDetail = '/asset-detail';
  static const String auditHistory = '/audit-history';
  static const String profile = '/profile';
  static const users = '/users';
  static const createUser = '/users/create';
  static const editUser = '/users/edit';
  static const workers = '/workers';
  static const workerDetails = '/worker/details';
  static const workerAdd = '/worker/add';
  static const String backups = '/backups';
  static const String historyActivity = '/history-activity';

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static Map<String, WidgetBuilder> routes() {
    return {
      // Pantalla de splash inicial
      initial: (context) => const SplashScreen(),

      // Pantalla de bienvenida (inicial)
      welcome: (context) => const WelcomeScreen(),

      // Pantalla de login
      login: (context) => LoginScreen(),

      // Dashboard principal (reemplaza la anterior)
      dashboard: (context) => const DashboardScreen(),

      // Otras pantallas del flujo principal
      inventory: (context) => const InventoryScreen(),
      addAsset: (context) => const AddAssetScreen(),
      trasladarUtencilio: (context) => const TransferScreen(),
      historialTraslado: (context) => HistoryScreen(),
      scanner: (context) => const ScannerScreen(),
      missingReport: (context) => const ReporteRevisionPage(),
      progresoReport: (context) => const RevisionProgresoPage(),
      importExcel: (context) => const ImportExcelScreen(),

      // Nuevas pantallas
      departments: (context) => const DepartmentsScreen(),
      selectDepartments: (context) => const SeleccionarDepartamentoPage(),
      auditHistory: (context) => const AuditHistoryScreen(),
      profile: (context) => const ProfileScreen(),
      createUser: (context) => const CreateEditUserScreen(),
      users: (context) => UserListScreen(),
      workers: (context) => WorkersScreen(),
      // workerDetails: (context) => WorkerDetailScreen(),
      backups: (context) => BackupManagementScreen(),
      historyActivity: (context) {
        return AllActivitiesHistoryScreen();
      },
    };
  }

  // Métodos de navegación actualizados
  static void goToWelcome(BuildContext context) {
    navigatorKey.currentState?.pushReplacementNamed(welcome);
  }

  static void goToLogin(BuildContext context) {
    navigatorKey.currentState?.pushReplacementNamed(login);
  }

  static void goToDashboard(BuildContext context) {
    navigatorKey.currentState?.pushReplacementNamed(dashboard);
  }

  static void goToInventory(BuildContext context) {
    navigatorKey.currentState?.pushNamed(inventory);
  }

  static bool _puedeAcceder(BuildContext context, String permiso) {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    if (PermissionGuard.canAccess(authProvider.usuarioActual, permiso)) {
      return true;
    }

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No tiene permisos para esta acción'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }

    return false;
  }

  static void goToAddAsset(BuildContext context) {
    if (!_puedeAcceder(context, 'gestion_equipos')) return;
    navigatorKey.currentState?.pushNamed(addAsset);
  }

  static void goToTrasladarUtencilio(BuildContext context) {
    if (!_puedeAcceder(context, 'trasladar')) return;
    navigatorKey.currentState?.pushNamed(trasladarUtencilio);
  }

  static void goToHistorialTraslado(BuildContext context) {
    navigatorKey.currentState?.pushNamed(historialTraslado);
  }

  static void goToAddDepartamento(BuildContext context) {
    navigatorKey.currentState?.pushNamed(addDepartamento);
  }

  static void goToInventoryDepartamento(BuildContext context) {
    navigatorKey.currentState?.pushNamed(inventoryDepartments);
  }

  static Future<void> goToScanner(BuildContext context) async {
    if (!_puedeAcceder(context, 'escanear')) return;

    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );

    if (context.mounted && result == true) {
      context.read<EquipoProvider>().cargarEquipos();
    }
  }

  static void goToMissingReport(BuildContext context) {
    navigatorKey.currentState?.pushNamed(missingReport);
  }

  static void goToProgresoReport(BuildContext context) {
    navigatorKey.currentState?.pushNamed(progresoReport);
  }

  static void goToImportExcel(BuildContext context) {
    if (!_puedeAcceder(context, 'importar')) return;
    navigatorKey.currentState?.pushNamed(importExcel);
  }

  // Nuevos métodos de navegación
  static void goToDepartments(BuildContext context) {
    navigatorKey.currentState?.pushNamed(departments);
  }

  static void goToSelectDepartments(BuildContext context) {
    navigatorKey.currentState?.pushNamed(selectDepartments);
  }

  static void goToAssetDetail(BuildContext context) {
    navigatorKey.currentState?.pushNamed(assetDetail);
  }

  static void goToAuditHistory(BuildContext context) {
    navigatorKey.currentState?.pushNamed(auditHistory);
  }

  static void goToProfile(BuildContext context) {
    navigatorKey.currentState?.pushNamed(profile);
  }

  static void goToCreateUser(BuildContext context) {
    navigatorKey.currentState?.pushNamed(createUser);
  }

  static void goToUserList(BuildContext context) {
    navigatorKey.currentState?.pushNamed(users);
  }

  static void goToWorkers(BuildContext context) {
    navigatorKey.currentState?.pushNamed(workers);
  }

  static void goToWorkerDetail(BuildContext context) {
    navigatorKey.currentState?.pushNamed(workerDetails);
  }

  static void goToWorkerAdd(BuildContext context) {
    navigatorKey.currentState?.pushNamed(workerAdd);
  }

  static void goToBackups(BuildContext context) {
    navigatorKey.currentState?.pushNamed(backups);
  }

  static void goToHistoryActivity(BuildContext context) {
    navigatorKey.currentState?.pushNamed(historyActivity);
  }

  static void goBack(BuildContext context) {
    if (navigatorKey.currentState?.canPop() ?? false) {
      navigatorKey.currentState?.pop();
    }
  }
}
