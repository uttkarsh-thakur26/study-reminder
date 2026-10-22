import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Gap.xl,
        vertical: Gap.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: scheme.primaryContainer.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(Radii.l),
            ),
            child: Icon(icon, size: 34, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: Gap.l),
          Text(
            title,
            style: theme.textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Gap.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: Gap.l), action!],
        ],
      ),
    );
  }
}

/// Centres page content and caps its width so lines stay readable on big
/// laptop screens.
class PageBody extends StatelessWidget {
  const PageBody({super.key, required this.child, this.maxWidth = 760});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader(this.title, {super.key, this.trailing, this.color});

  final String title;
  final Widget? trailing;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Gap.s, Gap.xl, Gap.s, Gap.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: theme.textTheme.labelLarge?.copyWith(
                color: color ?? theme.colorScheme.onSurfaceVariant,
                letterSpacing: 0.3,
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
