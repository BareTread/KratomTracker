import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Add-Dose-first FAB. A tap fires Add Dose directly (the most-used action in
/// the app). A long-press expands two large labelled pills stacked above the
/// button within a thumb arc; tap-anywhere dismisses.
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
          _FabPill(
            key: const Key('home-fab-add-strain'),
            label: 'Add Strain',
            icon: Icons.local_florist_outlined,
            fill: false,
            animation: _controller,
            onPressed: () => _run(widget.onAddStrain),
            reduced: reduced,
          ),
          const SizedBox(height: 10),
          _FabPill(
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
        _FabButton(
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

class _FabButton extends StatelessWidget {
  const _FabButton({
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

  @override
  Widget build(BuildContext context) {
    final accent = context.c.accent;
    final muted = context.c.accentMuted;
    return Container(
      width: 60,
      height: 60,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color.lerp(accent, muted, 0.15)!,
            Color.lerp(accent, muted, 0.55)!,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: accent.withValues(alpha: 0.28),
            blurRadius: 18,
            spreadRadius: 0,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(18),
          splashColor: context.c.textPrimary.withValues(alpha: 0.12),
          highlightColor: context.c.textPrimary.withValues(alpha: 0.06),
          child: Center(
            child: AnimatedRotation(
              turns: open ? 0.125 : 0,
              duration: reduced ? Duration.zero : AppMotion.fast,
              child: Icon(
                open ? Icons.close : Icons.add,
                size: 26,
                color: context.c.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A large labelled pill — label inside the button, not floating beside it.
/// Add Dose is the filled accent pill (dominant); Add Strain is the outlined
/// surface pill (secondary).
class _FabPill extends StatelessWidget {
  const _FabPill({
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
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 20),
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
                size: 22,
                color: fill ? context.c.textPrimary : context.c.textSecondary,
              ),
              const SizedBox(width: 10),
              Text(
                label,
                style: TextStyle(
                  color: context.c.textPrimary,
                  fontSize: 16,
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
        opacity: CurvedAnimation(parent: animation, curve: AppMotion.emphasized),
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(
            CurvedAnimation(
              parent: animation,
              curve: AppMotion.spring,
            ),
          ),
          child: pill,
        ),
      ),
    );
  }
}
