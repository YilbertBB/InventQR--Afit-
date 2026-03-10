import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/app_routes.dart';
import '../../core/app_theme.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Auto-completar con usuario root si es primera instalación
    _autoCompletarCredenciales();
  }

  Future<void> _autoCompletarCredenciales() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstInstall = prefs.getBool('is_first_install') ?? true;

    if (isFirstInstall) {
      _emailController.text = 'root';
      _passwordController.text = 'root';
      await prefs.setBool('is_first_install', false);
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login(BuildContext context) async {
    final username = _emailController.text.trim();
    final password = _passwordController.text;

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ingrese usuario y contraseña')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      final loginExitoso = await authProvider.login(username, password);

      if (loginExitoso) {
        final esRoot = authProvider.esUsuarioRoot;
        if (esRoot) {
          // Verificar si root ya no debería existir
          if (authProvider.rootDebeEstarRestringido) {
            // Forzar logout
            await authProvider.logout();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('El usuario root ya no está disponible'),
                  backgroundColor: Colors.orange,
                ),
              );
            }

            return;
          }
          if (context.mounted) {
            AppRoutes.goToDashboard(context);
          }
        } else {
          // Usuario normal, ir a dashboard normal
          if (context.mounted) {
            AppRoutes.goToDashboard(context);
          }
        }
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                authProvider.errorMensaje ?? 'Error de autenticación',
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    final cardColor = Theme.of(context).cardColor;
    final borderColor = Theme.of(context).dividerColor;
    final textColor = Theme.of(context).colorScheme.onSurface;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            // Contenido principal
            Column(
              children: [
                // Barra de navegación superior
                _buildTopBar(textColor, backgroundColor),

                // Contenido principal
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      children: [
                        const SizedBox(height: 20),

                        // Logo y título
                        _buildLogoSection(primaryColor, textColor, isDark),
                        const SizedBox(height: 40),

                        // Formulario de login
                        _buildLoginForm(
                          primaryColor,
                          cardColor,
                          borderColor,
                          textColor,
                          isDark,
                        ),
                      ],
                    ),
                  ),
                ),
                // Footer
                _buildFooter(isDark),
              ],
            ),

            // Loading overlay
            if (_isLoading)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(Color textColor, Color backgroundColor) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 48, 16, 16),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.8),
        backgroundBlendMode: BlendMode.srcOver,
      ),
      alignment: Alignment.center,
      child: Text(
        'InventQR',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
          letterSpacing: -0.3,
        ),
      ),
    );
  }

  Widget _buildLogoSection(Color primaryColor, Color textColor, bool isDark) {
    return Column(
      children: [
        // Logo con icono
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            Icons.inventory_2,
            color: primaryColor,
            size: 48,
            weight: 300,
          ),
        ),
        const SizedBox(height: 16),

        // Título
        Text(
          'Bienvenido',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: textColor,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 8),

        // Subtítulo
        Text(
          'Gestión de Activos TI por departamento',
          style: TextStyle(
            fontSize: 16,
            color: isDark ? const Color(0xFF9CA3AF) : const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginForm(
    Color primaryColor,
    Color cardColor,
    Color borderColor,
    Color textColor,
    bool isDark,
  ) {
    return Column(
      children: [
        // Campo de usuario/email
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Usuario',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark
                      ? const Color(0xFFD1D5DB)
                      : const Color(0xFF374151),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      Icons.person_outline,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _emailController,
                      style: TextStyle(fontSize: 16, color: textColor),
                      decoration: InputDecoration(
                        hintText: 'Nombre de Usuario',
                        hintStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF9DA6B9)
                              : const Color(0xFF9CA3AF),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Campo de contraseña
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Contraseña',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: isDark
                          ? const Color(0xFFD1D5DB)
                          : const Color(0xFF374151),
                    ),
                  ),
                ],
              ),
            ),
            Container(
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor, width: 1),
              ),
              child: Row(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16, right: 8),
                    child: Icon(
                      Icons.lock_outline,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      style: TextStyle(fontSize: 16, color: textColor),
                      decoration: InputDecoration(
                        hintText: '••••••••',
                        hintStyle: TextStyle(
                          color: isDark
                              ? const Color(0xFF9DA6B9)
                              : const Color(0xFF9CA3AF),
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 20,
                          horizontal: 8,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: isDark
                          ? const Color(0xFF9CA3AF)
                          : const Color(0xFF6B7280),
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 32),

        // Botón de iniciar sesión
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: () {
              _isLoading ? null : _login(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 4,
              shadowColor: primaryColor.withValues(alpha: 0.2),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Iniciar Sesión',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 24),

        // Información para primera vez
        _buildFirstTimeInfo(primaryColor, isDark),
        const SizedBox(height: 24),

        // Nota de seguridad
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            'Acceso seguro cifrado localmente para consulta de inventario TI.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFirstTimeInfo(Color primaryColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryColor.withValues(alpha: 0.1)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: primaryColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Primera vez: Use usuario "root" con contraseña "root". '
              'Cree un nuevo usuario administrador y el usuario root se eliminará automáticamente.',
              style: TextStyle(
                fontSize: 12,
                color: isDark
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFF6B7280),
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Text(
            'Versión 2.4.0 (Build 88)',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? const Color(0xFF6B7280) : const Color(0xFF9CA3AF),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppTheme.successColor,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Base de datos local',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFF6B7280)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
