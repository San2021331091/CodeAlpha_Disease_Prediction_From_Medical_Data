import 'package:cellscope/views/splash_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash reveals its existing workspace and does not replay', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SplashView(child: Scaffold(body: Text('Workspace ready'))),
      ),
    );
    expect(find.byKey(const ValueKey('cellscope-splash')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.text('CellScope'), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cellscope-splash')), findsNothing);
    expect(find.text('Workspace ready'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.byKey(const ValueKey('cellscope-splash')), findsNothing);
  });

  testWidgets('reduced motion skips the long animation on small screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            disableAnimations: true,
            textScaler: TextScaler.linear(2),
          ),
          child: SplashView(child: Scaffold(body: Text('Workspace ready'))),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(find.byKey(const ValueKey('cellscope-splash')), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
