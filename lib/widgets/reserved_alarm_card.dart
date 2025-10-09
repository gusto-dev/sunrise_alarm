import 'package:flutter/material.dart';
import 'package:timezone/timezone.dart' as tz;

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

  String _remainText(DateTime when, {tz.Location? loc}) {
    final now = loc != null ? tz.TZDateTime.now(loc) : DateTime.now();
    Duration diff = when.difference(now);
    if (diff.isNegative) diff = -diff;
    if (diff.inMinutes < 1) return '곧 울림';
    final d = diff.inDays;
    final h = diff.inHours % 24;
    final m = diff.inMinutes % 60;
    final parts = <String>[];
    if (d > 0) parts.add('$d일');
    if (h > 0) parts.add('$h시간');
    if (m > 0) parts.add('$m분');
    return '${parts.join(' ')} 남음';
  }

  String _fmtHM(DateTime dt) {
    final h = dt.hour.toString().padLeft(2, '0');
    final m = dt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  String _fmtYMDW(DateTime dt) {
    const wk = ['월', '화', '수', '목', '금', '토', '일'];
    final y = dt.year.toString().padLeft(4, '0');
    final mo = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final w = wk[(dt.weekday - 1) % 7];
    return '$y.$mo.$d($w)';
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
                '아직 예약된 알람이 없어요',
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
                    Text(
                      _fmtHM(scheduled!),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  _fmtYMDW(scheduled!),
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
                    _remainText(scheduled!, loc: location ?? tz.local),
                    key: ValueKey(
                      _remainText(scheduled!, loc: location ?? tz.local),
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
            tooltip: '삭제',
            icon: const Icon(Icons.delete_outline),
            onPressed: onDelete,
          ),
        ),
      ],
    );
  }
}
