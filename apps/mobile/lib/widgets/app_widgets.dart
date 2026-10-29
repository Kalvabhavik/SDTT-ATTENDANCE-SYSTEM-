import 'dart:async' as async;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';

/// Attendrix Design System Palette
/// Consistent with the Web Dashboard (Deep Blue actions, Light Blue background, White cards)
/// Tagline: "Smart Attendance. Verified Presence."
class AppColors {
  AppColors._();

  // Primary & Accents (Deep Blue & Navy matching Attendrix Design System)
  static const primary = Color(0xFF1D61F2); // Deep Royal Blue
  static const primaryDark = Color(0xFF154ECE); // Blue 800
  static const primaryLight = Color(0xFF3B82F6); // Blue 500
  static const secondary = Color(0xFF1E293B); // Navy Slate 800
  static const secondaryDark = Color(0xFF0F172A); // Navy Slate 900
  static const accentBlue = Color(0xFF1D61F2);
  static const accentBlueBg = Color(0xFFEFF5FF);
  static const accentBlueBorder = Color(0xFFBFDBFE);
  // Aliases for component compatibility
  static const accentIndigo = primary;
  static const accentIndigoBg = accentBlueBg;
  static const accentIndigoBorder = accentBlueBorder;

  // Status Colors (Clear present, absent, pending, rejected, and verified status indicators)
  static const emerald = Color(0xFF10B981); // Present / Verified (Emerald 500)
  static const emeraldBg = Color(0xFFECFDF5);
  static const emeraldBorder = Color(0xFFA7F3D0);

  static const rose = Color(0xFFEF4444); // Absent / Rejected / Error (Rose 500)
  static const roseBg = Color(0xFFFFF1F2);
  static const roseBorder = Color(0xFFFECDD3);

  static const amber = Color(0xFFF59E0B); // Pending / Flagged / Warning (Amber 500)
  static const amberBg = Color(0xFFFFFBEB);
  static const amberBorder = Color(0xFFFDE68A);

  static const sky = Color(0xFF0284C7); // Sky 600 info / network
  static const skyBg = Color(0xFFF0F9FF);
  static const skyBorder = Color(0xFFBAE6FD);

  // Surfaces & Backgrounds (Light Powder Blue Canvas matching screenshot)
  static const background = Color(0xFFEBF3FA); // Light Blue Page Background
  static const card = Color(0xFFFFFFFF); // Pure white card
  static const cardSubtle = Color(0xFFF8FAFC); // Slate 50


  // Typography (Deep Navy Ink with accessible contrast)
  static const ink = Color(0xFF0F172A); // Charcoal Navy Slate 900
  static const slate = Color(0xFF334155); // High-contrast Slate 700
  static const muted = Color(0xFF64748B); // Slate 500
  static const border = Color(0xFFE2E8F0); // Thin clean divider
  static const line = border;
  static const borderHighlight = Color(0xFFCBD5E1);

  // Pastel Chips
  static const tagBacklogBg = Color(0xFFF1F5F9);
  static const tagBacklogText = Color(0xFF475569);
  static const tagProgressBg = Color(0xFFFFFBEB);
  static const tagProgressText = Color(0xFFD97706);
  static const tagHoldBg = Color(0xFFFFF1F2);
  static const tagHoldText = Color(0xFFE11D48);
  static const tagApprovedBg = Color(0xFFECFDF5);
  static const tagApprovedText = Color(0xFF059669);

