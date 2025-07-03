import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:yumly/screens/home_screen.dart';
import 'package:yumly/screens/recipe_screen.dart';
import 'package:yumly/screens/mealplan_screen.dart';
import 'package:yumly/screens/inventory_screen.dart';
import 'package:yumly/screens/settings_screen.dart';
import 'package:yumly/screens/auth_screen.dart';
import 'package:yumly/screens/user_name_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'firebase_options.dart';

// Global theme notifier to be accessed from anywhere in the app
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  // Load saved theme preference
  final prefs = await SharedPreferences.getInstance();
  final isDarkMode = prefs.getBool('isDarkMode') ?? false;
  themeNotifier.value = isDarkMode ? ThemeMode.dark : ThemeMode.light;
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully');
  } catch (e) {
    print('Error initializing Firebase: $e');
  }
  runApp(const YumlyApp());
}

class YumlyApp extends StatefulWidget {
  const YumlyApp({super.key});

  @override
  State<YumlyApp> createState() => _YumlyAppState();
}

class _YumlyAppState extends State<YumlyApp> {
  @override
  void initState() {
    super.initState();
    themeNotifier.addListener(() {
      setState(() {});
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Yumly',
      themeMode: themeNotifier.value,
      theme: _buildLightTheme(),
      darkTheme: _buildDarkTheme(),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/auth': (context) => const AuthScreen(),
        '/username': (context) => const UserNameScreen(),
        '/home': (context) => const HomeScreen(),
        '/recipes': (context) => const RecipeScreen(),
        '/mealplan': (context) => const MealPlanScreen(),
        '/inventory': (context) => const InventoryScreen(),
        '/settings': (context) => const SettingsScreen(),
      },
      onUnknownRoute: (settings) {
        return MaterialPageRoute(
          builder: (context) => const HomeScreen(),
        );
      },
    );
  }
  
