import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'services/permission_service.dart';
import 'ui/screens/main_navigation_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Initialize permission service
  final permissionService = PermissionService();
  await permissionService.init();

  runApp(
    MultiProvider(
      providers: [ChangeNotifierProvider.value(value: permissionService)],
      child: const EmergencyAlertApp(),
    ),
  );
}

class EmergencyAlertApp extends StatefulWidget {
  const EmergencyAlertApp({super.key});

  @override
  State<EmergencyAlertApp> createState() => _EmergencyAlertAppState();
}

class _EmergencyAlertAppState extends State<EmergencyAlertApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Emergency Alert',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.red,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.red,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(centerTitle: true, elevation: 2),
        cardTheme: const CardThemeData(
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
          ),
        ),
      ),
      home: const MainNavigationScreen(),
    );
  }
}
