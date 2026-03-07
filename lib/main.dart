import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants/constants.dart';
import 'constants/is_debug.dart';
import 'firebase_options.dart';
import 'log.dart';
import 'pages/features/suggestion/execution_page.dart';
import 'pages/features/user/login_page.dart';
import 'pages/loading_page.dart';
import 'providers/features/user/auth/dosuka_auth_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await FirebaseAppCheck.instance.activate(
    providerWeb: ReCaptchaV3Provider('dummy-web-provider-key'),
    providerApple: const AppleAppAttestWithDeviceCheckFallbackProvider(),
  );

  if (ModeConstants.isMobile) {
    if (ModeConstants.isDebug) {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(false);
    } else {
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);
    }

    FlutterError.onError = (errorDetails) {
      FirebaseCrashlytics.instance.recordFlutterFatalError(errorDetails);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  if (ModeConstants.isDebug) {
    logger.d('デバッグモードで起動します。');
  } else {
    logger.d('リリースモードで起動します。');
  }

  final SharedPreferences prefs = await SharedPreferences.getInstance();

  runApp(MyApp(prefs: prefs));
}

class MyApp extends StatelessWidget {
  final SharedPreferences prefs;

  MyApp({super.key, required this.prefs});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<DosukAuthProvider>(
          create: (_) => DosukAuthProvider(
            firebaseAuth: FirebaseAuth.instance,
            googleSignIn: GoogleSignIn(),
            prefs: prefs,
          ),
        ),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: _router,
        title: AppConstants.appTitle,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: ColorConstants.themeColor,
          ),
          useMaterial3: true,
        ),
      ),
    );
  }

  late final GoRouter _router = GoRouter(
    initialLocation: '/',
    debugLogDiagnostics: ModeConstants.isDebug,
    routes: [
      GoRoute(
        name: ViewPageId.splash.pageName,
        path: '/',
        builder: (context, state) => const LoadingPage(),
      ),
      GoRoute(
        name: ViewPageId.login.pageName,
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        name: ViewPageId.execution.pageName,
        path: '/execution',
        builder: (context, state) => const ExecutionPage(),
      ),
    ],
  );
}
