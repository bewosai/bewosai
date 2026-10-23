import 'package:bewosai_app/shared/widgets/global_help_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

GoRouter _router(String start) => GoRouter(
      initialLocation: start,
      routes: [
        GoRoute(path: '/login', builder: (_, _) => const Scaffold(body: Text('login'))),
        GoRoute(path: '/dashboard', builder: (_, _) => Scaffold(body: Center(
          child: ElevatedButton(onPressed: () {}, child: const Text('page button')),
        ))),
        GoRoute(path: '/help', builder: (_, _) => const Scaffold(body: Text('help screen'))),
      ],
    );

Widget _app(GoRouter router) => MaterialApp.router(
      routerConfig: router,
      builder: (context, child) => Stack(children: [
        Positioned.fill(child: child!),
        GlobalHelpButton(router: router),
      ]),
    );

void main() {
  testWidgets('shows on app screens, opens help, and leaves the page usable', (tester) async {
    final router = _router('/dashboard');
    await tester.pumpWidget(_app(router));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.support_agent), findsOneWidget);
    await tester.tap(find.text('page button'));   // the screen underneath still takes taps
    await tester.tap(find.byIcon(Icons.support_agent));
    await tester.pumpAndSettle();
    expect(find.text('help screen'), findsOneWidget);
    expect(find.byIcon(Icons.support_agent), findsNothing); // not on the help screen itself
  });

  testWidgets('hidden on the sign-in screen', (tester) async {
    await tester.pumpWidget(_app(_router('/login')));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.support_agent), findsNothing);
  });
}
