 import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(const SplitRunnerApp());
}

// ============================================================
// SPLIT
// ============================================================

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

  factory Split.fromJson(
    Map<String, dynamic> json,
  ) {
    return Split(
      name: json['name'] as String? ?? 'Split',
      bestMs: json['bestMs'] as int?,
    );
  }
}

// ============================================================
// APP
// ============================================================

class SplitRunnerApp extends StatelessWidget {
  const SplitRunnerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SplitRunner',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        scaffoldBackgroundColor: const Color(0xFF101114),
      ),
      home: const TimerPage(),
    );
  }
}

// ============================================================
// OVERLAY BRIDGE
//
// Comunicação:
//
// Flutter -> Android
// Android -> Flutter
// ============================================================

class OverlayBridge {
  // IMPORTANTE:
  // O channel é público porque o TimerPage precisa
  // registrar o receptor dos comandos enviados pelo Android.
  static const MethodChannel channel =
      MethodChannel('splitrunner/overlay');

  // ==========================================================
  // VERIFICAR PERMISSÃO
  // ==========================================================

  static Future<bool> isGranted() async {
    final result = await channel.invokeMethod<bool>(
      'isOverlayGranted',
    );

    return result ?? false;
  }

  // ==========================================================
  // PEDIR PERMISSÃO
  // ==========================================================

  static Future<void> requestPermission() async {
    await channel.invokeMethod(
      'requestOverlayPermission',
    );
  }

  // ==========================================================
  // INICIAR OVERLAY
  // ==========================================================

  static Future<void> start({
    required int elapsedMs,
    required bool running,
    required String current,
    required String next,
  }) async {
    await channel.invokeMethod(
      'startOverlay',
      {
        'elapsedMs': elapsedMs,
        'running': running,
        'current': current,
        'next': next,
      },
    );
  }

  // ==========================================================
  // ATUALIZAR OVERLAY
  // ==========================================================

  static Future<void> update({
    required int elapsedMs,
    required bool running,
    required String current,
    required String next,
  }) async {
    await channel.invokeMethod(
      'updateOverlay',
      {
        'elapsedMs': elapsedMs,
        'running': running,
        'current': current,
        'next': next,
      },
    );
  }

  // ==========================================================
  // PARAR OVERLAY
  // ==========================================================

  static Future<void> stop() async {
    await channel.invokeMethod(
      'stopOverlay',
    );
  }
}

