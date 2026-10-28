import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.state,
    this.role,
  });

  final AppState state;
  final String? role;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final TextEditingController emailController;
  late final TextEditingController passwordController;
  final formKey = GlobalKey<FormState>();

  bool obscure = true;
  late String currentRole;

  @override
  void initState() {
    super.initState();
    currentRole = widget.role ?? widget.state.selectedRole ?? 'student';
    final isLecturer = currentRole == 'lecturer' || currentRole == 'teacher';
    final isController = currentRole == 'controller' || currentRole == 'admin';

    String defaultEmail = 'student1@demo.edu';
    String defaultPass = 'student123';
    if (isLecturer) {
      defaultEmail = 'teacher@demo.edu';
      defaultPass = 'teach123';
    } else if (isController) {
      defaultEmail = 'controller@demo.edu';
      defaultPass = 'admin123';
    }

    emailController = TextEditingController(text: defaultEmail);
    passwordController = TextEditingController(text: defaultPass);
  }

  void _switchDemoRole(String role, String email, String pass) {
    setState(() {
      currentRole = role;
      emailController.text = email;
      passwordController.text = pass;
    });
    widget.state.setRole(role);
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (widget.state.busy) return;
    if (!formKey.currentState!.validate()) return;
    widget.state.setRole(currentRole);
    final success = await widget.state.login(
      emailController.text.trim(),
      passwordController.text.trim(),
    );

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    } else if (!success && mounted && widget.state.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.rose,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          content: Row(
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.state.error!,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLecturer = currentRole == 'lecturer' || currentRole == 'teacher';
    final isController = currentRole == 'controller' || currentRole == 'admin';
    final roleLabel = isController ? 'Academic Controller' : (isLecturer ? 'Lecturer' : 'Student');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          '$roleLabel Access',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppColors.ink),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.ink),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
            child: Form(
              key: formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Role Icon & Badge
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.25),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Icon(
                        isController
                            ? Icons.admin_panel_settings_rounded
                            : (isLecturer ? Icons.co_present_rounded : Icons.face_retouching_natural_rounded),
                        color: Colors.white,
                        size: 32,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  Center(
                    child: Text(
                      'Sign In as $roleLabel',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: AppColors.ink,
                        letterSpacing: -0.4,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      'Use campus institutional credentials to authenticate session',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.slate.withValues(alpha: 0.9),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Quick 1-Tap Demo Account Switcher
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x040F172A),
                          blurRadius: 8,
                          offset: Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Row(
                            children: [
                              Icon(Icons.bolt_rounded, size: 16, color: AppColors.amber),
                              SizedBox(width: 4),
                              Text(
                                'Instant 1-Tap Demo Logins:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.slate,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: _DemoRoleChip(
                                label: 'Student',
                                isSelected: currentRole == 'student',
                                onTap: () => _switchDemoRole('student', 'student1@demo.edu', 'student123'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _DemoRoleChip(
                                label: 'Faculty',
                                isSelected: isLecturer,
                                onTap: () => _switchDemoRole('lecturer', 'teacher@demo.edu', 'teach123'),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: _DemoRoleChip(
                                label: 'Controller',
                                isSelected: isController,
                                onTap: () => _switchDemoRole('controller', 'controller@demo.edu', 'admin123'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Main Input Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.border),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x060F172A),
                          blurRadius: 16,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Institutional Email',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: emailController,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(
                            hintText: isController
                                ? 'controller@demo.edu'
                                : (isLecturer ? 'teacher@demo.edu' : 'student1@demo.edu'),
                            prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20, color: AppColors.slate),
                            filled: true,
                            fillColor: AppColors.cardSubtle,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter your email address';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        const Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.ink,
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextFormField(
                          controller: passwordController,
                          obscureText: obscure,
                          decoration: InputDecoration(
                            hintText: 'Enter password',
                            prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20, color: AppColors.slate),
                            filled: true,
                            fillColor: AppColors.cardSubtle,
                            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            suffixIcon: IconButton(
                              icon: Icon(
                                obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                                size: 20,
                                color: AppColors.slate,
                              ),
                              onPressed: () => setState(() => obscure = !obscure),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.border),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14),
                              borderSide: const BorderSide(color: AppColors.primary, width: 2),
                            ),
                          ),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Enter your password';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 22),

                        // Login CTA Button (Forest Green)
                        AnimatedPressable(
                          onTap: widget.state.busy ? null : _login,
                          child: Container(
                            height: 52,
                            decoration: BoxDecoration(
                              gradient: AppColors.primaryGradient,
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.3),
                                  blurRadius: 14,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Center(
                              child: widget.state.busy
                                  ? const AppLottieLoader(
                                      size: 38,
                                      color: Colors.white,
                                    )
                                  : FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        'Authenticate as $roleLabel',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                          fontSize: 15.5,
                                          letterSpacing: -0.2,
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Server URL Chip
                        ValueListenableBuilder<String>(
                          valueListenable: AppConfig.activeUrlNotifier,
                          builder: (context, url, _) {
                            final isLan = AppConfig.isUsingLan;
                            return InkWell(
                              onTap: () async {
                                AppConfig.toggleServerUrl();
                                final mode = AppConfig.connectionModeLabel;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Switched to $mode (${AppConfig.apiBaseUrl})'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: AppColors.ink,
                                  ),
                                );
                                final healthy = await widget.state.api.checkHealth();
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        healthy ? 'Connected to $mode backend!' : 'Cannot reach $mode backend.',
                                      ),
                                      backgroundColor: healthy ? AppColors.emerald : AppColors.amber,
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              },
                              borderRadius: BorderRadius.circular(8),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
                                child: SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Container(
                                        width: 7,
                                        height: 7,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Server: ${isLan ? "Wi-Fi" : "USB"} · Tap to toggle',
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.slate,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DemoRoleChip extends StatelessWidget {
  const _DemoRoleChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardSubtle,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Center(
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? Colors.white : AppColors.slate,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
