// ============================================================
// Solar-Grow - Pantalla de Registro
// ============================================================
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';

/// Pantalla de registro con email, contraseña y Google Sign-In
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.register(
      email: _emailController.text.trim(),
      password: _passwordController.text,
      fullName: _nameController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: SolarColors.background,
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              children: [
                const SizedBox(height: 40),
                // Logo Solar-Grow
                _buildLogo(),
                const SizedBox(height: 32),
                // Formulario de registro
                _buildForm(),
                const SizedBox(height: 16),
                // Mensaje de error
                _buildErrorMessage(),
                // Botón de registro
                _buildRegisterButton(),
                const SizedBox(height: 20),
                // Separador
                _buildDivider(),
                const SizedBox(height: 16),
                // Google Sign In
                _buildGoogleButton(),
                const SizedBox(height: 24),
                // Login link
                _buildLoginLink(),
                const SizedBox(height: 12),
                // Modo demo
                _buildDemoButton(),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: SolarColors.primary.withValues(alpha: 0.15),
                blurRadius: 20,
                spreadRadius: 2,
              ),
            ],
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('☀️', style: TextStyle(fontSize: 20)),
              Text('🔋', style: TextStyle(fontSize: 14)),
              Text('🌱', style: TextStyle(fontSize: 28)),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Solar-Grow',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: SolarColors.primaryDark,
          ),
        ),
      ],
    );
  }

  Widget _buildForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Regístrate',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: SolarColors.textPrimary,
              ),
            ),
            const SizedBox(height: 20),
            // Nombre
            const Text(
              'Nombre',
              style: TextStyle(
                color: SolarColors.skyBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Tu nombre completo',
                prefixIcon: Icon(
                  Icons.person_outline,
                  color: SolarColors.textLight,
                ),
              ),
            ),
            const SizedBox(height: 14),
            // Email
            const Text(
              'Email',
              style: TextStyle(
                color: SolarColors.skyBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(
                hintText: 'correo@ejemplo.com',
                prefixIcon: Icon(
                  Icons.email_outlined,
                  color: SolarColors.textLight,
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa tu correo electrónico';
                }
                if (!value.contains('@')) {
                  return 'Ingresa un correo válido';
                }
                return null;
              },
            ),
            const SizedBox(height: 14),
            // Contraseña
            const Text(
              'Contraseña',
              style: TextStyle(
                color: SolarColors.skyBlue,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              decoration: InputDecoration(
                hintText: '••••••••',
                prefixIcon: const Icon(
                  Icons.lock_outline,
                  color: SolarColors.textLight,
                ),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_off : Icons.visibility,
                    color: SolarColors.textLight,
                  ),
                  onPressed: () {
                    setState(() => _obscurePassword = !_obscurePassword);
                  },
                ),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Ingresa una contraseña';
                }
                if (value.length < 6) {
                  return 'Mínimo 6 caracteres';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        if (auth.errorMessage != null && auth.status == AuthStatus.error) {
          return Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: SolarColors.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: SolarColors.error,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      auth.errorMessage!,
                      style: const TextStyle(
                        color: SolarColors.error,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRegisterButton() {
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return Padding(
          padding: const EdgeInsets.only(top: 16),
          child: SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: auth.status == AuthStatus.loading ? null : _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: SolarColors.skyBlue,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: auth.status == AuthStatus.loading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    )
                  : const Text(
                      'Registrarse',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildDivider() {
    return Row(
      children: [
        Expanded(
          child: Divider(color: SolarColors.textLight.withValues(alpha: 0.3)),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'O',
            style: TextStyle(color: SolarColors.textLight, fontSize: 13),
          ),
        ),
        Expanded(
          child: Divider(color: SolarColors.textLight.withValues(alpha: 0.3)),
        ),
      ],
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: () {
          // TODO: Implementar Google Sign In
        },
        icon: const Text('🔍', style: TextStyle(fontSize: 20)),
        label: const Text(
          'Continuar con Google',
          style: TextStyle(
            color: SolarColors.textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: SolarColors.textLight.withValues(alpha: 0.3)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginLink() {
    return TextButton(
      onPressed: () {
        Navigator.of(context).pushReplacementNamed('/login');
      },
      child: const Text.rich(
        TextSpan(
          text: '¿Ya tienes cuenta? ',
          style: TextStyle(color: SolarColors.textLight),
          children: [
            TextSpan(
              text: 'Inicia sesión',
              style: TextStyle(
                color: SolarColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDemoButton() {
    return TextButton.icon(
      onPressed: () {
        context.read<AuthProvider>().enterDemoMode();
        Navigator.of(context).pushReplacementNamed('/home');
      },
      icon: const Icon(
        Icons.play_circle_outline,
        color: SolarColors.secondary,
        size: 20,
      ),
      label: const Text(
        'Modo Demo (sin servidor)',
        style: TextStyle(
          color: SolarColors.secondary,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
      ),
    );
  }
}