  ThemeData _buildLightTheme() {
    return ThemeData(
      useMaterial3: true,
      primaryColor: const Color(0xFF2F7164), // Forest Teal
      colorScheme: const ColorScheme.light(
        primary: Color(0xFF2F7164), // Forest Teal
        secondary: Color(0xFFD6A84E), // Muted Gold
        tertiary: Color(0xFF66BB6A), // Avocado Green
        surface: Color(0xFFFFF8E7), // Vanilla Cream
        background: Color(0xFFFFF8E7), // Vanilla Cream
        error: Color(0xFFFF6F61), // Mild Coral
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFF6B6B6B), // Cozy Grey
        onBackground: Color(0xFF6B6B6B), // Cozy Grey
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFFFFF8E7), // Vanilla Cream
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF2F7164), // Forest Teal
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.pacifico(
          fontSize: 24,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      cardTheme: CardTheme(
        color: Colors.white,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFD6A84E), // Muted Gold
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFF2F7164), // Forest Teal
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFD6A84E), // Muted Gold
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      textTheme: TextTheme(
        displayLarge: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        displayMedium: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        displaySmall: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        headlineLarge: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        headlineMedium: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        headlineSmall: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        titleLarge: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        titleMedium: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        titleSmall: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        bodyLarge: const TextStyle(color: Color(0xFF6B6B6B)), // Cozy Grey
        bodyMedium: const TextStyle(color: Color(0xFF6B6B6B)), // Cozy Grey
        bodySmall: const TextStyle(color: Color(0xFF6B6B6B)), // Cozy Grey
        labelLarge: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        labelMedium: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        labelSmall: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF2F7164), // Forest Teal
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF2F7164), width: 2), // Forest Teal
          borderRadius: BorderRadius.circular(8),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD6A84E)), // Muted Gold
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD6A84E)), // Muted Gold
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(color: Color(0xFF2F7164)), // Forest Teal
        hintStyle: TextStyle(color: const Color(0xFF6B6B6B).withOpacity(0.6)), // Cozy Grey
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFD6A84E), // Muted Gold
        selectedColor: Color(0xFF2F7164), // Forest Teal
        secondarySelectedColor: Color(0xFF2F7164), // Forest Teal
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(color: Colors.white),
        secondaryLabelStyle: TextStyle(color: Colors.white),
        brightness: Brightness.light,
      ),
      dividerColor: Color(0xFFD6A84E), // Muted Gold
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFFFFF8E7), // Vanilla Cream
        selectedItemColor: Color(0xFF2F7164), // Forest Teal
        unselectedItemColor: Color(0xFFD6A84E), // Muted Gold
      ),
    );
  }

  ThemeData _buildDarkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: const Color(0xFF1F3D36), // Deep Pine Green
      colorScheme: const ColorScheme.dark(
        primary: Color(0xFF1F3D36), // Deep Pine Green
        secondary: Color(0xFFA8872B), // Dimmed Gold
        tertiary: Color(0xFF4CAF50), // Muted Avocado Green
        surface: Color(0xFF121212), // Charcoal Black
        background: Color(0xFF121212), // Charcoal Black
        error: Color(0xFFFF5A5F), // Warm Coral
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: Color(0xFFE0E0E0), // Light Grey for better contrast
        onBackground: Color(0xFFE0E0E0), // Light Grey for better contrast
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: const Color(0xFF121212), // Charcoal Black
      appBarTheme: AppBarTheme(
        backgroundColor: const Color(0xFF1F3D36), // Deep Pine Green
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.pacifico(
          fontSize: 24,
          color: Colors.white,
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 2,
      ),
      cardTheme: CardTheme(
        color: const Color(0xFF1E1E1E), // Slate Grey
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFFA8872B), // Dimmed Gold
          foregroundColor: Colors.white,
          elevation: 2,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: const Color(0xFFA8872B), // Dimmed Gold
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: Color(0xFFA8872B), // Dimmed Gold
        foregroundColor: Colors.white,
        elevation: 4,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        displayMedium: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        displaySmall: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        headlineLarge: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        headlineMedium: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        headlineSmall: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        titleLarge: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        titleMedium: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        titleSmall: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        bodyLarge: TextStyle(color: Color(0xFFE0E0E0)), // Light Grey
        bodyMedium: TextStyle(color: Color(0xFFE0E0E0)), // Light Grey
        bodySmall: TextStyle(color: Color(0xFFE0E0E0)), // Light Grey
        labelLarge: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        labelMedium: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
        labelSmall: TextStyle(color: Color(0xFFD0AD60)), // Brighter Gold
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFD0AD60), // Brighter Gold
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF1E1E1E), // Slate Grey
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFFD0AD60), width: 2), // Brighter Gold
          borderRadius: BorderRadius.circular(8),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF3E3E3E)), // Lighter Slate Grey
          borderRadius: BorderRadius.circular(8),
        ),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Color(0xFF3E3E3E)), // Lighter Slate Grey
          borderRadius: BorderRadius.circular(8),
        ),
        labelStyle: const TextStyle(color: Color(0xFFE0E0E0)), // Light Grey
        hintStyle: const TextStyle(color: Color(0xFF9E9E9E)), // Medium Grey
      ),
      chipTheme: const ChipThemeData(
        backgroundColor: Color(0xFFA8872B), // Dimmed Gold
        selectedColor: Color(0xFF1F3D36), // Deep Pine Green
        secondarySelectedColor: Color(0xFF1F3D36), // Deep Pine Green
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        labelStyle: TextStyle(color: Colors.white),
        secondaryLabelStyle: TextStyle(color: Colors.white),
        brightness: Brightness.dark,
      ),
      dividerColor: Color(0xFF3E3E3E), // Lighter Slate Grey
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF121212), // Charcoal Black
        selectedItemColor: Color(0xFFD0AD60), // Brighter Gold
        unselectedItemColor: Color(0xFFBDBDBD), // Light Grey
      ),
    );
  }
}

// Splash Screen widget
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    // Navigate to the appropriate screen after a delay
    _navigateToNextScreen();
  }

  Future<void> _navigateToNextScreen() async {
    // Wait for 2 seconds to display the splash screen
    await Future.delayed(const Duration(seconds: 2));

    // Check if user is logged in
    if (FirebaseAuth.instance.currentUser != null) {
      // Navigate to home if logged in
      Navigator.of(context).pushReplacementNamed('/home');
    } else {
      // Navigate to auth screen if not logged in
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/yumly_bg.png'),
            fit: BoxFit.cover,
          ),
        ),
      ),
    );
  }
}
