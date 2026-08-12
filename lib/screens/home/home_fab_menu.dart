import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Circular cyan FAB for the home screen. A tap fires Add Dose; a long-press
/// expands two labelled actions (Add Dose / Add Strain) above it.
class HomeFabMenu extends StatefulWidget {
  const HomeFabMenu({
    super.key,
    required this.onAddDose,
    required this.onAddStrain,
    required this.onVisibilityChanged,
  });

  final VoidCallback onAddDose;
  final VoidCallback onAddStrain;
  final ValueChanged<bool> onVisibilityChanged;

  @override
  State<HomeFabMenu> createState() => HomeFabMenuState();
}

class HomeFabMenuState extends State<HomeFabMenu>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _open = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.normal,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void close() {
    if (!_open) return;
    setState(() => _open = false);
    widget.onVisibilityChanged(false);
    _controller.reverse();
  }

  void _openMenu() {
    HapticFeedback.mediumImpact();
    setState(() => _open = true);
    widget.onVisibilityChanged(true);
    if (AppMotion.reduced(context)) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  void _tapFab() {
    if (_open) {
      close();
      return;
    }
    widget.onAddDose();
  }

  void _run(VoidCallback action) {
    close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    final reduced = AppMotion.reduced(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _MenuPill(
            key: const Key('home-fab-add-strain'),
            label: 'Add Strain',
            icon: Icons.local_florist_outlined,
            fill: false,
            animation: _controller,
            onPressed: () => _run(widget.onAddStrain),
            reduced: reduced,
          ),
          const SizedBox(height: 10),
          _MenuPill(
            key: const Key('home-fab-add-dose'),
            label: 'Add Dose',
            icon: Icons.add,
            fill: true,
            animation: _controller,
            onPressed: () => _run(widget.onAddDose),
            reduced: reduced,
          ),
          const SizedBox(height: 12),
        ],
        _CircularFab(
          key: const Key('home-fab'),
          open: _open,
          reduced: reduced,
          onTap: _tapFab,
          onLongPress: _open ? null : _openMenu,
        ),
      ],
    );
  }
}

/// Plain circular cyan FAB — roughly 56px with a single `+` glyph.
class _CircularFab extends StatelessWidget {
  const _CircularFab({
    super.key,
    required this.open,
    required this.reduced,
    required this.onTap,
    required this.onLongPress,
  });

  final bool open;
  final bool reduced;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  static const double _size = 56;

  @override
  Widget build(BuildContext context) {
    final accent = context.c.accent;
    final muted = context.c.accentMuted;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        customBorder: const CircleBorder(),
        child: Ink(
          width: _size,
          height: _size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(accent, muted, 0.1)!,
                Color.lerp(accent, muted, 0.45)!,
              ],
            ),
            // Two layers, not one glow: a tight neutral contact shadow does
            // the lifting, and a wider, dimmer cyan bloom sits under it. A
            // lone cyan glow made the disc look like it was emitting light
            // rather than resting above the page.
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
              BoxShadow(
                color: accent.withValues(alpha: 0.2),
                blurRadius: 22,
                spreadRadius: -2,
                offset: const Offset(0, 7),
              ),
            ],
          ),
          child: Center(
            child: AnimatedRotation(
              turns: open ? 0.125 : 0,
              duration: reduced ? Duration.zero : AppMotion.fast,
              child: Icon(
                open ? Icons.close : Icons.add,
                size: 24,
                color: context.c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Expanded menu pill shown above the FAB on long-press.
class _MenuPill extends StatelessWidget {
  const _MenuPill({
    super.key,
    required this.label,
    required this.icon,
    required this.fill,
    required this.animation,
    required this.onPressed,
    required this.reduced,
  });

  final String label;
  final IconData icon;
  final bool fill;
  final Animation<double> animation;
  final VoidCallback onPressed;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final pill = Material(
      color: fill ? context.c.accent : context.c.surfaceRaised,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: fill
              ? null
              : BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: context.c.hairline),
                ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: fill ? context.c.textPrimary : context.c.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: context.c.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reduced) {
      return SizeTransition(
        sizeFactor: AlwaysStoppedAnimation(animation.value),
        child: pill,
      );
    }
    return SizeTransition(
      sizeFactor: CurvedAnimation(parent: animation, curve: AppMotion.spring),
      alignment: Alignment.bottomRight,
      child: FadeTransition(
        opacity:
            CurvedAnimation(parent: animation, curve: AppMotion.emphasized),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(parent: animation, curve: AppMotion.spring),
          ),
          child: pill,
        ),
      ),
    );
  }
}
