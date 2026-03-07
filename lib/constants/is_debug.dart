import 'package:flutter/foundation.dart';

class ModeConstants {
  static bool get isDebug => kDebugMode || kProfileMode;
  static bool get isMobile => !kIsWeb;
  static bool get isAndroid => isMobile && defaultTargetPlatform == TargetPlatform.android;
  static bool get isIOS => isMobile && defaultTargetPlatform == TargetPlatform.iOS;
}
