import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'config/supabase_config.dart';
import 'config/app_config.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting('id_ID', null);
  await initializeDateFormatting('id', null);
  AppConfig.initialize();
  await SupabaseConfig.initialize();

  runApp(
    const ProviderScope(
      child: FinancierApp(),
    ),
  );
}
