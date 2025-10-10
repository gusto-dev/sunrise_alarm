import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;
import '../l10n/app_localizations.dart';
import '../utils/formatters.dart' as fmt;
import '../main.dart';

class ReservedAlarmCard extends StatelessWidget {
  final DateTime? scheduled;
  final tz.Location? location;
  final VoidCallback? onDelete; // shows confirm outside

  const ReservedAlarmCard({
    super.key,
    required this.scheduled,
    required this.location,
    required this.onDelete,
  });

  String _remainText(BuildContext context, DateTime when, {tz.Location? loc}) {
    final l10n = AppLocalizations.of(context);
    final now = loc != null ? tz.TZDateTime.now(loc) : DateTime.now();
    Duration diff = when.difference(now);
    if (diff.isNegative) diff = -diff;
    if (diff.inMinutes < 1) return l10n.remainSoon;
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final days = d > 0 ? l10n.remainDays(d.toString()) : '';
    final hours = h > 0 ? l10n.remainHours(h.toString()) : '';
    final mins = m > 0 ? l10n.remainMinutes(m.toString()) : '';
    return l10n.remain(days, hours, mins);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    if (scheduled == null) {
      return Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          side: BorderSide(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.alarm_off, color: scheme.onSurfaceVariant, size: 34),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(context).noReserved,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Stack(
      children: [
        Card(
          elevation: 0,
          margin: EdgeInsets.zero,
          color: scheme.surface,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            side: BorderSide(color: scheme.outlineVariant),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.alarm, color: scheme.onSurface, size: 40),
                    const SizedBox(width: 10),
                    ValueListenableBuilder<bool>(
                      valueListenable: appTime24h,
                      builder: (context, is24h, __) {
                        final t = is24h
                            ? fmt.fmtHM(scheduled!)
                            : fmt.fmtJmIntl(
                                scheduled!,
                                Localizations.localeOf(context),
                              );
                        return Text(
                          t,
                          style: theme.textTheme.displaySmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  fmt.fmtYMDWIntl(scheduled!, Localizations.localeOf(context)),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) {
                    final offsetTween = Tween<Offset>(
                      begin: const Offset(0.1, 0),
                      end: Offset.zero,
                    ).chain(CurveTween(curve: Curves.easeOut));
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: animation.drive(offsetTween),
                        child: child,
                      ),
                    );
                  },
                  child: Text(
                    _remainText(context, scheduled!, loc: location ?? tz.local),
                    key: ValueKey(
                      _remainText(
                        context,
                        scheduled!,
                        loc: location ?? tz.local,
                      ),
                    ),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: IconButton(
            tooltip: AppLocalizations.of(context).delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}
