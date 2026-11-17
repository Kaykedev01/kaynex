import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kaynex/main.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  testWidgets('KAYNEX opens its local workspace', (tester) async {
    final store = await LocalStore.openAt(inMemoryDatabasePath);
    await store.setPreference('homePage', '5');
    await tester.pumpWidget(MaterialApp(
      home: PreferencesPage(
        store: store,
        isLight: false,
        onThemeChanged: (_) {},
        accentHex: '9BCB75',
        onAccentChanged: (_) {},
      ),
    ));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Sobre o KAYNEX'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    await store.close();
  });
}
