import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/app_routes.dart';
import '../core/app_theme.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final primaryColor = AppTheme.primaryColor;
    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(color: backgroundColor),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Espacio superior
                  const SizedBox(height: 20),

                  // Logo
                  _buildLogo(primaryColor),
                  const SizedBox(height: 20),

                  // Ilustración
                  _buildIllustration(primaryColor),
                  const SizedBox(height: 28),

                  // Texto
                  _buildTextContent(primaryColor),
                  const SizedBox(height: 40),

                  // Botones
                  _buildButtonSection(context, primaryColor),

                  // Footer
                  const SizedBox(height: 20),
                  _buildFooter(),

                  // Espacio final
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withValues(alpha: 0.1),
            blurRadius: 10,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Icon(Icons.inventory_2, color: primaryColor, size: 52),
    );
  }

  Widget _buildIllustration(Color primaryColor) {
    return SizedBox(
      width: 250,
      height: 120,
      child: Stack(
        children: [
          // Contenedor de la ilustración
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.transparent,
            ),
            child: Center(
              child: Icon(
                Icons.laptop_mac,
                size: 90,
                color: Colors.black.withValues(
                  alpha: 0.8,
                ), // Color para modo claro
              ),
            ),
          ),

          // Efecto de brillo
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.6,
                  colors: [
                    primaryColor.withValues(
                      alpha: 0.08,
                    ), // Más suave para modo claro
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextContent(Color primaryColor) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 300),
      child: Column(
        children: [
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle(
                fontSize: 32,
                fontWeight: FontWeight.bold,
                height: 1.3,
                color: Color(0xFF111827), // Texto oscuro para modo claro
              ),
              children: [
                const TextSpan(text: 'Bienvenida al\n'),
                TextSpan(
                  text: 'Sistema TI',
                  style: TextStyle(
                    color: primaryColor,
                    shadows: [
                      Shadow(
                        color: primaryColor.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Optimiza, escanea y controla tus activos TI por departamento en segundos.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.normal,
                color: Colors.grey[700], // Gris más oscuro para modo claro
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonSection(BuildContext context, Color primaryColor) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 320),
      child: Column(
        children: [
          // Botón primario
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              onPressed: () async {
                // Marcar que ya no es la primera vez
                final prefs = await SharedPreferences.getInstance();
                await prefs.setBool('is_first_time', false);
                if (!context.mounted) return;

                // Navegar al login
                AppRoutes.goToLogin(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 6,
                shadowColor: primaryColor.withValues(alpha: 0.4),
              ),
              child: const Text(
                'Iniciar Sesión',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Text(
        'Versión 1.0.2 • Secure Cloud',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 1.2,
          color: Colors.grey[600], // Gris medio para modo claro
        ),
      ),
    );
  }
}
