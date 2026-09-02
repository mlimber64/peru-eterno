import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';

import '../core/constants/app_info.dart';

/// Compartir logros con la hoja nativa del sistema.
///
/// Es la vía de adquisición más barata que tiene la app: los momentos en los
/// que alguien acaba de desbloquear algo o terminar una historia son
/// exactamente cuando le apetece contarlo, y cada mensaje lleva el enlace a
/// la ficha de la tienda.
///
/// Los textos llegan ya traducidos desde la pantalla que llama (con `t(...)`),
/// para que este servicio no dependa del sistema de i18n.
class ShareService {
  const ShareService._();

  /// Comparte [message] añadiendo el enlace a la ficha de la app.
  ///
  /// [subject] solo lo usan algunos destinos (correo, por ejemplo); el resto
  /// lo ignora.
  ///
  /// Nunca lanza: si el usuario cancela o el sistema no ofrece a nadie con
  /// quien compartir, no pasa nada.
  static Future<void> share({
    required String message,
    String? subject,
  }) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: '$message\n\n${AppInfo.storeUrl}',
          subject: subject,
        ),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('ShareService.share: $e');
    }
  }
}
