import 'package:flutter/material.dart';
import '../main.dart';
import '../services/settings_service.dart';
import '../l10n/app_localizations.dart';
import '../services/alarm_service.dart';
import '../utils/toast.dart' show showTopToast;

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _language = 'system'; // 'system'|'ko'|'en'
  bool _time24h = true;
  String _theme = 'auto'; // 'auto'|'light'|'dark'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lang = await SettingsService.getLanguageOverride();
    final t24 = await SettingsService.getTimeFormat24h();
    final theme = await SettingsService.getThemeModePref();
    if (!mounted) return;
    setState(() {
      _language = lang;
      _time24h = t24;
      _theme = theme;
    });
  }

  Future<void> _applyLanguage(String v) async {
    setState(() => _language = v);
    await SettingsService.setLanguageOverride(v);
    if (v == 'system') {
      appLocale.value = null;
    } else {
      appLocale.value = Locale(v);
    }
  }

  Future<void> _applyTimeFormat(bool v) async {
    setState(() => _time24h = v);
    await SettingsService.setTimeFormat24h(v);
    appTime24h.value = v;
  }

  Future<void> _applyTheme(String v) async {
    setState(() => _theme = v);
    await SettingsService.setThemeModePref(v);
    switch (v) {
      case 'light':
        appThemeMode.value = ThemeMode.light;
        break;
      case 'dark':
        appThemeMode.value = ThemeMode.dark;
        break;
      default:
        // auto: follow current heuristic in HomeScreen; here we set to system default
        appThemeMode.value = ThemeMode.system;
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListView(
        children: [
          const SizedBox(height: 8),
          ListTile(
            title: Text(l10n.settingsLanguage),
            subtitle: Text(
              _language == 'system'
                  ? l10n.settingsSystemDefault
                  : (_language == 'ko'
                        ? l10n.settingsKorean
                        : l10n.settingsEnglish),
            ),
            trailing: DropdownButton<String>(
              value: _language,
              onChanged: (v) => v == null ? null : _applyLanguage(v),
              items: [
                DropdownMenuItem(
                  value: 'system',
                  child: Text(l10n.settingsSystemDefault),
                ),
                DropdownMenuItem(value: 'ko', child: Text(l10n.settingsKorean)),
                DropdownMenuItem(
                  value: 'en',
                  child: Text(l10n.settingsEnglish),
                ),
              ],
            ),
          ),
          SwitchListTile(
            title: Text(l10n.settingsTime24h),
            value: _time24h,
            onChanged: _applyTimeFormat,
          ),
          ListTile(
            title: Text(l10n.settingsTheme),
            trailing: DropdownButton<String>(
              value: _theme,
              onChanged: (v) => v == null ? null : _applyTheme(v),
              items: [
                DropdownMenuItem(
                  value: 'auto',
                  child: Text(l10n.settingsThemeAuto),
                ),
                DropdownMenuItem(
                  value: 'light',
                  child: Text(l10n.settingsThemeLight),
                ),
                DropdownMenuItem(
                  value: 'dark',
                  child: Text(l10n.settingsThemeDark),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              l10n.settingsNote,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(l10n.settingsTestAlarm),
            subtitle: Text(l10n.settingsTestAlarmDesc),
            trailing: FilledButton(
              onPressed: () async {
                final when = DateTime.now().add(const Duration(seconds: 10));
                await AlarmService.scheduleNew(
                  when,
                  title: l10n.notifTestTitle,
                  body: l10n.notifTestBody,
                );
                if (!mounted) return;
                showTopToast(context, l10n.testAlarmScheduledToast);
              },
              child: Text(l10n.settingsRun),
            ),
          ),
        ],
      ),
    );
  }
}
