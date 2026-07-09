import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'screens/splash_screen.dart';

class PeruEternoApp extends StatelessWidget {
  const PeruEternoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Perú Eterno',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.ocre,
          brightness: Brightness.dark,
          surface: AppColors.negoCacao,
        ),
        scaffoldBackgroundColor: AppColors.negoCacao,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          foregroundColor: AppColors.cremaPergamino,
          elevation: 0,
          centerTitle: false,
        ),
        bottomNavigationBarTheme: const BottomNavigationBarThemeData(
          backgroundColor: AppColors.marronProfundo,
          selectedItemColor: AppColors.ocre,
          unselectedItemColor: Color(0x80F5E6C8),
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
