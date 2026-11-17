import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:crypto/crypto.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

part 'core/database/local_store.dart';
part 'core/services/windows_service.dart';
part 'core/services/storage_scanner.dart';
part 'core/services/file_operations.dart';
part 'core/services/maintenance_service.dart';
part 'app/app_shell.dart';
part 'shared/widgets.dart';
part 'features/overview/overview_page.dart';
part 'features/system/system_page.dart';
part 'features/files/files_page.dart';
part 'features/network/network_page.dart';
part 'features/activities/activities_page.dart';
part 'features/preferences/preferences_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;
  final store = await LocalStore.open();
  final homePage = int.tryParse(await store.preference('homePage', '0')) ?? 0;
  runApp(KaynexApp(store: store, initialPage: homePage));
}

const _green = Color(0xFF9BCB75);
const _bg = Color(0xFF101310);
const _panel = Color(0xFF171B17);
const _line = Color(0xFF293029);
const _muted = Color(0xFF8E988D);
