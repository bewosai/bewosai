import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/app_colors.dart';

/// The round help button at the bottom right of every signed-in screen: opens
/// Help & Feedback (ask how to use the app / send a message). Sits above the
/// bottom bar and the screens' own + buttons, and hides while typing.
class GlobalHelpButton extends StatelessWidget {
  final GoRouter router;
  const GlobalHelpButton({super.key, required this.router});

  /// Sign-in screens, the help screen itself, and the full-screen till.
  static const _hiddenOn = {'/', '/login', '/select-business', '/help', '/pos'};

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: router.routerDelegate,
      builder: (context, _) {
        // The screen on top: a pushed one (like /help) doesn't change .uri.
        final config = router.routerDelegate.currentConfiguration;
        final path = config.isEmpty ? '/' : config.last.matchedLocation;
        final typing = MediaQuery.of(context).viewInsets.bottom > 0;
        if (_hiddenOn.contains(path) || typing) return const SizedBox.shrink();
        // Align (not Positioned): this sits inside a builder, and only the
        // button itself takes taps — the rest of the screen stays usable.
        return Align(
          alignment: Alignment.bottomRight,
          child: Padding(
            padding: EdgeInsets.only(right: 16, bottom: MediaQuery.of(context).padding.bottom + 150),
            child: Material(
            color: AppColors.orange,
            shape: const CircleBorder(),
            elevation: 6,
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () => router.push('/help'),
              child: const Padding(
                padding: EdgeInsets.all(12),
                child: Icon(Icons.support_agent, color: Colors.white, size: 24, semanticLabel: 'Help'),
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}
