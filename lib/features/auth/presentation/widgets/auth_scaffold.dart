import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/providers.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/responsive.dart';

/// Shared layout for login/register: soft background orbs, theme toggle
/// and a centered card with the brand gradient bar on top.
class AuthScaffold extends ConsumerWidget {
  const AuthScaffold({super.key, required this.child, this.maxWidth = Breakpoints.formMaxWidth});

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return Scaffold(
      body: Stack(
        children: [
          const Positioned.fill(child: _BackgroundOrbs()),
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: maxWidth),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: c.bgCard,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: context.isDark ? c.accentBorder : c.border),
                      boxShadow: [
                        BoxShadow(
                          color: context.isDark ? const Color(0x8C000000) : const Color(0x1F0F172A),
                          blurRadius: 64,
                          offset: const Offset(0, 24),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Container(
                            height: 4,
                            decoration: const BoxDecoration(gradient: AppColors.accentBarGradient),
                          ),
                          Padding(
                            padding: EdgeInsets.all(context.isPhone ? 24 : 32),
                            child: child,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: _ThemeToggleButton(onTap: ref.read(themeModeProvider.notifier).toggle),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThemeToggleButton extends StatelessWidget {
  const _ThemeToggleButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Material(
      color: c.bgCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: c.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            context.isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
            size: 20,
            color: c.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _BackgroundOrbs extends StatelessWidget {
  const _BackgroundOrbs();

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    Widget orb(Color color, double size) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color, color.withAlpha(0)]),
          ),
        );

    return ColoredBox(
      color: context.colors.bgBase,
      child: Stack(
        children: [
          Positioned(
            top: -120,
            left: -100,
            child: orb(dark ? const Color(0x406366F1) : const Color(0x266366F1), 360),
          ),
          Positioned(
            bottom: -140,
            right: -120,
            child: orb(dark ? const Color(0x338B5CF6) : const Color(0x1F8B5CF6), 400),
          ),
        ],
      ),
    );
  }
}

/// Logo + title + subtitle block at the top of auth cards.
class AuthHeader extends StatelessWidget {
  const AuthHeader({super.key, required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Column(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0x406366F1), Color(0x268B5CF6)],
            ),
            border: Border.all(color: const Color(0x596366F1), width: 1.5),
          ),
          child: const Icon(Icons.menu_book_rounded, color: AppColors.brand, size: 28),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: c.textPrimary),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: c.textMuted),
        ),
      ],
    );
  }
}
