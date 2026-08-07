import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const SplitRunnerApp());

class Split {
  String name;
  int? bestMs;
  Split({required this.name, this.bestMs});
  Map<String, dynamic> toJson() => {'name': name, 'bestMs': bestMs};
  factory Split.fromJson(Map<String, dynamic> j) => Split(
        name: j['name'] as String? ?? 'Split',
        bestMs: j['bestMs'] as int?,
      );
}

class SplitRunnerApp extends StatelessWidget {
  const SplitRunnerApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'SplitRunner',
        theme: ThemeData(
          brightness: Brightness.dark,
          useMaterial3: true,
          colorSchemeSeed: Colors.blue,
          scaffoldBackgroundColor: const Color(0xFF101114),
        ),
        home: const TimerPage(),
      );
}

class OverlayBridge {
  static const _channel = MethodChannel('splitrunner/overlay');
  static Future<bool> isGranted() async =>
      await _channel.invokeMethod<bool>('isOverlayGranted') ?? false;
  static Future<void> requestPermission() =>
      _channel.invokeMethod('requestOverlayPermission');
  static Future<void> start({required int elapsedMs, required bool running, required String current, required String next}) =>
      _channel.invokeMethod('startOverlay', {
        'elapsedMs': elapsedMs,
        'running': running,
        'current': current,
        'next': next,
      });
  static Future<void> update({required int elapsedMs, required bool running, required String current, required String next}) =>
      _channel.invokeMethod('updateOverlay', {
        'elapsedMs': elapsedMs,
        'running': running,
        'current': current,
        'next': next,
      });
  static Future<void> stop() => _channel.invokeMethod('stopOverlay');
}

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});
  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  final Stopwatch timer = Stopwatch();
  Timer? ticker;
  List<Split> splits = [
    Split(name: 'Início'),
    Split(name: 'Split 1'),
    Split(name: 'Split 2'),
    Split(name: 'Final'),
  ];
  int current = 0;
  bool finished = false;
  bool overlay = false;

  @override
  void initState() {
    super.initState();
    load();
  }

  @override
  void dispose() {
    ticker?.cancel();
    super.dispose();
  }

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('splits');
    if (data == null) return;
    try {
      final decoded = jsonDecode(data) as List;
      if (!mounted) return;
      setState(() {
        splits = decoded
            .map((e) => Split.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      });
    } catch (_) {}
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('splits', jsonEncode(splits.map((e) => e.toJson()).toList()));
  }

  String formatTime(int ms) {
    final m = (ms ~/ 60000).toString().padLeft(2, '0');
    final s = ((ms ~/ 1000) % 60).toString().padLeft(2, '0');
    final c = ((ms % 1000) ~/ 10).toString().padLeft(2, '0');
    return '$m:$s.$c';
  }

  Future<void> syncOverlay() async {
    if (!overlay) return;
    final next = current + 1 < splits.length ? splits[current + 1].name : 'FINAL';
    await OverlayBridge.update(
      elapsedMs: timer.elapsedMilliseconds,
      running: timer.isRunning,
      current: splits[current].name,
      next: next,
    );
  }

  void start() async {
    if (finished) reset();
    timer.start();
    ticker?.cancel();
    ticker = Timer.periodic(const Duration(milliseconds: 30), (_) {
      if (mounted) setState(() {});
      syncOverlay();
    });
    setState(() {});
    syncOverlay();
  }

  void pause() {
    timer.stop();
    ticker?.cancel();
    setState(() {});
    syncOverlay();
  }

  void split() {
    if (!timer.isRunning || finished) return;
    if (current < splits.length - 1) {
      setState(() => current++);
    } else {
      timer.stop();
      ticker?.cancel();
      setState(() => finished = true);
    }
    syncOverlay();
  }

  void reset() {
    timer..stop()..reset();
    ticker?.cancel();
    setState(() {
      current = 0;
      finished = false;
    });
    syncOverlay();
  }

  Future<void> toggleOverlay() async {
    final granted = await OverlayBridge.isGranted();
    if (!granted) {
      await OverlayBridge.requestPermission();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ative "Permitir sobre outros apps" e toque novamente.')),
      );
      return;
    }
    if (overlay) {
      await OverlayBridge.stop();
      setState(() => overlay = false);
    } else {
      final next = current + 1 < splits.length ? splits[current + 1].name : 'FINAL';
      await OverlayBridge.start(
        elapsedMs: timer.elapsedMilliseconds,
        running: timer.isRunning,
        current: splits[current].name,
        next: next,
      );
      setState(() => overlay = true);
    }
  }

  Future<void> editSplits() async {
    final result = await Navigator.push<List<Split>>(
      context,
      MaterialPageRoute(builder: (_) => SplitEditor(initial: splits)),
    );
    if (result != null && result.isNotEmpty) {
      setState(() {
        splits = result;
        current = 0;
        finished = false;
      });
      await save();
      syncOverlay();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitRunner'),
        actions: [
          IconButton(onPressed: editSplits, icon: const Icon(Icons.edit_note)),
          IconButton(
            tooltip: overlay ? 'Desligar overlay' : 'Ativar overlay',
            onPressed: toggleOverlay,
            icon: Icon(overlay ? Icons.layers_clear : Icons.layers),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 18),
          Text(formatTime(timer.elapsedMilliseconds), style: const TextStyle(fontSize: 56, fontWeight: FontWeight.bold, fontFeatures: [FontFeature.tabularFigures()])),
          const SizedBox(height: 8),
          Text(finished ? 'FINALIZADO' : 'Split ${current + 1}/${splits.length}'),
          if (overlay) const Padding(padding: EdgeInsets.only(top: 6), child: Text('OVERLAY ATIVO', style: TextStyle(color: Colors.greenAccent))),
          const SizedBox(height: 16),
          Expanded(
            child: Card(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              child: ListView.builder(
                itemCount: splits.length,
                itemBuilder: (_, i) => ListTile(
                  leading: CircleAvatar(radius: 15, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                  title: Text(splits[i].name, style: TextStyle(fontWeight: i == current ? FontWeight.bold : FontWeight.normal)),
                  trailing: Text(splits[i].bestMs == null ? '--:--.--' : formatTime(splits[i].bestMs!)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: timer.isRunning ? pause : start, icon: Icon(timer.isRunning ? Icons.pause : Icons.play_arrow), label: Text(timer.isRunning ? 'PAUSAR' : 'INICIAR'))),
                const SizedBox(width: 8),
                Expanded(child: FilledButton.tonalIcon(onPressed: timer.isRunning ? split : null, icon: const Icon(Icons.flag), label: const Text('SPLIT'))),
                const SizedBox(width: 8),
                IconButton.filledTonal(onPressed: reset, icon: const Icon(Icons.restart_alt)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SplitEditor extends StatefulWidget {
  final List<Split> initial;
  const SplitEditor({super.key, required this.initial});
  @override
  State<SplitEditor> createState() => _SplitEditorState();
}

class _SplitEditorState extends State<SplitEditor> {
  late List<Split> list;
  @override
  void initState() {
    super.initState();
    list = widget.initial.map((s) => Split(name: s.name, bestMs: s.bestMs)).toList();
  }

  Future<void> rename(int i) async {
    final c = TextEditingController(text: list[i].name);
    final value = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renomear split'),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('SALVAR')),
        ],
      ),
    );
    if (value != null && value.isNotEmpty) setState(() => list[i].name = value);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('Editar splits'),
          actions: [
            IconButton(onPressed: () => setState(() => list.add(Split(name: 'Novo Split'))), icon: const Icon(Icons.add)),
            TextButton(onPressed: () => Navigator.pop(context, list), child: const Text('SALVAR')),
          ],
        ),
        body: ReorderableListView.builder(
          itemCount: list.length,
          onReorder: (oldIndex, newIndex) {
            setState(() {
              if (newIndex > oldIndex) newIndex--;
              final item = list.removeAt(oldIndex);
              list.insert(newIndex, item);
            });
          },
          itemBuilder: (_, i) => ListTile(
            key: ValueKey('${list[i].name}-$i'),
            leading: const Icon(Icons.drag_handle),
            title: Text(list[i].name),
            onTap: () => rename(i),
            trailing: IconButton(onPressed: list.length <= 1 ? null : () => setState(() => list.removeAt(i)), icon: const Icon(Icons.delete_outline)),
          ),
        ),
      );
}
