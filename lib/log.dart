import 'package:logger/logger.dart';

Logger get logger => Log.instance;

class Log extends Logger {
  Log._() : super(printer: PrettyPrinter(dateTimeFormat: DateTimeFormat.dateAndTime));
  static final instance = Log._();
}
