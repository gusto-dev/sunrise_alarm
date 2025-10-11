import 'package:flutter/material.dart';
import '../services/ringtone_service.dart';
import '../services/alarm_service.dart';
import '../l10n/app_localizations.dart';
import '../main.dart';

class StopOverlay {
  static OverlayEntry? _entry;
  static bool get isShowing => _entry != null;

  static void show({int? alarmId, bool cancelScheduled = true}) {
    if (isShowing) return;
    final ctx = navigatorKey.currentContext;
    if (ctx == null) return;
    final l10n = AppLocalizations.of(ctx);

    _entry = OverlayEntry(
      builder: (context) {
        return Stack(
          children: [
            // Scrim
            Positioned.fill(
              child: IgnorePointer(
                ignoring: true, // block interactions visually only
                child: Container(
                  color: const Color(0xFF000000).withValues(alpha: 0.5),
                ),
              ),
            ),
            // Centered card
            Center(
              child: Material(
                color: Colors.transparent,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Card(
                    elevation: 8,
                    clipBehavior: Clip.antiAlias,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            l10n.notifSunriseTitle,
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.notifSunriseBody,
                            style: Theme.of(context).textTheme.bodyMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          FilledButton(
                            onPressed: () async {
                              // Stop sound and cancel alarm(s), then remove overlay
                              try {
                                await RingtoneService.stop();
                              } catch (_) {}
                              if (cancelScheduled) {
                                try {
                                  if (alarmId != null) {
                                    await AlarmService.cancelById(alarmId);
                                  } else {
                                    await AlarmService.cancelAll();
                                  }
                                } catch (_) {}
                              }
                              hide();
                            },
                            child: Text(l10n.alarmActionStop),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );

    navigatorKey.currentState?.overlay?.insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }
}
