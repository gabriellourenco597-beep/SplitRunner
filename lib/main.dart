import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SplitRunnerApp());
}

class Split {
  String name;
  int? bestMs;

  Split({
    required this.name,
    this.bestMs,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'bestMs': bestMs,
    };
  }

  factory Split.fromJson(Map<String, dynamic> json) {
    return Split(
      name: json['name'] as String,
      bestMs: json['bestMs'] as int?,
    );
  }
}

class SplitRunnerApp extends StatelessWidget {
  const SplitRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitRunner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        colorSchemeSeed: Colors.blue,
        useMaterial3: true,
      ),
      home: const TimerPage(),
    );
  }
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

    if (data != null) {
      final decoded = jsonDecode(data) as List;

      setState(() {
        splits = decoded
            .map(
              (item) => Split.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();
      });
    }
  }

  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.setString(
      'splits',
      jsonEncode(
        splits.map((split) => split.toJson()).toList(),
      ),
    );
  }

  void start() {
    if (finished) {
      reset();
    }

    timer.start();

    ticker?.cancel();

    ticker = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) {
        setState(() {});
      },
    );

    setState(() {});
  }

  void pause() {
    timer.stop();
    ticker?.cancel();

    setState(() {});
  }

  void split() {
    if (!timer.isRunning || finished) {
      return;
    }

    if (current < splits.length - 1) {
      setState(() {
        current++;
      });
    } else {
      timer.stop();
      ticker?.cancel();

      setState(() {
        finished = true;
      });
    }
  }

  void reset() {
    timer
      ..stop()
      ..reset();

    ticker?.cancel();

    setState(() {
      current = 0;
      finished = false;
    });
  }

  String formatTime(int milliseconds) {
    final minutes = milliseconds ~/ 60000;
    final seconds = (milliseconds % 60000) ~/ 1000;
    final ms = (milliseconds % 1000) ~/ 10;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${ms.toString().padLeft(2, '0')}';
  }

  Future<void> editSplits() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => SplitEditor(
          splits: splits,
          onChanged: (newSplits) {
            splits = newSplits;
            save();
            setState(() {});
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final elapsed = timer.elapsedMilliseconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text('SplitRunner'),
        actions: [
          IconButton(
            tooltip: 'Editar splits',
            onPressed: editSplits,
            icon: const Icon(Icons.edit),
          ),
        ],
      ),
      body: Column(
        children: [
          const SizedBox(height: 30),

          Text(
            formatTime(elapsed),
            style: const TextStyle(
              fontSize: 56,
              fontWeight: FontWeight.bold,
              fontFeatures: [
                FontFeature.tabularFigures(),
              ],
            ),
          ),

          const SizedBox(height: 10),

          Text(
            finished
                ? 'FINALIZADO'
                : 'Split ${current + 1} / ${splits.length}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          const SizedBox(height: 30),

          Expanded(
            child: ListView.builder(
              itemCount: splits.length,
              itemBuilder: (context, index) {
                final split = splits[index];

                return ListTile(
                  leading: CircleAvatar(
                    child: Text('${index + 1}'),
                  ),
                  title: Text(split.name),
                  trailing: index == current
                      ? const Icon(
                          Icons.play_arrow,
                          color: Colors.green,
                        )
                      : null,
                );
              },
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: timer.isRunning ? split : start,
                    icon: Icon(
                      timer.isRunning
                          ? Icons.flag
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      timer.isRunning ? 'SPLIT' : 'START',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: timer.isRunning ? pause : reset,
                    icon: Icon(
                      timer.isRunning
                          ? Icons.pause
                          : Icons.refresh,
                    ),
                    label: Text(
                      timer.isRunning ? 'PAUSAR' : 'RESET',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class SplitEditor extends StatefulWidget {
  final List<Split> splits;
  final ValueChanged<List<Split>> onChanged;

  const SplitEditor({
    super.key,
    required this.splits,
    required this.onChanged,
  });

  @override
  State<SplitEditor> createState() => _SplitEditorState();
}

class _SplitEditorState extends State<SplitEditor> {
  late List<Split> list;

  @override
  void initState() {
    super.initState();

    list = widget.splits
        .map(
          (split) => Split(
            name: split.name,
            bestMs: split.bestMs,
          ),
        )
        .toList();
  }

  Future<void> rename(int index) async {
    final controller = TextEditingController(
      text: list[index].name,
    );

    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renomear split'),
          content: TextField(
            controller: controller,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Nome',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('CANCELAR'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text.trim(),
                );
              },
              child: const Text('SALVAR'),
            ),
          ],
        );
      },
    );

    if (result != null && result.isNotEmpty) {
      setState(() {
        list[index].name = result;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Editar splits'),
        actions: [
          IconButton(
            tooltip: 'Adicionar split',
            onPressed: () {
              setState(() {
                list.add(
                  Split(
                    name: 'Novo Split',
                  ),
                );
              });
            },
            icon: const Icon(Icons.add),
          ),
          TextButton(
            onPressed: () {
              widget.onChanged(list);
              Navigator.pop(context);
            },
            child: const Text('SALVAR'),
          ),
        ],
      ),
      body: ReorderableListView.builder(
        itemCount: list.length,
        onReorder: (oldIndex, newIndex) {
          setState(() {
            if (newIndex > oldIndex) {
              newIndex--;
            }

            final item = list.removeAt(oldIndex);
            list.insert(newIndex, item);
          });
        },
        itemBuilder: (context, index) {
          final split = list[index];

          return ListTile(
            key: ValueKey(split),
            title: Text(split.name),
            onTap: () => rename(index),
            trailing: IconButton(
              onPressed: list.length <= 1
                  ? null
                  : () {
                      setState(() {
                        list.removeAt(index);
                      });
                    },
              icon: const Icon(Icons.delete_outline),
            ),
          );
        },
      ),
    );
  }
}
