import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:ds_clickeat_web_admin/features/auth/controllers/login_controller.dart';
import 'package:ds_clickeat_web_admin/features/auth/controllers/session_controller.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  bool _obscure = true;
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _loading = true);
    try {
      final ok = await ref
          .read(loginControllerProvider.notifier)
          .login(_email.text.trim(), _pass.text);

      if (!mounted) return;

      if (ok) {
        await ref.read(sessionControllerProvider.notifier).bootstrap();
        if (!mounted) return;
        context.go('/app/products');
      } else {
        final err = ref.read(loginControllerProvider).error ??
            'No se pudo iniciar sesión';
        _showErrorDialog(err);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.white,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 4),
                  const Icon(Icons.error_outline, color: Colors.red, size: 34),
                  const SizedBox(height: 10),
                  const Text(
                    'No se pudo iniciar sesión',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 15),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 46,
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF1F2E4D),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(28),
                        ),
                      ),
                      onPressed: () => Navigator.of(ctx).pop(),
                      child: const Text('Entendido'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final logged = ref.watch(sessionControllerProvider) != null;
    if (logged) {
      Future.microtask(() {
        if (context.mounted) context.go('/app/products');
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F2),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Center(
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 690),
                    child: Card(
                      color: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 32, vertical: 36),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/images/ClickEat-logo-48.png',
                                    width: 40,
                                    height: 40,
                                  ),
                                  const SizedBox(width: 10),
                                  RichText(
                                    text: const TextSpan(
                                      style: TextStyle(
                                        fontSize: 28,
                                        fontWeight: FontWeight.w800,
                                        height: 1.0,
                                        letterSpacing: .3,
                                      ),
                                      children: [
                                        TextSpan(
                                            text: 'Click',
                                            style: TextStyle(
                                                color: Colors.black)),
                                        TextSpan(
                                            text: 'Eat',
                                            style: TextStyle(
                                                color: Color(0xFFF9B93B))),
                                        TextSpan(
                                            text: ' - Admin',
                                            style: TextStyle(
                                                color: Colors.black)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Iniciar sesión',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleLarge
                                      ?.copyWith(
                                        color: Colors.black,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Correo',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 56,
                                child: TextFormField(
                                  controller: _email,
                                  decoration: const InputDecoration(
                                    hintText: 'usuario@clickeat.com',
                                    border: OutlineInputBorder(),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (v) {
                                    if (v == null || v.trim().isEmpty) {
                                      return 'Ingresa tu correo';
                                    }
                                    final ok = RegExp(r'^[^@]+@[^@]+\.[^@]+')
                                        .hasMatch(v);
                                    return ok ? null : 'Correo inválido';
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Align(
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Contraseña',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.black,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 56,
                                child: TextFormField(
                                  controller: _pass,
                                  obscureText: _obscure,
                                  decoration: InputDecoration(
                                    border: const OutlineInputBorder(),
                                    hintText: 'Contraseña',
                                    suffixIcon: IconButton(
                                      onPressed: () =>
                                          setState(() => _obscure = !_obscure),
                                      icon: Icon(_obscure
                                          ? Icons.visibility
                                          : Icons.visibility_off),
                                    ),
                                  ),
                                  validator: (v) => (v == null || v.isEmpty)
                                      ? 'Ingresa tu contraseña'
                                      : null,
                                ),
                              ),
                              const SizedBox(height: 28),
                              SizedBox(
                                width: double.infinity,
                                height: 60,
                                child: FilledButton(
                                  onPressed: _loading ? null : _submit,
                                  style: FilledButton.styleFrom(
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    backgroundColor: const Color(0xFF1F2E4D),
                                  ),
                                  child: _loading
                                      ? const SizedBox(
                                          width: 22,
                                          height: 22,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('Ingresar',
                                          style: TextStyle(
                                              fontSize: 18,
                                              fontWeight: FontWeight.w700)),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
