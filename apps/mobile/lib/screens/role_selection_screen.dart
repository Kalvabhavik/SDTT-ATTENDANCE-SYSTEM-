import 'package:flutter/material.dart';
import '../config/app_config.dart';
import '../state/app_state.dart';
import '../widgets/app_widgets.dart';
import 'login_screen.dart';

class RoleSelectionScreen extends StatelessWidget {
  const RoleSelectionScreen({super.key, required this.state});
  final AppState state;

  void _chooseRole(BuildContext context, String role) {
    state.setRole(role);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LoginScreen(state: state, role: role),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 16),

                      // Brand Monogram & Minimal Organic Badge
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            gradient: AppColors.primaryGradient,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.28),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: const Center(
                            child: Icon(
                              Icons.spa_rounded,
                              color: Colors.white,
                              size: 30,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Tagline chip
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppColors.emeraldBg,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: AppColors.emeraldBorder),
                          ),
                          child: const Text(
                            'ATTENDRIX BIOMETRICS v2.4',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          'Classroom Attendance',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w900,
                            color: AppColors.ink,
                            letterSpacing: -0.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Center(
                        child: Text(
                          'Zero-Proxy Verification • Active Liveness • 180° Classroom Sweep',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: AppColors.slate,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      const Text(
                        'Select Your Institutional Role',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.ink,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // 1. Student Card
                      _RoleCard(
                        title: 'Student Portal',
                        badge: 'ACTIVE LIVENESS & RADAR',
                        description: 'Self-verify presence with 4-step head pose & blink liveness plus 180° classroom sweep.',
                        icon: Icons.face_retouching_natural_rounded,
                        iconBg: AppColors.emeraldBg,
                        iconColor: AppColors.primary,
                        badgeBg: AppColors.emeraldBg,
                        badgeColor: AppColors.primary,
                        onTap: () => _chooseRole(context, 'student'),
                      ),
                      const SizedBox(height: 12),

                      // 2. Lecturer Card
                      _RoleCard(
                        title: 'Faculty / Lecturer',
                        badge: 'LIVE CLASSROOM CONSOLE',
                        description: 'Launch timed attendance sessions, monitor live check-in feed, and review anti-proxy flags.',
                        icon: Icons.co_present_rounded,
                        iconBg: const Color(0xFFE6F4F1),
                        iconColor: AppColors.primaryDark,
                        badgeBg: const Color(0xFFE6F4F1),
                        badgeColor: AppColors.primaryDark,
                        onTap: () => _chooseRole(context, 'lecturer'),
                      ),
                      const SizedBox(height: 12),

                      // 3. Controller Card
                      _RoleCard(
                        title: 'Academic Controller',
                        badge: 'INSTITUTIONAL INTEGRITY',
                        description: 'Configure classroom templates, verify registered rosters, and export official audit reports.',
                        icon: Icons.admin_panel_settings_rounded,
                        iconBg: const Color(0xFFF1F5F9),
                        iconColor: const Color(0xFF334155),
                        badgeBg: const Color(0xFFF1F5F9),
                        badgeColor: const Color(0xFF334155),
                        onTap: () => _chooseRole(context, 'controller'),
                      ),

                      const SizedBox(height: 28),

                      // Server Connection Switcher Bar (Clean White Capsule)
                      Center(
                        child: ValueListenableBuilder<String>(
                          valueListenable: AppConfig.activeUrlNotifier,
                          builder: (context, url, _) {
                            final isLan = AppConfig.isUsingLan;
                            return InkWell(
                              onTap: () {
                                AppConfig.toggleServerUrl();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Switched to ${AppConfig.connectionModeLabel} (${AppConfig.apiBaseUrl})'),
                                    duration: const Duration(seconds: 2),
                                    backgroundColor: AppColors.ink,
                                  ),
                                );
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: AppColors.border),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x060F172A),
                                      blurRadius: 10,
                                      offset: Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: AppColors.primary,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Backend: ${isLan ? "Wi-Fi (10.0.4.99:8000)" : "USB (localhost:8000)"}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.ink,
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    const Icon(Icons.swap_horiz_rounded, size: 16, color: AppColors.slate),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          'Tap server chip above to toggle between Mobile Wi-Fi and USB adb host',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.title,
    required this.badge,
    required this.description,
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.badgeBg,
    required this.badgeColor,
    required this.onTap,
  });

  final String title;
  final String badge;
  final String description;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final Color badgeBg;
  final Color badgeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedPressable(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border, width: 1.0),
          boxShadow: const [
            BoxShadow(
              color: Color(0x060F172A),
              blurRadius: 16,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: badgeBg,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          badge,
                          style: TextStyle(
                            fontSize: 9.5,
                            fontWeight: FontWeight.w800,
                            color: badgeColor,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16.5,
                      fontWeight: FontWeight.w800,
                      color: AppColors.ink,
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.slate,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            const Padding(
              padding: EdgeInsets.only(top: 14),
              child: Icon(Icons.chevron_right_rounded, color: AppColors.muted, size: 22),
            ),
          ],
        ),
      ),
    );
  }
}
