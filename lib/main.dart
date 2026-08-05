import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const SplitRunnerApp());

class Split { String name; int? bestMs; Split({required this.name, this.bestMs});
  Map<String,dynamic> toJson()=>{'name':name,'bestMs':bestMs};
  factory Split.fromJson(Map<String,dynamic> j)=>Split(name:j['name'] ?? 'Split',bestMs:j['bestMs']); }

class SplitRunnerApp extends StatelessWidget { const SplitRunnerApp({super.key});
  @override Widget build(BuildContext context)=>MaterialApp(debugShowCheckedModeBanner:false,title:'SplitRunner',theme:ThemeData(brightness:Brightness.dark,useMaterial3:true,colorSchemeSeed:Colors.blue,scaffoldBackgroundColor:const Color(0xff101114)),home:const TimerPage()); }

class TimerPage extends StatefulWidget { const TimerPage({super.key}); @override State<TimerPage> createState()=>_TimerPageState(); }
class _TimerPageState extends State<TimerPage> {
  final Stopwatch timer=Stopwatch(); Timer? ticker;
  List<Split> splits=[Split(name:'Início'),Split(name:'Split 2'),Split(name:'Split 3'),Split(name:'Final')];
  int current=0; bool finished=false;
  @override void initState(){super.initState();load();}
  @override void dispose(){ticker?.cancel();super.dispose();}
  Future<void> load() async { final p=await SharedPreferences.getInstance(); final raw=p.getString('splits'); if(raw==null)return; try{final a=(jsonDecode(raw) as List).map((e)=>Split.fromJson(Map<String,dynamic>.from(e))).toList(); if(a.isNotEmpty&&mounted)setState(()=>splits=a);}catch(_){}}
  Future<void> save() async { final p=await SharedPreferences.getInstance(); await p.setString('splits',jsonEncode(splits.map((e)=>e.toJson()).toList())); }
  void start(){if(finished)reset();timer.start();ticker??=Timer.periodic(const Duration(milliseconds:30),(_){if(mounted)setState((){});});setState((){});}
  void pause(){timer.stop();setState((){});}
  void split(){if(!timer.isRunning||finished)return;if(current<splits.length-1){splits[current].bestMs??=timer.elapsedMilliseconds;current++;}else{finished=true;timer.stop();}save();setState((){});}
  void reset(){timer..stop()..reset();current=0;finished=false;setState((){});}
  String fmt(int ms){final m=(ms~/60000).toString().padLeft(2,'0');final s=((ms~/1000)%60).toString().padLeft(2,'0');final c=((ms%1000)~/10).toString().padLeft(2,'0');return '$m:$s.$c';}
  Future<void> edit() async {final r=await Navigator.push<List<Split>>(context,MaterialPageRoute(builder:(_)=>SplitEditor(initial:splits)));if(r!=null&&r.isNotEmpty){setState((){splits=r;current=0;finished=false;});save();}}
  @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('SplitRunner'),actions:[IconButton(onPressed:edit,icon:const Icon(Icons.edit_note))]),body:Column(children:[const SizedBox(height:12),Text(fmt(timer.elapsedMilliseconds),style:const TextStyle(fontSize:58,fontWeight:FontWeight.bold,fontFeatures:[FontFeature.tabularFigures()])),Text(finished?'FINALIZADO':timer.isRunning?'Split ${current+1}/${splits.length}':'PRONTO',style:const TextStyle(color:Colors.white70)),const SizedBox(height:12),Expanded(child:Card(margin:const EdgeInsets.symmetric(horizontal:12),child:ListView.builder(itemCount:splits.length,itemBuilder:(_,i){final active=i==current&&!finished;return ListTile(leading:CircleAvatar(radius:15,child:Text('${i+1}',style:const TextStyle(fontSize:12))),title:Text(splits[i].name,style:TextStyle(fontWeight:active?FontWeight.bold:FontWeight.normal)),trailing:Text(splits[i].bestMs==null?'--:--.--':fmt(splits[i].bestMs!)),tileColor:active?Theme.of(context).colorScheme.primary.withOpacity(.18):null);}))),Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:FilledButton.icon(onPressed:timer.isRunning?pause:start,icon:Icon(timer.isRunning?Icons.pause:Icons.play_arrow),label:Text(timer.isRunning?'PAUSAR':'INICIAR'))),const SizedBox(width:8),Expanded(child:FilledButton.tonalIcon(onPressed:timer.isRunning?split:null,icon:const Icon(Icons.flag),label:const Text('SPLIT'))),const SizedBox(width:8),IconButton.filledTonal(onPressed:reset,icon:const Icon(Icons.restart_alt))]))]));
}

class SplitEditor extends StatefulWidget { final List<Split> initial; const SplitEditor({super.key,required this.initial}); @override State<SplitEditor> createState()=>_SplitEditorState(); }
class _SplitEditorState extends State<SplitEditor>{late List<Split> list; @override void initState(){super.initState();list=widget.initial.map((s)=>Split(name:s.name,bestMs:s.bestMs)).toList();}
 Future<void> rename(int i) async {final c=TextEditingController(text:list[i].name);final v=await showDialog<String>(context:context,builder:(_)=>AlertDialog(title:const Text('Nome do split'),content:TextField(controller:c,autofocus:true,decoration:const InputDecoration(hintText:'Ex.: Boss 1')),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('Cancelar')),FilledButton(onPressed:()=>Navigator.pop(context,c.text.trim()),child:const Text('Salvar'))]));if(v!=null&&v.isNotEmpty)setState(()=>list[i].name=v);}
 @override Widget build(BuildContext context)=>Scaffold(appBar:AppBar(title:const Text('Editar splits'),actions:[IconButton(onPressed:()=>setState(()=>list.add(Split(name:'Novo Split'))),icon:const Icon(Icons.add)),TextButton(onPressed:()=>Navigator.pop(context,list),child:const Text('SALVAR'))]),body:ReorderableListView.builder(itemCount:list.length,onReorder:(a,b){setState((){if(b>a)b--;final x=list.removeAt(a);list.insert(b,x);});},itemBuilder:(_,i)=>ListTile(key:ValueKey('${list[i].name}-$i'),leading:const Icon(Icons.drag_handle),title:Text(list[i].name),subtitle:Text('Split ${i+1}'),onTap:()=>rename(i),trailing:IconButton(onPressed:list.length<=1?null:()=>setState(()=>list.removeAt(i)),icon:const Icon(Icons.delete_outline))})); }
