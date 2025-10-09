import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import '../services/quote_service.dart';

class AlarmScreen extends StatefulWidget {
  const AlarmScreen({super.key});

  @override
  State<AlarmScreen> createState() => _AlarmScreenState();
}

class _AlarmScreenState extends State<AlarmScreen> {
  late final String quote;
  final ctrl = TextEditingController();
  final player = AudioPlayer()..setReleaseMode(ReleaseMode.loop);
  double tolerance = 0.4; // 오타 허용 정도 (0=엄격,1=관대)
  bool _ringing = true; // 멈출 때까지 계속 울림

  @override
  void initState() {
    super.initState();
    quote = QuoteService.pick();
    player.play(AssetSource('sounds/alarm.mp3')); // Flutter assets에서 재생
  }

  @override
  void dispose() {
    player.stop();
    player.dispose();
    ctrl.dispose();
    super.dispose();
  }

  Future<void> _tryStop() async {
    if (QuoteService.pass(ctrl.text, quote, tolerance)) {
      await player.stop();
      _ringing = false;
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('해제 완료! 좋은 하루 ✨')));
      Navigator.of(context).pop();
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('조금만 더 정확히 입력해봐요!')));
    }
  }

  Future<void> _forceStop() async {
    await player.stop();
    _ringing = false;
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_ringing,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return; // 이미 뒤로가기가 수행되었음
        if (!mounted) return;
        // 울리는 중에는 뒤로가기를 막고 안내를 표시
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알람을 멈추려면 아래 "멈춤" 버튼을 누르세요.')),
        );
      },
      child: Scaffold(
        backgroundColor: Colors.yellow[50],
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                const Spacer(),
                Text(
                  '알람 해제: 아래 문장을 그대로 입력하세요',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Text(
                  quote,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: ctrl,
                  autofocus: true,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _tryStop,
                        child: const Text('해제'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.redAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _forceStop,
                        child: const Text('멈춤'),
                      ),
                    ),
                  ],
                ),
                const Spacer(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
