import 'package:logger/logger.dart';
import '../../../config/env.dart';

final log = Logger(
  printer: PrettyPrinter(
    methodCount: 0,
    errorMethodCount: 5,
    lineLength: 80,
    colors: true,
    printEmojis: true,
  ),
  level: Env.isDev ? Level.debug : Level.info,
);
