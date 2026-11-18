import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_theme.dart';

/// Circular cyan FAB for the home screen. A tap fires Add Dose; a long-press
/// expands labelled actions above it: Add Strain, Add Dose, and — when the
/// log has at least one dose — a repeat pill for the most recent dose.
class HomeFabMenu extends StatefulWidget {
  const HomeFabMenu({
    super.key,
    required this.onAddDose,
    required this.onAddStrain,
    required this.onVisibilityChanged,
    this.repeatCode,
    this.repeatAmount,
    this.repeatStrainColor,
    this.onRepeatLast,
  });

  final VoidCallback onAddDose;
  final VoidCallback onAddStrain;
  final ValueChanged<bool> onVisibilityChanged;

  /// Repeat-last-dose pill, shown only when all three are non-null.
  /// [repeatCode] is the strain's short code, [repeatAmount] its formatted
  /// amount (e.g. "16.6g"), [repeatStrainColor] the strain's identity colour.
  final String? repeatCode;
  final String? repeatAmount;
  final Color? repeatStrainColor;
  final VoidCallback? onRepeatLast;

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
            spans: const [TextSpan(text: 'Add Strain')],
            icon: Icons.local_florist_outlined,
            animation: _controller,
            onPressed: () => _run(widget.onAddStrain),
            reduced: reduced,
          ),
          const SizedBox(height: 10),
          _MenuPill(
            key: const Key('home-fab-add-dose'),
            spans: const [TextSpan(text: 'Add Dose')],
            icon: Icons.add,
            animation: _controller,
            onPressed: () => _run(widget.onAddDose),
            reduced: reduced,
          ),
          if (widget.repeatCode != null &&
              widget.repeatAmount != null &&
              widget.onRepeatLast != null) ...[
            const SizedBox(height: 10),
            _MenuPill(
              key: const Key('home-fab-repeat-last'),
              spans: [
                TextSpan(
                  text: widget.repeatCode!,
                  style: TextStyle(
                    color: legibleStrainColor(
                      widget.repeatStrainColor ?? context.c.textPrimary,
                      Theme.of(context).brightness,
                    ),
                  ),
                ),
                TextSpan(text: ' · ${widget.repeatAmount} again'),
              ],
              semanticsLabel:
                  'Log ${widget.repeatCode} ${widget.repeatAmount!.replaceAll(RegExp(r'g$'), ' grams')} again now',
              icon: Icons.replay,
              animation: _controller,
              onPressed: () => _run(widget.onRepeatLast!),
              reduced: reduced,
            ),
          ],
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
class _CircularFab extends StatefulWidget {
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

  @override
  State<_CircularFab> createState() => _CircularFabState();
}

class _CircularFabState extends State<_CircularFab> {
  static const double _size = 56;
  bool _pressed = false;

  bool get open => widget.open;
  bool get reduced => widget.reduced;
  VoidCallback get onTap => widget.onTap;
  VoidCallback? get onLongPress => widget.onLongPress;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: open ? 'Close menu' : 'Log a dose',
      hint: open ? null : 'Long press for more actions',
      excludeSemantics: true,
      onTap: onTap,
      onLongPress: onLongPress,
      // Flat disc, no shadow stack or gradient: the earlier neutral shadow +
      // cyan bloom left a dark crescent under the circle in dark theme, and
      // elevation isn't needed — the accent fill already reads as the one
      // action on the page. Presses still sink the disc a few percent.
      child: AnimatedScale(
        scale: _pressed ? 0.92 : 1,
        duration: reduced ? Duration.zero : AppMotion.fast,
        curve: AppMotion.emphasized,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              onTap();
            },
            onLongPress: onLongPress,
            onHighlightChanged: (down) => setState(() => _pressed = down),
            customBorder: const CircleBorder(),
            child: Ink(
              width: _size,
              height: _size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.c.accent,
              ),
              child: Center(
                child: AnimatedRotation(
                  turns: open ? 0.125 : 0,
                  duration: reduced ? Duration.zero : AppMotion.fast,
                  child: Icon(
                    open ? Icons.close : Icons.add,
                    size: 24,
                    color: Colors.white,
                  ),
                ),
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
    required this.spans,
    required this.icon,
    required this.animation,
    required this.onPressed,
    required this.reduced,
    this.semanticsLabel,
  });

  /// Rich label: single span for plain pills; the repeat pill adds a second
  /// span so the strain code can carry its identity colour while the rest of
  /// the label stays neutral.
  final List<TextSpan> spans;
  final IconData icon;
  final Animation<double> animation;
  final VoidCallback onPressed;
  final bool reduced;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final pill = Material(
      color: context.c.surfaceRaised,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(horizontal: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.c.hairline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 20,
                color: context.c.textSecondary,
              ),
              const SizedBox(width: 10),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    color: context.c.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                  children: spans,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Custom announcement (the repeat pill's "Log … grams again now")
    // replaces the inner text/icon semantics; the wrapper carries the button
    // role and the action so activation still works.
    final child = semanticsLabel == null
        ? pill
        : Semantics(
            label: semanticsLabel,
            button: true,
            excludeSemantics: true,
            onTap: onPressed,
            child: pill,
          );

    if (reduced) {
      return SizeTransition(
        sizeFactor: AlwaysStoppedAnimation(animation.value),
        child: child,
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
          child: child,
        ),
      ),
    );
  }
}
