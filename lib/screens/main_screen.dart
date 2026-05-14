import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';
import 'explore_screen.dart';
import 'favorites_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    HomeScreen(),
    ExploreScreen(),
    FavoritesScreen(),
    SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final lang = context.watch<LanguageProvider>().currentLanguage;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNav(lang),
    );
  }

  Widget _buildBottomNav(String lang) {
    final labels = _labels(lang);
    return Container(
      decoration: BoxDecoration(
        color: AppColors.marronProfundo,
        border: Border(
          top: BorderSide(
            color: AppColors.cremaPergamino.withOpacity(0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(4, (i) {
              final isActive = _currentIndex == i;
              final item = _navItems[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => setState(() => _currentIndex = i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.ocre.withOpacity(0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isActive ? item.$2 : item.$1,
                            size: 22,
                            color: isActive
                                ? AppColors.ocre
                                : AppColors.cremaPergamino.withOpacity(0.45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labels[i],
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight: isActive
                                ? FontWeight.w700
                                : FontWeight.w400,
                            color: isActive
                                ? AppColors.ocre
                                : AppColors.cremaPergamino.withOpacity(0.4),
                            letterSpacing: 0.3,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }

  // (outlined icon, filled icon)
  static const List<(IconData, IconData)> _navItems = [
    (Icons.home_outlined, Icons.home_rounded),
    (Icons.explore_outlined, Icons.explore_rounded),
    (Icons.favorite_border_rounded, Icons.favorite_rounded),
    (Icons.settings_outlined, Icons.settings_rounded),
  ];

  List<String> _labels(String lang) => switch (lang) {
        'en' => ['Home', 'Explore', 'Saved', 'Settings'],
        'it' => ['Home', 'Esplora', 'Salvati', 'Impostazioni'],
        _ => ['Inicio', 'Explorar', 'Guardados', 'Ajustes'],
      };
}
