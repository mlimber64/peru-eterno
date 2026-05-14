import 'package:flutter/material.dart';
import 'core/constants/app_colors.dart';
import 'screens/splash_screen.dart';

class PeruEternoApp extends StatelessWidget {
  const PeruEternoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Peru Eterno',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.ocre,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: AppColors.cremaPergamino,
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.marronOscuro,
          foregroundColor: AppColors.cremaPergamino,
          elevation: 0,
          centerTitle: true,
        ),
      ),
      home: const SplashScreen(),
    );
  }
}
