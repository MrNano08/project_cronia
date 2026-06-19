import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../theme/cronia_theme.dart';

class CroniaBackground extends StatelessWidget {
  final Widget child;

  const CroniaBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(gradient: CroniaColors.appGradient),
      child: child,
    );
  }
}

class CroniaCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final BorderRadiusGeometry borderRadius;
  final Color? borderColor;
  final Gradient? gradient;
  final VoidCallback? onTap;

  const CroniaCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(18),
    this.margin,
    this.borderRadius = const BorderRadius.all(Radius.circular(22)),
    this.borderColor,
    this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius;
    final content = Container(
      margin: margin,
      padding: padding,
      decoration: BoxDecoration(
        color: gradient == null ? CroniaColors.surface : null,
        gradient: gradient,
        borderRadius: radius,
        border: Border.all(color: borderColor ?? CroniaColors.line),
        boxShadow: [
          BoxShadow(
            color: CroniaColors.ink.withValues(alpha: 0.055),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: content,
      ),
    );
  }
}

class CroniaAnimatedItem extends StatelessWidget {
  final Widget child;
  final int index;
  final Duration duration;

  const CroniaAnimatedItem({
    super.key,
    required this.child,
    this.index = 0,
    this.duration = const Duration(milliseconds: 360),
  });

  @override
  Widget build(BuildContext context) {
    final safeIndex = index.clamp(0, 8).toInt();
    final delay = Duration(milliseconds: safeIndex * 35);

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: duration + delay,
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 10 * (1 - value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class CroniaEmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? action;

  const CroniaEmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: CroniaCard(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 30),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: CroniaColors.surfaceSoft,
                  border: Border.all(color: CroniaColors.line),
                ),
                child: Icon(icon, color: CroniaColors.primaryDark, size: 32),
              ),
              const SizedBox(height: 18),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (action != null) ...[
                const SizedBox(height: 18),
                action!,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class CroniaHeroHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget? trailing;

  const CroniaHeroHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return CroniaCard(
      padding: const EdgeInsets.all(20),
      gradient: CroniaColors.heroGradient,
      borderColor: Colors.transparent,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
            ),
            child: Icon(icon, color: Colors.white, size: 26),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 21,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 12),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class CroniaSectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final IconData? icon;
  final Widget child;

  const CroniaSectionCard({
    super.key,
    required this.title,
    this.subtitle,
    this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return CroniaCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: CroniaColors.surfaceSoft,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CroniaColors.line),
                  ),
                  child: Icon(icon, color: CroniaColors.primaryDark, size: 20),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class CroniaNavigationBar extends StatelessWidget {
  final int selectedIndex;

  const CroniaNavigationBar({super.key, required this.selectedIndex});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      decoration: BoxDecoration(
        color: CroniaColors.surface,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: CroniaColors.line),
        boxShadow: [
          BoxShadow(
            color: CroniaColors.ink.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: NavigationBar(
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          if (index == 0) context.go('/home');
          if (index == 1) context.go('/calendar');
          if (index == 2) context.go('/planner');
          if (index == 3) context.go('/settings');
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_rounded), label: 'Inicio'),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_rounded),
            label: 'Calendario',
          ),
          NavigationDestination(icon: Icon(Icons.auto_awesome_rounded), label: 'IA'),
          NavigationDestination(icon: Icon(Icons.settings_rounded), label: 'Ajustes'),
        ],
      ),
    );
  }
}