  // Gradients (Clean academic navy & indigo)
  static const primaryGradient = LinearGradient(
    colors: [Color(0xFF4F46E5), Color(0xFF3730A3)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const studentHeroGradient = LinearGradient(
    colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const teacherHeroGradient = LinearGradient(
    colors: [Color(0xFF312E81), Color(0xFF1E1B4B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const accentGradient = LinearGradient(
    colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// App theme with Inter typography, smooth shapes, and crisp academic contrast
ThemeData buildTheme({bool isTest = false}) {
  const baseTextTheme = TextTheme(
    headlineLarge: TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w900,
      color: AppColors.ink,
      letterSpacing: -0.8,
      height: 1.15,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
      letterSpacing: -0.5,
    ),
    titleLarge: TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w800,
      color: AppColors.ink,
      letterSpacing: -0.3,
    ),
    titleMedium: TextStyle(
      fontSize: 15.5,
      fontWeight: FontWeight.w700,
      color: AppColors.ink,
    ),
    bodyLarge: TextStyle(
      fontSize: 15,
      height: 1.5,
      color: AppColors.slate,
    ),
    bodyMedium: TextStyle(
      fontSize: 13.5,
      height: 1.45,
      color: AppColors.slate,
    ),
    labelSmall: TextStyle(
      fontSize: 11.5,
      fontWeight: FontWeight.w600,
      color: AppColors.muted,
      letterSpacing: 0.3,
    ),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.card,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.background,
      elevation: 0,
      scrolledUnderElevation: 1,
      centerTitle: false,
      iconTheme: IconThemeData(color: AppColors.ink),
      titleTextStyle: TextStyle(
        color: AppColors.ink,
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
    ),
    textTheme: isTest ? baseTextTheme : GoogleFonts.interTextTheme(baseTextTheme),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      labelStyle: const TextStyle(color: AppColors.slate, fontSize: 14),
      hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
      prefixIconColor: AppColors.slate,
      suffixIconColor: AppColors.slate,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.rose, width: 1.5),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.rose, width: 2),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        side: const BorderSide(color: AppColors.border, width: 1.2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: Colors.white,
      elevation: 2,
      shadowColor: Colors.black12,
      height: 68,
      indicatorColor: AppColors.primary.withValues(alpha: 0.12),
      labelTextStyle: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            color: AppColors.primary,
          );
        }
        return const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.slate,
        );
      }),
      iconTheme: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return const IconThemeData(color: AppColors.primary, size: 24);
        }
        return const IconThemeData(color: AppColors.slate, size: 24);
      }),
    ),
  );
}

/// Optional consistent dark theme for Attendrix
ThemeData buildDarkTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: const Color(0xFF090D16),
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
      primary: AppColors.primaryLight,
      secondary: const Color(0xFF334155),
      surface: const Color(0xFF0F172A),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF090D16),
      elevation: 0,
      centerTitle: false,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
  );
}

/// Tactile bounce effect for pressable elements
class AnimatedPressable extends StatefulWidget {
  const AnimatedPressable({
    super.key,
    required this.child,
    this.onTap,
    this.scaleDown = 0.96,
  });

  final Widget child;
  final VoidCallback? onTap;
  final double scaleDown;

  @override
  State<AnimatedPressable> createState() => _AnimatedPressableState();
}

class _AnimatedPressableState extends State<AnimatedPressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap != null ? (_) => setState(() => _pressed = true) : null,
      onTapUp: widget.onTap != null ? (_) => setState(() => _pressed = false) : null,
      onTapCancel: widget.onTap != null ? () => setState(() => _pressed = false) : null,
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: _pressed ? widget.scaleDown : 1.0,
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

/// Staggered Fade & Slide In Entrance
class FadeSlideIn extends StatefulWidget {
  const FadeSlideIn({
    super.key,
    required this.child,
    this.delay = Duration.zero,
    this.duration = const Duration(milliseconds: 450),
    this.offsetY = 24.0,
  });

  final Widget child;
  final Duration delay;
  final Duration duration;
  final double offsetY;

  @override
  State<FadeSlideIn> createState() => _FadeSlideInState();
}

class _FadeSlideInState extends State<FadeSlideIn> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fade;
  late final Animation<double> _slide;
  async.Timer? _timer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _fade = CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);
    _slide = Tween<double>(begin: widget.offsetY, end: 0.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      _timer = async.Timer(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Opacity(
        opacity: _fade.value,
        child: Transform.translate(
          offset: Offset(0, _slide.value),
          child: child,
        ),
      ),
      child: widget.child,
    );
  }
}

