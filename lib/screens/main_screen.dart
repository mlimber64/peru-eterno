import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants/app_colors.dart';
import '../providers/language_provider.dart';

/// Shell de las 5 pestañas principales. El contenido de cada pestaña (y su
/// propia pila de navegación interna — `Navigator.push` desde dentro de una
/// pestaña sigue funcionando exactamente igual que antes) lo gestiona
/// `StatefulShellRoute.indexedStack` en `app_router.dart`; este widget solo
/// dibuja el `Scaffold` + bottom nav (visualmente idéntico a la versión
/// anterior basada en `IndexedStack` propio) y delega el cambio de pestaña a
/// [navigationShell].
class MainScreen extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScreen({super.key, required this.navigationShell});

  @override
  Widget build(BuildContext context) {
    final t = context.watch<LanguageProvider>().t;

    return Scaffold(
      backgroundColor: AppColors.negoCacao,
      body: navigationShell,
      bottomNavigationBar: _buildBottomNav(t),
    );
  }

  Widget _buildBottomNav(String Function(String) t) {
    final labels = [
      t('navigation.home'),
      t('navigation.explore'),
      t('navigation.map'),
      t('navigation.saved'),
      t('navigation.settings'),
    ];
    return Container(
      decoration: BoxDecoration(
        color: AppColors.marronProfundo,
        border: Border(
          top: BorderSide(
            color: AppColors.cremaPergamino.withValues(alpha: 0.08),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(_navItems.length, (i) {
              final isActive = navigationShell.currentIndex == i;
              final item = _navItems[i];
              return Expanded(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // `initialLocation: true` cuando se re-toca la pestaña ya
                  // activa: vuelve a su ruta raíz (mismo comportamiento de
                  // "tap en la pestaña actual reinicia su stack" que tienen
                  // la mayoría de apps con bottom nav).
                  onTap: () => navigationShell.goBranch(
                    i,
                    initialLocation: i == navigationShell.currentIndex,
                  ),
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
                                ? AppColors.ocre.withValues(alpha: 0.15)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Icon(
                            isActive ? item.$2 : item.$1,
                            size: 22,
                            color: isActive
                                ? AppColors.ocre
                                : AppColors.cremaPergamino.withValues(alpha: 0.45),
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          labels[i],
                          style: GoogleFonts.lato(
                            fontSize: 10,
                            fontWeight:
                                isActive ? FontWeight.w700 : FontWeight.w400,
                            color: isActive
                                ? AppColors.ocre
                                : AppColors.cremaPergamino.withValues(alpha: 0.4),
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
    (Icons.map_outlined, Icons.map_rounded),
    (Icons.favorite_border_rounded, Icons.favorite_rounded),
    (Icons.settings_outlined, Icons.settings_rounded),
  ];
}
