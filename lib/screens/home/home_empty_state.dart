import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

class HomeEmptyState extends StatelessWidget {
  const HomeEmptyState({super.key, required this.onAddDose});

  final VoidCallback onAddDose;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 80),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 168,
                    height: 168,
                    decoration: BoxDecoration(
                      color: context.c.surfaceSunken,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.eco_outlined,
                      size: 72,
                      color: context.c.accentMuted,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'No doses recorded',
                    style: TextStyle(
                      color: context.c.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Semantics(
                    button: true,
                    label: 'Add your first dose',
                    child: InkWell(
                      key: const Key('home-empty-add-dose'),
                      onTap: onAddDose,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 48),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: BoxDecoration(
                          color: context.c.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: context.c.accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              color: context.c.accent,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Add your first dose',
                              style: TextStyle(color: context.c.accent),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
