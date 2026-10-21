import 'package:flutter/material.dart';

import '../state/app_state.dart';
import '../widgets/app_widgets.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.state});
  final AppState state;
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final email = TextEditingController(text: 'teacher@demo.edu');
  final password = TextEditingController(text: 'teach123');
  final formKey = GlobalKey<FormState>();
  bool obscure = true;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!formKey.currentState!.validate()) return;
    await widget.state.login(email.text, password.text);
    if (mounted && widget.state.error != null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(widget.state.error!)));
    }
  }

  void _fill(String address, String pass) {
    setState(() {
      email.text = address;
      password.text = pass;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                          width: 58,
                          height: 58,
                          decoration: BoxDecoration(
                              color: AppColors.teal,
                              borderRadius: BorderRadius.circular(18)),
                          child: const Icon(Icons.how_to_reg_rounded,
                              color: Colors.white, size: 32)),
                      const SizedBox(height: 24),
                      Text('Classroom\nattendance',
                          style: Theme.of(context).textTheme.headlineLarge),
                      const SizedBox(height: 12),
                      Text(
                          'A calmer way to take roll, review suggestions, and keep every student’s record clear.',
                          style: Theme.of(context).textTheme.bodyLarge),
                      const SizedBox(height: 28),
                      AppCard(
                        child: Form(
                          key: formKey,
                          child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Sign in to your demo account',
                                    style:
                                        Theme.of(context).textTheme.titleLarge),
                                const SizedBox(height: 18),
                                TextFormField(
                                    controller: email,
                                    keyboardType: TextInputType.emailAddress,
                                    textInputAction: TextInputAction.next,
                                    decoration: const InputDecoration(
                                        labelText: 'Email',
                                        prefixIcon:
                                            Icon(Icons.alternate_email)),
                                    validator: (v) =>
                                        v == null || !v.contains('@')
                                            ? 'Enter a valid email address'
                                            : null),
                                const SizedBox(height: 12),
                                TextFormField(
                                    controller: password,
                                    obscureText: obscure,
                                    onFieldSubmitted: (_) => _login(),
                                    decoration: InputDecoration(
                                        labelText: 'Password',
                                        prefixIcon:
                                            const Icon(Icons.lock_outline),
                                        suffixIcon: IconButton(
                                            tooltip: obscure
                                                ? 'Show password'
                                                : 'Hide password',
                                            onPressed: () => setState(
                                                () => obscure = !obscure),
                                            icon: Icon(obscure
                                                ? Icons.visibility_outlined
                                                : Icons
                                                    .visibility_off_outlined))),
                                    validator: (v) => v == null || v.isEmpty
                                        ? 'Enter your password'
                                        : null),
                                const SizedBox(height: 20),
                                SizedBox(
                                    width: double.infinity,
                                    child: FilledButton.icon(
                                        onPressed:
                                            widget.state.busy ? null : _login,
                                        icon: widget.state.busy
                                            ? const SizedBox(
                                                width: 18,
                                                height: 18,
                                                child:
                                                    CircularProgressIndicator(
                                                        strokeWidth: 2,
                                                        color: Colors.white))
                                            : const Icon(
                                                Icons.arrow_forward_rounded),
                                        label: const Text('Continue'))),
                                if (widget.state.error != null) ...[
                                  const SizedBox(height: 14),
                                  Text(widget.state.error!,
                                      style: const TextStyle(
                                          color: AppColors.coral,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ]),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text('Quick demo access',
                          style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      Wrap(spacing: 8, runSpacing: 8, children: [
                        OutlinedButton(
                            onPressed: () =>
                                _fill('teacher@demo.edu', 'teach123'),
                            child: const Text('Teacher demo')),
                        OutlinedButton(
                            onPressed: () =>
                                _fill('student1@demo.edu', 'student123'),
                            child: const Text('Student demo')),
                      ]),
                      const SizedBox(height: 22),
                      Text(
                          'Demo only • no face recognition • no photo or template retention • in-app notifications only',
                          style: Theme.of(context).textTheme.bodyMedium),
                    ]),
              ),
            ),
          ),
        ),
      );
}