/// Modern AppCard with delicate borders, subtle elevation, and rounded geometry
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.backgroundColor,
    this.borderColor,
    this.borderRadius = 22.0,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final EdgeInsets? margin;
  final Color? backgroundColor;
  final Color? borderColor;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cardContent = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.card,
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: borderColor ?? AppColors.border,
          width: 1.0,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x060F172A),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
          BoxShadow(
            color: Color(0x040F172A),
            blurRadius: 4,
            offset: Offset(0, 1),
          ),
        ],
      ),
      child: child,
    );

    if (onTap != null) {
      return AnimatedPressable(
        onTap: onTap,
        child: cardContent,
      );
    }
    return cardContent;
  }
}

/// Modern Status Pill with icon and animated glowing styling
class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status, this.compact = false});

  final String status;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();

    Color bg;
    Color border;
    Color text;
    IconData icon;

    switch (normalized) {
      case 'present':
        bg = AppColors.emeraldBg;
        border = AppColors.emeraldBorder;
        text = AppColors.emerald;
        icon = Icons.check_circle_rounded;
        break;
      case 'verified':
        bg = AppColors.emeraldBg;
        border = AppColors.emeraldBorder;
        text = AppColors.emerald;
        icon = Icons.verified_user_rounded;
        break;
      case 'absent':
        bg = AppColors.roseBg;
        border = AppColors.roseBorder;
        text = AppColors.rose;
        icon = Icons.cancel_rounded;
        break;
      case 'rejected':
        bg = AppColors.roseBg;
        border = AppColors.roseBorder;
        text = AppColors.rose;
        icon = Icons.gpp_bad_rounded;
        break;
      case 'flagged':
        bg = AppColors.amberBg;
        border = AppColors.amberBorder;
        text = AppColors.amber;
        icon = Icons.warning_amber_rounded;
        break;
      case 'finalized':
        bg = const Color(0xFFF1F5F9);
        border = const Color(0xFFCBD5E1);
        text = AppColors.slate;
        icon = Icons.lock_clock_rounded;
        break;
      case 'open':
        bg = AppColors.accentIndigoBg;
        border = AppColors.accentIndigoBorder;
        text = AppColors.primary;
        icon = Icons.radio_button_checked_rounded;
        break;
      default: // pending
        bg = AppColors.amberBg;
        border = AppColors.amberBorder;
        text = AppColors.amber;
        icon = Icons.schedule_rounded;
    }

    final label = normalized.isEmpty
        ? 'Pending'
        : normalized[0].toUpperCase() + normalized.substring(1);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 11,
        vertical: compact ? 4 : 5.5,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: border, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: compact ? 12 : 14, color: text),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: text,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 11 : 12,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }
}

/// Circular Animated Gauge for Student Attendance Card
class CircularAttendanceGauge extends StatelessWidget {
  const CircularAttendanceGauge({
    super.key,
    required this.percentage,
    this.size = 110.0,
    this.strokeWidth = 10.0,
  });

  final double percentage; // 0 - 100
  final double size;
  final double strokeWidth;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: percentage.clamp(0.0, 100.0)),
      duration: const Duration(milliseconds: 1200),
      curve: Curves.easeOutCubic,
      builder: (context, value, _) {
        final ratio = value / 100.0;
        final color = ratio >= 0.75
            ? AppColors.emerald
            : ratio >= 0.60
                ? AppColors.amber
                : AppColors.rose;

        return SizedBox(
          width: size,
          height: size,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size(size, size),
                painter: _GaugePainter(
                  ratio: ratio,
                  strokeWidth: strokeWidth,
                  color: color,
                ),
              ),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${value.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: size * 0.24,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: -1,
                    ),
                  ),
                  Text(
                    'Attendance',
                    style: TextStyle(
                      fontSize: size * 0.10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({
    required this.ratio,
    required this.strokeWidth,
    required this.color,
  });

  final double ratio;
  final double strokeWidth;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track paint
    final trackPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    // Progress paint with gradient-like glow
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = -math.pi / 2;
    final sweepAngle = 2 * math.pi * ratio;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_GaugePainter old) =>
      old.ratio != ratio || old.color != color;
}

/// Multi-color Animated Attendance Bar
class AttendanceBreakdownBar extends StatelessWidget {
  const AttendanceBreakdownBar({
    super.key,
    required this.present,
    required this.absent,
    required this.pending,
    this.height = 8.0,
  });

