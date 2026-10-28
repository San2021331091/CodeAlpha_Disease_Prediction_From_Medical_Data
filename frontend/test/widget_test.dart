import 'package:cellscope/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'support/fake_api.dart';

void main() {
  testWidgets('sample results fit narrow enlarged-text screens', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.6;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.view.resetViewInsets();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });
    await tester.pumpWidget(CellScopeApp(api: FakeApi()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.widgetWithText(ActionChip, 'Benign example 1'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.widgetWithText(ActionChip, 'Benign example 1')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Benign example 1'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Analyze measurements'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await Scrollable.ensureVisible(
      tester.element(find.text('Analyze measurements')),
      alignment: .5,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze measurements'));
    await tester.pumpAndSettle();
    expect(find.text('Benign classification'), findsOneWidget);
    expect(tester.takeException(), isNull);
    tester.state<NavigatorState>(find.byType(Navigator).first).pop();
    await tester.pumpAndSettle();
    expect(find.byTooltip('Server settings'), findsNothing);
    expect(find.text('Server connection'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final spec in [
    (const Size(320, 568), 1.0),
    (const Size(360, 640), 1.6),
    (const Size(800, 360), 1.2),
    (const Size(768, 1024), 1.0),
  ]) {
    testWidgets('all page content fits ${spec.$1} at text scale ${spec.$2}', (
      tester,
    ) async {
      tester.view.physicalSize = spec.$1;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = spec.$2;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
      });
      await tester.pumpWidget(CellScopeApp(api: FakeApi()));
      await tester.pumpAndSettle();
      for (final tab in ['Overview', 'Analyze', 'Model lab', 'History']) {
        await tester.tap(find.text(tab));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$tab initial layout');
        for (var i = 0; i < 9; i++) {
          await tester.drag(
            find.byType(Scrollable).first,
            const Offset(0, -350),
          );
          await tester.pumpAndSettle();
          expect(
            tester.takeException(),
            isNull,
            reason: '$tab scrolling, step $i',
          );
        }
      }
    });
  }

  testWidgets('connection error scrolls on a short landscape screen', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(640, 300);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    await tester.pumpWidget(CellScopeApp(api: FakeApi()..unavailable = true));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('Retry connection'), 150);
    expect(find.text('Retry connection').hitTestable(), findsOneWidget);
  });

  testWidgets('connection failure can be retried', (tester) async {
    final api = FakeApi()..unavailable = true;
    await tester.pumpWidget(CellScopeApp(api: api));
    await tester.pumpAndSettle();
    expect(find.text('Test server unavailable'), findsOneWidget);
    api.unavailable = false;
    await tester.tap(find.text('Retry connection'));
    await tester.pumpAndSettle();
    expect(find.text('Small details.\nDeeper understanding.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sample populates all groups and submits exact measurements', (
    tester,
  ) async {
    final api = FakeApi();
    await tester.pumpWidget(CellScopeApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Analyze'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ActionChip, 'Benign example 1'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Analyze measurements'),
      600,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Analyze measurements'));
    await tester.pumpAndSettle();
    expect(api.predictions, 1);
    expect(find.text('Benign classification'), findsOneWidget);
    expect(find.text('Public record label: Benign'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('history result opens and clear requires confirmation', (
    tester,
  ) async {
    final api = FakeApi();
    await tester.pumpWidget(CellScopeApp(api: api));
    await tester.pumpAndSettle();
    await tester.tap(find.text('History'));
    await tester.pumpAndSettle();
    expect(find.text('Benign classification'), findsOneWidget);
    await tester.tap(find.text('Clear server history'));
    await tester.pumpAndSettle();
    expect(api.deleted, false);
    await tester.tap(find.text('Clear history'));
    await tester.pumpAndSettle();
    expect(api.deleted, true);
    expect(find.text('A fresh start'), findsOneWidget);
  });

  testWidgets(
    'responsive layout on narrow 320px mobile screen has no overflows',
    (tester) async {
      tester.view.physicalSize = const Size(320, 568);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final api = FakeApi();
      await tester.pumpWidget(CellScopeApp(api: api));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      for (final tabName in ['Analyze', 'Model lab', 'History', 'Overview']) {
        await tester.tap(find.text(tabName));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
