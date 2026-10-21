import 'package:flutter/material.dart';

class AppColors {
  static const ink = Color(0xFF18323C);
  static const teal = Color(0xFF0D7775);
  static const mint = Color(0xFFDDF5EC);
  static const cream = Color(0xFFFFFBF3);
  static const coral = Color(0xFFD7644C);
  static const amber = Color(0xFFF0B657);
  static const slate = Color(0xFF58717A);
  static const line = Color(0xFFD9E5E3);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.cream,
      colorScheme: ColorScheme.fromSeed(
              seedColor: AppColors.teal, brightness: Brightness.light)
          .copyWith(surface: Colors.white),
      fontFamily: 'sans',
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.w800,
            color: AppColors.ink,
            letterSpacing: -0.7),
        headlineMedium: TextStyle(
            fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.ink),
        titleLarge: TextStyle(
            fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.ink),
        titleMedium: TextStyle(
            fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.ink),
        bodyLarge: TextStyle(fontSize: 16, height: 1.45, color: AppColors.ink),
        bodyMedium:
            TextStyle(fontSize: 14, height: 1.4, color: AppColors.slate),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.line)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: const BorderSide(color: AppColors.teal, width: 2)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          margin: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(22),
              side: const BorderSide(color: AppColors.line))),
    );

class AppCard extends StatelessWidget {
  const AppCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(18)});
  final Widget child;
  final EdgeInsets padding;
  @override
  Widget build(BuildContext context) =>
      Card(child: Padding(padding: padding, child: child));
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});
  final String status;
  @override
  Widget build(BuildContext context) {
    final normalized = status.toLowerCase();
    final color = normalized == 'present'
        ? AppColors.teal
        : normalized == 'absent'
            ? AppColors.coral
            : AppColors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .13),
          borderRadius: BorderRadius.circular(99)),
      child: Text(normalized[0].toUpperCase() + normalized.substring(1),
          style: TextStyle(
              color: color, fontWeight: FontWeight.w800, fontSize: 12)),
    );
  }
}

class ErrorPanel extends StatelessWidget {
  const ErrorPanel(
      {super.key,
      required this.message,
      required this.onRetry,
      this.secondaryLabel = 'Use manual roll call'});
  final String message;
  final VoidCallback onRetry;
  final String secondaryLabel;
  @override
  Widget build(BuildContext context) => AppCard(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.cloud_off_rounded, color: AppColors.coral, size: 28),
          const SizedBox(height: 8),
          Text(message, style: Theme.of(context).textTheme.bodyLarge),
          const SizedBox(height: 12),
          Wrap(spacing: 10, runSpacing: 8, children: [
            FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry')),
            OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.fact_check_outlined),
                label: Text(secondaryLabel)),
          ]),
        ]),
      );
}

class EmptyState extends StatelessWidget {
  const EmptyState(
      {super.key,
      required this.icon,
      required this.title,
      required this.message});
  final IconData icon;
  final String title;
  final String message;
  @override
  Widget build(BuildContext context) => AppCard(
          child: Column(children: [
        Icon(icon, size: 42, color: AppColors.teal),
        const SizedBox(height: 12),
        Text(title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 6),
        Text(message, textAlign: TextAlign.center)
      ]));
}
