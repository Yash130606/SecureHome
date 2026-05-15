// lib/main.dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'core/app_colors.dart';
import 'core/app_text.dart';
import 'core/app_theme.dart';
import 'providers/app_provider.dart';
import 'providers/auth_provider.dart';
import 'screens/splash/splash_screen.dart';
import 'services/alert_service.dart';
import 'services/push_notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FlutterError] ${details.exceptionAsString()}');
  };

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.transparent,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  final provider = AppProvider();
  await provider.loadPrefs();

  runApp(SecureHomeApp(provider: provider));
}

class SecureHomeApp extends StatelessWidget {
  final AppProvider provider;

  const SecureHomeApp({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProxyProvider<AuthProvider, AppProvider>(
          create: (_) => provider,
          update: (_, auth, app) {
            final instance = app ?? provider;
            instance.syncPiSession(
              ip: auth.piIpAddress,
              isConnected: auth.piConnected,
            );
            return instance;
          },
        ),
        ChangeNotifierProvider(create: (_) => AlertService()),
      ],
      child: const _AppRoot(),
    );
  }
}

class _AppRoot extends StatefulWidget {
  const _AppRoot();

  @override
  State<_AppRoot> createState() => _AppRootState();
}

class _AppRootState extends State<_AppRoot> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await PushNotificationService.initialize(
        onNotificationTap: () {
          if (!mounted) return;
          context.read<AppProvider>().setNav(3);
        },
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SecureHome',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SplashScreen(),
      builder: (context, child) {
        return _ForegroundAlertListener(
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}

class _ForegroundAlertListener extends StatefulWidget {
  final Widget child;

  const _ForegroundAlertListener({required this.child});

  @override
  State<_ForegroundAlertListener> createState() =>
      _ForegroundAlertListenerState();
}

class _ForegroundAlertListenerState extends State<_ForegroundAlertListener> {
  String? _lastShownAlertId;

  @override
  Widget build(BuildContext context) {
    final app = context.watch<AppProvider>();
    final alert = app.pendingForegroundAlert;

    if (alert != null && alert.id != _lastShownAlertId) {
      _lastShownAlertId = alert.id;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final messenger = ScaffoldMessenger.maybeOf(context);
        if (messenger == null) return;
        HapticFeedback.mediumImpact();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.fromLTRB(14, 0, 14, 18),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: _alertColor(alert.severity).withOpacity(0.35),
                ),
              ),
              backgroundColor: _alertColor(alert.severity),
              duration: const Duration(seconds: 4),
              content: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _alertIcon(alert.type),
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          alert.title,
                          style: AppText.bodyM(color: Colors.white)
                              .copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${alert.zone} | ${alert.time}',
                          style: AppText.bodyS(
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              action: SnackBarAction(
                label: 'Open',
                textColor: Colors.white,
                onPressed: () {
                  context.read<AppProvider>().setNav(3);
                },
              ),
            ),
          );
        context.read<AppProvider>().consumeForegroundAlert(alert.id);
      });
    }

    return widget.child;
  }

  Color _alertColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'high':
        return AppColors.accentRed.withOpacity(0.95);
      case 'medium':
        return AppColors.accentOrange.withOpacity(0.95);
      default:
        return AppColors.brand.withOpacity(0.95);
    }
  }

  IconData _alertIcon(String type) {
    switch (type.toLowerCase()) {
      case 'person':
        return Icons.person_outline;
      case 'motion':
        return Icons.directions_run;
      case 'system':
        return Icons.security_rounded;
      default:
        return Icons.notifications_active_outlined;
    }
  }
}