  final int present;
  final int absent;
  final int pending;
  final double height;

  @override
  Widget build(BuildContext context) {
    final total = present + absent + pending;
    if (total == 0) {
      return Container(
        height: height,
        decoration: BoxDecoration(
          color: AppColors.cardSubtle,
          borderRadius: BorderRadius.circular(height / 2),
        ),
      );
    }

    final pRatio = present / total;
    final aRatio = absent / total;
    final pendRatio = pending / total;

    return ClipRRect(
      borderRadius: BorderRadius.circular(height / 2),
      child: Container(
        height: height,
        color: AppColors.cardSubtle,
        child: Row(
          children: [
            if (present > 0)
              Expanded(
                flex: (pRatio * 1000).toInt(),
                child: Container(color: AppColors.emerald),
              ),
            if (absent > 0)
              Expanded(
                flex: (aRatio * 1000).toInt(),
                child: Container(color: AppColors.rose),
              ),
            if (pending > 0)
              Expanded(
                flex: (pendRatio * 1000).toInt(),
                child: Container(color: AppColors.amber),
              ),
          ],
        ),
      ),
    );
  }
}

/// Error / Offline State Panel
class ErrorPanel extends StatelessWidget {
  const ErrorPanel({
    super.key,
    required this.message,
    required this.onRetry,
    this.secondaryLabel = 'Use manual roll call',
  });

  final String message;
  final VoidCallback onRetry;
  final String secondaryLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      backgroundColor: AppColors.roseBg,
      borderColor: AppColors.roseBorder,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.rose.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.wifi_off_rounded,
                  color: AppColors.rose,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Connection error',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.rose,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.ink,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              FilledButton.icon(
                onPressed: onRetry,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.rose,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Try again'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Premium Empty State with ambient glow circle and crisp typography
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.12),
                    AppColors.secondary.withValues(alpha: 0.08),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 34, color: AppColors.primary),
            ),
            const SizedBox(height: 18),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    height: 1.45,
                    color: AppColors.slate,
                  ),
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 18),
              FilledButton(
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.prefixIcon,
    this.obscureText = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData? prefixIcon;
  final bool obscureText;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
            color: AppColors.slate,
          ),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.ink),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(fontSize: 13, color: AppColors.muted),
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 20, color: AppColors.slate) : null,
            filled: true,
            fillColor: AppColors.cardSubtle,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}

/// Explicit Loading State View with academic styling and step indicators
class AppLottieLoader extends StatelessWidget {
  const AppLottieLoader({
    super.key,
    this.size = 72,
    this.color,
  });

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Lottie.asset(
        'assets/animations/loading.json',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Center(
            child: SizedBox(
              width: size > 30 ? 28 : size * 0.8,
              height: size > 30 ? 28 : size * 0.8,
              child: CircularProgressIndicator(
                strokeWidth: size > 30 ? 3 : 2,
                valueColor: AlwaysStoppedAnimation(color ?? AppColors.primary),
              ),
            ),
          );
        },
      ),
    );
  }
}

class LoadingStateView extends StatelessWidget {
  const LoadingStateView({
    super.key,
    this.title = 'Processing Verification',
    this.message = 'Cross-referencing biometric features with the academic server...',
    this.steps,
  });

