import 'package:flutter/material.dart';
import 'services/firebase_service.dart';
import 'screens/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase App, Auth & Analytics
  try {
    await FirebaseService.initialize();
  } catch (e) {
    debugPrint('Firebase init note: $e');
  }

  runApp(const QtvApp());
}

class QtvApp extends StatelessWidget {
  const QtvApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'QTV - HD Live Video Calls',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark,
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF06070C),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFF8B5CF6),
          secondary: Color(0xFF00E5FF),
          surface: Color(0xFF0D101D),
        ),
        fontFamily: 'sans-serif',
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}
