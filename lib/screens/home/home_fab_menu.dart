import 'dart:ui';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

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
    _controller = AnimationController(vsync: this, duration: AppMotion.fast);
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

  void _toggle() {
    setState(() => _open = !_open);
    widget.onVisibilityChanged(_open);
    if (AppMotion.reduced(context)) {
      _controller.value = _open ? 1 : 0;
    } else if (_open) {
      _controller.forward();
    } else {
      _controller.reverse();
    }
  }

  void _run(VoidCallback action) {
    close();
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (_open) ...[
          _FabOption(
            label: 'Add Strain',
            heroTag: 'addStrain',
            icon: Icons.local_florist,
            color: context.c.positive,
            animation: _controller,
            onPressed: () => _run(widget.onAddStrain),
          ),
          const SizedBox(height: 8),
          _FabOption(
            label: 'Add Dose',
            heroTag: 'addDose',
            icon: Icons.add,
            color: context.c.accentMuted,
            animation: _controller,
            onPressed: () => _run(widget.onAddDose),
          ),
          const SizedBox(height: 8),
        ],
        Stack(
          alignment: Alignment.center,
          children: [
            ClipOval(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: const SizedBox(width: 56, height: 56),
              ),
            ),
            FloatingActionButton(
              onPressed: _toggle,
              backgroundColor: context.c.accent,
              child: AnimatedRotation(
                duration:
                    AppMotion.reduced(context) ? Duration.zero : AppMotion.fast,
                turns: _open ? 0.125 : 0,
                child: const Icon(Icons.add),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _FabOption extends StatelessWidget {
  const _FabOption({
    required this.label,
    required this.heroTag,
    required this.icon,
    required this.color,
    required this.animation,
    required this.onPressed,
  });

  final String label;
  final String heroTag;
  final IconData icon;
  final Color color;
  final Animation<double> animation;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(parent: animation, curve: AppMotion.spring),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: context.c.surfaceRaised,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: context.c.hairline),
            ),
            child: Text(label, style: TextStyle(color: context.c.textPrimary)),
          ),
          const SizedBox(width: 8),
          FloatingActionButton(
            heroTag: heroTag,
            onPressed: onPressed,
            backgroundColor: color,
            mini: true,
            child: Icon(icon),
          ),
        ],
      ),
    );
  }
}