// ============================================================
// TIMER PAGE
// ============================================================

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

  // ==========================================================
  // INIT
  // ==========================================================

  @override
  void initState() {
    super.initState();

    // ========================================================
    // RECEBER COMANDOS DO ANDROID
    // ========================================================
    //
    // Android -> Flutter
    //
    // toggleTimerFromOverlay
    // restartTimerFromOverlay
    //

    OverlayBridge.channel.setMethodCallHandler(
      _handleOverlayCommand,
    );

    loadSplits();
  }

  // ==========================================================
  // RECEBER COMANDOS DO OVERLAY
  // ==========================================================

  Future<dynamic> _handleOverlayCommand(
    MethodCall call,
  ) async {
    switch (call.method) {
      // --------------------------------------------------------
      // 1 TOQUE NO OVERLAY
      // --------------------------------------------------------

      case 'toggleTimerFromOverlay':
        await toggleTimerFromOverlay();
        return true;

      // --------------------------------------------------------
      // 2 TOQUES NO OVERLAY
      // --------------------------------------------------------

      case 'restartTimerFromOverlay':
        await restartTimerFromOverlay();
        return true;

      // --------------------------------------------------------
      // COMANDO DESCONHECIDO
      // --------------------------------------------------------

      default:
        return null;
    }
  }

  // ==========================================================
  // DISPOSE
  // ==========================================================

  @override
  void dispose() {
    ticker?.cancel();

    // Remove o receptor do MethodChannel.
    OverlayBridge.channel.setMethodCallHandler(null);

    super.dispose();
  }

  // ==========================================================
  // LOAD SPLITS
  // ==========================================================

  Future<void> loadSplits() async {
    final prefs =
        await SharedPreferences.getInstance();

    final data =
        prefs.getString('splits');

    if (data == null) {
      return;
    }

    try {
      final decoded =
          jsonDecode(data) as List;

      if (!mounted) {
        return;
      }

      setState(() {
        splits = decoded
            .map(
              (item) => Split.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList();

        if (splits.isEmpty) {
          splits = [
            Split(name: 'Início'),
            Split(name: 'Split 1'),
            Split(name: 'Split 2'),
            Split(name: 'Final'),
          ];
        }
      });
    } catch (_) {
      // Mantém os splits padrão.
    }
  }

  // ==========================================================
  // SAVE SPLITS
  // ==========================================================

  Future<void> saveSplits() async {
    final prefs =
        await SharedPreferences.getInstance();

    await prefs.setString(
      'splits',
      jsonEncode(
        splits
            .map(
              (split) => split.toJson(),
            )
            .toList(),
      ),
    );
  }

  // ==========================================================
  // FORMAT TIME
  // ==========================================================

  String formatTime(
    int milliseconds,
  ) {
    final minutes =
        milliseconds ~/ 60000;

    final seconds =
        (milliseconds % 60000) ~/ 1000;

    final centiseconds =
        (milliseconds % 1000) ~/ 10;

    return '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }

  // ==========================================================
  // NEXT SPLIT
  // ==========================================================

  String get nextSplitName {
    if (current + 1 < splits.length) {
      return splits[current + 1].name;
    }

    return 'FINAL';
  }

  // ==========================================================
  // START TICKER
  // ==========================================================

  void startTicker() {
    ticker?.cancel();

    ticker = Timer.periodic(
      const Duration(milliseconds: 30),
      (_) {
        if (!mounted) {
          return;
        }

        setState(() {});
      },
    );
  }

  // ==========================================================
  // SYNC OVERLAY
  // ==========================================================

  Future<void> syncOverlay() async {
    if (!overlay) {
      return;
    }

    if (splits.isEmpty) {
      return;
    }

    try {
      await OverlayBridge.update(
        elapsedMs:
            timer.elapsedMilliseconds,
        running:
            timer.isRunning,
        current:
            splits[current].name,
        next:
            nextSplitName,
      );
    } catch (_) {
      // Overlay pode ter sido fechado pelo Android.
    }
  }

  // ==========================================================
  // START
  // ==========================================================

  Future<void> start() async {
    if (finished) {
      timer
        ..stop()
        ..reset();

      current = 0;

      finished = false;
    }

    timer.start();

    startTicker();

    if (mounted) {
      setState(() {});
    }

    await syncOverlay();
  }

  // ==========================================================
  // PAUSE
  // ==========================================================

  Future<void> pause() async {
    timer.stop();

    ticker?.cancel();

    if (mounted) {
      setState(() {});
    }

    await syncOverlay();
  }

  // ==========================================================
  // TOGGLE TIMER
  // ==========================================================

  Future<void> toggleTimer() async {
    if (timer.isRunning) {
      await pause();
    } else {
      await start();
    }
  }

  // ==========================================================
  // TOGGLE VINDO DO OVERLAY
  // ==========================================================

  Future<void> toggleTimerFromOverlay() async {
    // Se a run terminou, um toque inicia uma nova run.
    if (finished) {
      await start();
      return;
    }

    // --------------------------------------------------------
    // PAUSAR
    // --------------------------------------------------------

    if (timer.isRunning) {
      timer.stop();

      ticker?.cancel();
    }

    // --------------------------------------------------------
    // INICIAR
    // --------------------------------------------------------

    else {
      timer.start();

      startTicker();
    }

    if (mounted) {
      setState(() {});
    }

    // Atualiza o overlay com o novo estado.
    await syncOverlay();
  }

  // ==========================================================
  // SPLIT
  // ==========================================================

  Future<void> split() async {
    if (!timer.isRunning ||
        finished) {
      return;
    }

    final elapsed =
        timer.elapsedMilliseconds;

    // Salva o tempo do split atual
    // somente se ainda não existir.
    if (current < splits.length &&
        splits[current].bestMs == null) {
      splits[current].bestMs =
          elapsed;
    }

    // --------------------------------------------------------
    // PRÓXIMO SPLIT
    // --------------------------------------------------------

    if (current < splits.length - 1) {
      current++;
    }

    // --------------------------------------------------------
    // FINAL
    // --------------------------------------------------------

    else {
      timer.stop();

      ticker?.cancel();

      finished = true;
    }

    await saveSplits();

    if (mounted) {
      setState(() {});
    }

    await syncOverlay();
  }

  // ==========================================================
  // RESET
  // ==========================================================

  Future<void> reset() async {
    timer
      ..stop()
      ..reset();

    ticker?.cancel();

    current = 0;

    finished = false;

    if (mounted) {
      setState(() {});
    }

    await syncOverlay();
  }

  // ==========================================================
  // RESTART VINDO DO OVERLAY
  // ==========================================================

  Future<void> restartTimerFromOverlay() async {
    // --------------------------------------------------------
    // RESET COMPLETO
    // --------------------------------------------------------

    timer
      ..stop()
      ..reset();

    ticker?.cancel();

    current = 0;

    finished = false;

    // --------------------------------------------------------
    // INICIA NOVAMENTE
    // --------------------------------------------------------

    timer.start();

    startTicker();

    if (mounted) {
      setState(() {});
    }

    // Atualiza imediatamente o overlay.
    await syncOverlay();
  }

  // ==========================================================
  // TOGGLE OVERLAY
  // ==========================================================

  Future<void> toggleOverlay() async {
    try {
      final granted =
          await OverlayBridge.isGranted();

      // --------------------------------------------------------
      // PERMISSÃO NÃO CONCEDIDA
      // --------------------------------------------------------

      if (!granted) {
        await OverlayBridge.requestPermission();

        if (!mounted) {
          return;
        }

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            duration:
                Duration(seconds: 4),
            content: Text(
              'Permita "Exibir sobre outros apps" '
              'e depois toque novamente no botão Overlay.',
            ),
          ),
        );

        return;
      }

      // --------------------------------------------------------
      // DESLIGAR OVERLAY
      // --------------------------------------------------------

      if (overlay) {
        await OverlayBridge.stop();

        if (mounted) {
          setState(() {
            overlay = false;
          });
        }

        return;
      }

      // --------------------------------------------------------
      // LIGAR OVERLAY
      // --------------------------------------------------------

      await OverlayBridge.start(
        elapsedMs:
            timer.elapsedMilliseconds,
        running:
            timer.isRunning,
        current:
            splits[current].name,
        next:
            nextSplitName,
      );

      if (mounted) {
        setState(() {
          overlay = true;
        });
      }
    }

    // ----------------------------------------------------------
    // ERRO PLATFORM
    // ----------------------------------------------------------

    on PlatformException catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          duration:
              const Duration(seconds: 5),
          content: Text(
            'Erro no Overlay: '
            '${error.message ?? error.code}',
          ),
        ),
      );
    }

    // ----------------------------------------------------------
    // OUTRO ERRO
    // ----------------------------------------------------------

    catch (error) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          duration:
              const Duration(seconds: 5),
          content: Text(
            'Erro ao iniciar Overlay: $error',
          ),
        ),
      );
    }
  }

  // ==========================================================
  // EDIT SPLITS
  // ==========================================================

  Future<void> editSplits() async {
    final result =
        await Navigator.push<List<Split>>(
      context,
      MaterialPageRoute(
        builder: (_) => SplitEditor(
          initial: splits,
        ),
      ),
    );

    if (result == null ||
        result.isEmpty) {
      return;
    }

    setState(() {
      splits = result;

      current = 0;

      finished = false;
    });

    await saveSplits();

    await syncOverlay();
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final elapsed =
        timer.elapsedMilliseconds;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'SplitRunner',
        ),
        actions: [

          // ----------------------------------------------------
          // EDITAR SPLITS
          // ----------------------------------------------------

          IconButton(
            tooltip:
                'Editar splits',
            onPressed:
                editSplits,
            icon: const Icon(
              Icons.edit_note,
            ),
          ),

          // ----------------------------------------------------
          // OVERLAY
          // ----------------------------------------------------

          IconButton(
            tooltip: overlay
                ? 'Desligar overlay'
                : 'Ativar overlay',
            onPressed:
                toggleOverlay,
            icon: Icon(
              overlay
                  ? Icons.layers_clear
                  : Icons.layers,
            ),
          ),
        ],
      ),

      body: Column(
        children: [

          const SizedBox(
            height: 18,
          ),

          // ----------------------------------------------------
          // TIMER
          // ----------------------------------------------------

          Text(
            formatTime(elapsed),
            style: const TextStyle(
              fontSize: 56,
              fontWeight:
                  FontWeight.bold,
              fontFeatures: [
                FontFeature
                    .tabularFigures(),
              ],
            ),
          ),

          const SizedBox(
            height: 8,
          ),

          // ----------------------------------------------------
          // STATUS
          // ----------------------------------------------------

          Text(
            finished
                ? 'FINALIZADO'
                : 'Split ${current + 1}/${splits.length}',
            style: const TextStyle(
              fontSize: 18,
            ),
          ),

          if (overlay)
            const Padding(
              padding:
                  EdgeInsets.only(
                top: 6,
              ),
              child: Text(
                'OVERLAY ATIVO',
                style: TextStyle(
                  color:
                      Colors.greenAccent,
                  fontWeight:
                      FontWeight.bold,
                ),
              ),
            ),

          const SizedBox(
            height: 16,
          ),

          // ----------------------------------------------------
          // SPLITS
          // ----------------------------------------------------

          Expanded(
            child: Card(
              margin:
                  const EdgeInsets.symmetric(
                horizontal: 12,
              ),
              child:
                  ListView.builder(
                itemCount:
                    splits.length,
                itemBuilder:
                    (context, index) {

                  final split =
                      splits[index];

                  final active =
                      index == current &&
                          !finished;

                  return ListTile(
                    leading:
                        CircleAvatar(
                      radius: 15,
                      child: Text(
                        '${index + 1}',
                        style:
                            const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ),

                    title: Text(
                      split.name,
                      style:
                          TextStyle(
                        fontWeight: active
                            ? FontWeight
                                .bold
                            : FontWeight
                                .normal,
                      ),
                    ),

                    trailing: Text(
                      split.bestMs ==
                              null
                          ? '--:--.--'
                          : formatTime(
                              split.bestMs!,
                            ),
                    ),
                  );
                },
              ),
            ),
          ),

          // ----------------------------------------------------
          // CONTROLES
          // ----------------------------------------------------

          Padding(
            padding:
                const EdgeInsets.all(
              12,
            ),
            child: Row(
              children: [

                // ----------------------------------------------
                // START / PAUSE
                // ----------------------------------------------

                Expanded(
                  child:
                      FilledButton.icon(
                    onPressed:
                        toggleTimer,
                    icon: Icon(
                      timer.isRunning
                          ? Icons.pause
                          : Icons.play_arrow,
                    ),
                    label: Text(
                      timer.isRunning
                          ? 'PAUSAR'
                          : 'INICIAR',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                // ----------------------------------------------
                // SPLIT
                // ----------------------------------------------

                Expanded(
                  child:
                      FilledButton
                          .tonalIcon(
                    onPressed:
                        timer.isRunning
                            ? split
                            : null,
                    icon: const Icon(
                      Icons.flag,
                    ),
                    label: const Text(
                      'SPLIT',
                    ),
                  ),
                ),

                const SizedBox(
                  width: 8,
                ),

                // ----------------------------------------------
                // RESET
                // ----------------------------------------------

                IconButton.filledTonal(
                  tooltip:
                      'Resetar',
                  onPressed:
                      reset,
                  icon: const Icon(
                    Icons.restart_alt,
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

// ============================================================
// SPLIT EDITOR
// ============================================================

class SplitEditor
    extends StatefulWidget {

  final List<Split> initial;

  const SplitEditor({
    super.key,
    required this.initial,
  });

  @override
  State<SplitEditor> createState() =>
      _SplitEditorState();
}

class _SplitEditorState
    extends State<SplitEditor> {

  late List<Split> list;

  @override
  void initState() {
    super.initState();

    list = widget.initial
        .map(
          (split) => Split(
            name: split.name,
            bestMs: split.bestMs,
          ),
        )
        .toList();
  }

  // ==========================================================
  // RENAME
  // ==========================================================

  Future<void> rename(
    int index,
  ) async {

    final controller =
        TextEditingController(
      text: list[index].name,
    );

    final value =
        await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Renomear split',
          ),

          content: TextField(
            controller:
                controller,
            autofocus: true,
            textInputAction:
                TextInputAction.done,
            decoration:
                const InputDecoration(
              labelText: 'Nome',
              hintText:
                  'Ex.: Boss 1',
            ),
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                );
              },
              child: const Text(
                'CANCELAR',
              ),
            ),

            FilledButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  controller.text
                      .trim(),
                );
              },
              child: const Text(
                'SALVAR',
              ),
            ),
          ],
        );
      },
    );

    if (value == null ||
        value.isEmpty) {
      return;
    }

    setState(() {
      list[index].name =
          value;
    });
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(
    BuildContext context,
  ) {

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Editar splits',
        ),

        actions: [

          // ----------------------------------------------------
          // ADICIONAR
          // ----------------------------------------------------

          IconButton(
            tooltip:
                'Adicionar split',
            onPressed: () {

              setState(() {

                list.add(
                  Split(
                    name:
                        'Novo Split',
                  ),
                );
              });
            },

            icon: const Icon(
              Icons.add,
            ),
          ),

          // ----------------------------------------------------
          // SALVAR
          // ----------------------------------------------------

          TextButton(
            onPressed: () {

              Navigator.pop(
                context,
                list,
              );
            },

            child: const Text(
              'SALVAR',
            ),
          ),
        ],
      ),

      body:
          ReorderableListView.builder(
        itemCount:
            list.length,

        // ------------------------------------------------------
        // REORDENAR
        // ------------------------------------------------------

        onReorder: (
          oldIndex,
          newIndex,
        ) {

          setState(() {

            if (
                newIndex >
                oldIndex) {

              newIndex--;
            }

            final item =
                list.removeAt(
              oldIndex,
            );

            list.insert(
              newIndex,
              item,
            );
          });
        },

        // ------------------------------------------------------
        // ITEM
        // ------------------------------------------------------

        itemBuilder: (
          context,
          index,
        ) {

          final split =
              list[index];

          return ListTile(
            key: ValueKey(
              '${split.name}-$index',
            ),

            leading:
                const Icon(
              Icons.drag_handle,
            ),

            title:
                Text(
              split.name,
            ),

            subtitle:
                Text(
              'Split ${index + 1}',
            ),

            onTap: () {
              rename(index);
            },

            trailing:
                IconButton(
              tooltip:
                  'Excluir',

              onPressed:
                  list.length <= 1
                      ? null
                      : () {

                          setState(() {

                            list.removeAt(
                              index,
                            );
                          });
                        },

              icon:
                  const Icon(
                Icons.delete_outline,
              ),
            ),
          );
        },
      ),
    );
  }
}   