  final String title;
  final String message;
  final List<String>? steps;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.accentIndigoBg,
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.accentIndigoBorder),
              ),
              child: const Center(
                child: SizedBox(
                  width: 36,
                  height: 36,
                  child: CircularProgressIndicator(
                    strokeWidth: 3,
                    valueColor: AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.ink,
                letterSpacing: -0.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                fontSize: 13.5,
                color: AppColors.slate,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            if (steps != null && steps!.isNotEmpty) ...[
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardSubtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: steps!.map((step) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.check_circle_rounded, size: 16, color: AppColors.primary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              step,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.slate,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Explicit Verified Success State View
class SuccessStateView extends StatelessWidget {
  const SuccessStateView({
    super.key,
    this.title = 'Attendance Verified Present',
    this.message = 'Your presence and active liveness have been verified by the institutional engine.',
    this.metrics,
    this.actionLabel = 'Return to Dashboard',
    this.onAction,
  });

  final String title;
  final String message;
  final Map<String, String>? metrics;
  final String actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      backgroundColor: Colors.white,
      borderColor: AppColors.emeraldBorder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.emeraldBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.verified_user_rounded,
                color: AppColors.emerald,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: AppColors.ink,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.slate,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (metrics != null && metrics!.isNotEmpty) ...[
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.cardSubtle,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: metrics!.entries.map((entry) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: const TextStyle(
                            fontSize: 12.5,
                            color: AppColors.muted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.value,
                            textAlign: TextAlign.end,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.ink,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
          if (onAction != null) ...[
            const SizedBox(height: 22),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.emerald,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onAction,
              child: Text(
                actionLabel,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Explicit Verification Rejection / Failure State View
class RejectionStateView extends StatelessWidget {
  const RejectionStateView({
    super.key,
    this.title = 'Verification Rejected',
    this.message = 'The submission could not be verified against the classroom attendance criteria.',
    this.reason,
    this.retryLabel = 'Try Verification Again',
    required this.onRetry,
    this.onManualOption,
    this.manualLabel = 'Use Manual Roll Call',
  });

  final String title;
  final String message;
  final String? reason;
  final String retryLabel;
  final VoidCallback onRetry;
  final VoidCallback? onManualOption;
  final String manualLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
      backgroundColor: Colors.white,
      borderColor: AppColors.roseBorder,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 68,
              height: 68,
              decoration: const BoxDecoration(
                color: AppColors.roseBg,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.gpp_bad_rounded,
                color: AppColors.rose,
                size: 38,
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18.5,
              fontWeight: FontWeight.w900,
              color: AppColors.rose,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13.5,
              color: AppColors.slate,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          if (reason != null && reason!.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.roseBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.roseBorder),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, color: AppColors.rose, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      reason!,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: AppColors.rose,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.rose,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: Text(
              retryLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 14.5,
              ),
            ),
          ),
          if (onManualOption != null) ...[
            const SizedBox(height: 8),
            TextButton(
              onPressed: onManualOption,
              child: Text(
                manualLabel,
                style: const TextStyle(
                  color: AppColors.slate,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Explicit Retry State Card for network errors, permission blocks, or timeouts
class RetryStateCard extends StatelessWidget {
  const RetryStateCard({
    super.key,
    required this.title,
    required this.message,
    required this.onRetry,
    this.icon = Icons.refresh_rounded,
    this.buttonLabel = 'Try Again',
  });

  final String title;
  final String message;
  final VoidCallback onRetry;
  final IconData icon;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(20),
      backgroundColor: Colors.white,
      borderColor: AppColors.borderHighlight,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.accentIndigoBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            message,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.slate,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 11),
              backgroundColor: AppColors.primary,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

/// Debounced Button to prevent duplicate taps and duplicate capture submissions
class AppDebouncedButton extends StatefulWidget {
  const AppDebouncedButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.style,
    this.debounceDuration = const Duration(milliseconds: 1000),
    this.isBusy = false,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final ButtonStyle? style;
  final Duration debounceDuration;
  final bool isBusy;

  @override
  State<AppDebouncedButton> createState() => _AppDebouncedButtonState();
}

class _AppDebouncedButtonState extends State<AppDebouncedButton> {
  bool _locked = false;
  async.Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }

  void _handleTap() {
    if (_locked || widget.isBusy || widget.onPressed == null) return;
    setState(() => _locked = true);
    widget.onPressed!();
    _debounceTimer?.cancel();
    _debounceTimer = async.Timer(widget.debounceDuration, () {
      if (mounted) setState(() => _locked = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = !_locked && !widget.isBusy && widget.onPressed != null;
    return FilledButton(
      style: widget.style,
      onPressed: enabled ? _handleTap : null,
      child: widget.isBusy
          ? const AppLottieLoader(
              size: 26,
              color: Colors.white,
            )
          : widget.child,
    );
  }
}

