import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

const bg = Color(0xFF080A0F);
const panel = Color(0xFF10141D);
const panel2 = Color(0xFF171D28);
const gold = Color(0xFFFFB52E);
const cyan = Color(0xFF39D8FF);
const red = Color(0xFFFF4F67);

Future<void> _bgMessage(RemoteMessage message) async {
  await Firebase.initializeApp();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(_bgMessage);
  runApp(const CommandCenterApp());
}

class AppState extends ChangeNotifier {
  final auth = FirebaseAuth.instance;
  final db = FirebaseFirestore.instance;
  final storage = FirebaseStorage.instance;
  final uuid = const Uuid();
  String? teamCode;
  String role = 'Player';
  StreamSubscription? membersSub;
  StreamSubscription? chatSub;

  Future<void> loadTeam() async {
    final p = await SharedPreferences.getInstance();
    teamCode = p.getString('teamCode');
    role = p.getString('role') ?? 'Player';
    notifyListeners();
  }

  Future<void> saveTeam(String code, String newRole) async {
    final p = await SharedPreferences.getInstance();
    await p.setString('teamCode', code.trim().toUpperCase());
    await p.setString('role', newRole);
    teamCode = code.trim().toUpperCase();
    role = newRole;
    notifyListeners();
  }

  CollectionReference<Map<String,dynamic>> col(String name) =>
      db.collection('teams').doc(teamCode).collection(name);

  Future<void> ensureUserProfile() async {
    final u = auth.currentUser;
    if (u == null || teamCode == null) return;
    await db.collection('teams').doc(teamCode).collection('members').doc(u.uid).set({
      'uid': u.uid, 'email': u.email, 'role': role, 'displayName': u.displayName ?? u.email?.split('@').first ?? 'Player',
      'online': true, 'lastSeen': FieldValue.serverTimestamp()
    }, SetOptions(merge: true));
    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await db.collection('teams').doc(teamCode).collection('members').doc(u.uid)
          .set({'fcmToken': token}, SetOptions(merge: true));
    }
  }

  Future<String> uploadBytes(Uint8List bytes, String path) async {
    final ref = storage.ref().child(path);
    await ref.putData(bytes);
    return ref.getDownloadURL();
  }
}

class CommandCenterApp extends StatefulWidget {
  const CommandCenterApp({super.key});
  @override State<CommandCenterApp> createState() => _CommandCenterAppState();
}
class _CommandCenterAppState extends State<CommandCenterApp> {
  final state = AppState();
  @override void initState(){ super.initState(); state.loadTeam(); }
  @override Widget build(BuildContext context) => AnimatedBuilder(
    animation: state,
    builder: (_,__) => MaterialApp(
      debugShowCheckedModeBanner:false, theme: ThemeData(
        brightness: Brightness.dark, scaffoldBackgroundColor:bg, colorScheme: const ColorScheme.dark(primary:gold),
        inputDecorationTheme: const InputDecorationTheme(filled:true, fillColor:panel, border:OutlineInputBorder(borderSide:BorderSide.none)),
        cardTheme: const CardThemeData(color:panel, margin:EdgeInsets.zero),
      ),
      home: state.auth.currentUser == null ? AuthScreen(state) : state.teamCode == null ? TeamSetupScreen(state) : HomeScreen(state),
    ),
  );
}

class AuthScreen extends StatefulWidget {
  final AppState s; const AuthScreen(this.s,{super.key});
  @override State<AuthScreen> createState()=>_AuthScreenState();
}
class _AuthScreenState extends State<AuthScreen>{
  final email=TextEditingController(), pass=TextEditingController();
  bool login=true,busy=false;
  Future<void> go() async {
    setState(()=>busy=true);
    try {
      if(login) await FirebaseAuth.instance.signInWithEmailAndPassword(email:email.text.trim(),password:pass.text);
      else await FirebaseAuth.instance.createUserWithEmailAndPassword(email:email.text.trim(),password:pass.text);
    } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('$e'))); }
    if(mounted)setState(()=>busy=false);
  }
  @override Widget build(BuildContext c)=>Scaffold(body:Center(child:SingleChildScrollView(padding:const EdgeInsets.all(24),child:Column(children:[
    const Icon(Icons.shield_moon,size:76,color:gold), const SizedBox(height:16),
    const Text('BGMI COMMAND CENTER',style:TextStyle(fontSize:28,fontWeight:FontWeight.w900,letterSpacing:1)),
    const Text('V4 • TEAM OPERATIONS',style:TextStyle(color:cyan,fontWeight:FontWeight.bold)),
    const SizedBox(height:28), TextField(controller:email,keyboardType:TextInputType.emailAddress,decoration:const InputDecoration(labelText:'Email')),
    const SizedBox(height:12), TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Password')),
    const SizedBox(height:18), SizedBox(width:double.infinity,height:52,child:ElevatedButton(onPressed:busy?null:go,child:Text(busy?'PLEASE WAIT':login?'LOGIN':'CREATE ACCOUNT'))),
    TextButton(onPressed:()=>setState(()=>login=!login),child:Text(login?'Create a new account':'Back to login'))
  ]))));
}

class TeamSetupScreen extends StatefulWidget {
  final AppState s; const TeamSetupScreen(this.s,{super.key});
  @override State<TeamSetupScreen> createState()=>_TeamSetupState();
}
class _TeamSetupState extends State<TeamSetupScreen>{
  final code=TextEditingController(); String role='Player';
  @override Widget build(BuildContext c)=>Scaffold(body:Center(child:Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[
    const Text('JOIN / CREATE TEAM',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:18),
    TextField(controller:code,textCapitalization:TextCapitalization.characters,decoration:const InputDecoration(labelText:'TEAM CODE',hintText:'BAGGA01')),
    const SizedBox(height:12),DropdownButtonFormField<String>(value:role,items:['Owner','Coach','IGL','Analyst','Player'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>role=x!)),
    const SizedBox(height:18),SizedBox(width:double.infinity,height:52,child:ElevatedButton(onPressed:()async{if(code.text.trim().isEmpty)return;await widget.s.saveTeam(code.text,role);await widget.s.ensureUserProfile();},child:const Text('ENTER COMMAND CENTER')))
  ]))));
}

class HomeScreen extends StatefulWidget {
  final AppState s; const HomeScreen(this.s,{super.key});
  @override State<HomeScreen> createState()=>_HomeState();
}
class _HomeState extends State<HomeScreen>{
  int index=0;
  final pages=['Dashboard','Players','Planner','Chat','Matches','Recorder'];
  @override Widget build(BuildContext c){
    final widgets=[Dashboard(widget.s),PlayersPage(widget.s),Planner(widget.s),ChatPage(widget.s),MatchesPage(widget.s),RecorderPage(widget.s)];
    return Scaffold(appBar:AppBar(title:Text(pages[index]),actions:[IconButton(onPressed:()=>showAboutDialog(context:context,applicationName:'BGMI Team Command Center V4',applicationVersion:'4.0.0',children:[const Text('Native Flutter esports team operations app.')]),icon:const Icon(Icons.info_outline))]),
      body:widgets[index],
      bottomNavigationBar:NavigationBar(selectedIndex:index,onDestinationSelected:(i)=>setState(()=>index=i),destinations:const [
        NavigationDestination(icon:Icon(Icons.dashboard),label:'Home'),NavigationDestination(icon:Icon(Icons.groups),label:'Players'),
        NavigationDestination(icon:Icon(Icons.map),label:'Planner'),NavigationDestination(icon:Icon(Icons.forum),label:'Chat'),
        NavigationDestination(icon:Icon(Icons.event),label:'Matches'),NavigationDestination(icon:Icon(Icons.videocam),label:'Record')]));
  }
}

class Dashboard extends StatelessWidget{
  final AppState s; const Dashboard(this.s,{super.key});
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[
    Container(padding:const EdgeInsets.all(20),decoration:BoxDecoration(borderRadius:BorderRadius.circular(22),gradient:const LinearGradient(colors:[Color(0xFF252B38),Color(0xFF11151D)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text('TEAM ${s.teamCode}',style:const TextStyle(color:gold,fontWeight:FontWeight.w900,fontSize:14)),const SizedBox(height:6),
      const Text('TACTICAL COMMAND',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:8),
      Text('Role: ${s.role} • Realtime Firebase workspace',style:const TextStyle(color:Colors.white70))
    ])),const SizedBox(height:14),
    _tile(Icons.map,'Strategy Planner','Circle + rotation + draw plans',c,()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>Planner(s)))),
    _tile(Icons.forum,'Team Chat','Realtime comms and announcements',c,()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>ChatPage(s)))),
    _tile(Icons.videocam,'Match Recorder','Native capture controls',c,()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>RecorderPage(s)))),
  ]);
  Widget _tile(IconData i,String a,String b,BuildContext c,VoidCallback f)=>Card(child:ListTile(onTap:f,leading:CircleAvatar(backgroundColor:gold,child:Icon(i,color:Colors.black)),title:Text(a,style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text(b)));
}

class PlayersPage extends StatefulWidget{
  final AppState s; const PlayersPage(this.s,{super.key});
  @override State<PlayersPage> createState()=>_PlayersState();
}
class _PlayersState extends State<PlayersPage>{
  final name=TextEditingController(), uid=TextEditingController(), ign=TextEditingController();
  Future<void> add()async{await widget.s.col('players').add({'name':name.text,'ign':ign.text,'uid':uid.text,'role':'Player','createdAt':FieldValue.serverTimestamp()});name.clear();uid.clear();ign.clear();}
  @override Widget build(BuildContext c)=>Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:Row(children:[Expanded(child:TextField(controller:ign,decoration:const InputDecoration(hintText:'IGN'))),const SizedBox(width:8),IconButton(onPressed:()=>showModalBottomSheet(context:c,builder:(_)=>Padding(padding:const EdgeInsets.all(18),child:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:name,decoration:const InputDecoration(labelText:'Name')),TextField(controller:uid,decoration:const InputDecoration(labelText:'BGMI UID')),const SizedBox(height:10),ElevatedButton(onPressed:()async{await add();if(context.mounted)Navigator.pop(context);},child:const Text('ADD PLAYER'))])),),icon:const Icon(Icons.person_add,color:gold))])),
    Expanded(child:StreamBuilder<QuerySnapshot>(stream:widget.s.col('players').orderBy('createdAt',descending:false).snapshots(),builder:(_,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(12),children:snap.data!.docs.map((d){final x=d.data() as Map<String,dynamic>;return Card(child:ListTile(leading:const CircleAvatar(child:Icon(Icons.person)),title:Text(x['ign']??'Player'),subtitle:Text('${x['name']??''} • UID ${x['uid']??''}'),trailing:Text(x['role']??'Player'));}).toList());}))
  ]);
}

enum Tool{free,circle,arrow,marker,eraser}
class Planner extends StatefulWidget{
  final AppState s; const Planner(this.s,{super.key});
  @override State<Planner> createState()=>_PlannerState();
}
class _PlannerState extends State<Planner>{
  Tool tool=Tool.free; String map='Erangel'; String phase='Drop'; final List<List<Offset>> strokes=[]; final List<Offset> markers=[]; final List<List<Offset>> arrows=[];
  void clear(){setState((){strokes.clear();markers.clear();arrows.clear();});}
  Future<void> save()async{
    final data={'map':map,'phase':phase,'strokes':strokes.map((x)=>x.map((p)=>[p.dx,p.dy]).toList()).toList(),'markers':markers.map((p)=>[p.dx,p.dy]).toList(),'arrows':arrows.map((x)=>x.map((p)=>[p.dx,p.dy]).toList()).toList(),'createdAt':FieldValue.serverTimestamp()};
    await widget.s.col('plans').add(data); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Plan saved to team workspace')));
  }
  @override Widget build(BuildContext c)=>Column(children:[
    SingleChildScrollView(scrollDirection:Axis.horizontal,padding:const EdgeInsets.all(8),child:Row(children:[
      DropdownButton<String>(value:map,items:['Erangel','Miramar','Sanhok','Vikendi','Rondo'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>map=x!)),
      const SizedBox(width:12),DropdownButton<String>(value:phase,items:['Drop','Loot','First Circle','Mid Game','Rotation','End Game'].map((x)=>DropdownMenuItem(value:x,child:Text(x))).toList(),onChanged:(x)=>setState(()=>phase=x!)),
      IconButton(onPressed:clear,icon:const Icon(Icons.delete_outline)),IconButton(onPressed:save,icon:const Icon(Icons.cloud_upload,color:gold))
    ])),
    Wrap(spacing:6,children:Tool.values.map((t)=>ChoiceChip(label:Text(t.name.toUpperCase()),selected:tool==t,onSelected:(_)=>setState(()=>tool=t))).toList()),
    const SizedBox(height:8),
    Expanded(child:LayoutBuilder(builder:(_,box)=>GestureDetector(
      onPanStart:(d){final p=d.localPosition;if(tool==Tool.free||tool==Tool.eraser)strokes.add([p]);},
      onPanUpdate:(d){final p=d.localPosition;if(tool==Tool.free||tool==Tool.eraser){if(strokes.isEmpty)strokes.add([]);setState(()=>strokes.last.add(p));}else if(tool==Tool.arrow){if(arrows.isEmpty||arrows.last.length==2)arrows.add([p]);else setState(()=>arrows.last.add(p));}},
      onTapDown:(d){if(tool==Tool.marker)setState(()=>markers.add(d.localPosition));},
      child:CustomPaint(size:Size.infinite,painter:TacticalPainter(strokes,markers,arrows,tool,box.maxWidth,box.maxHeight))
    )))
  ]);
}

class TacticalPainter extends CustomPainter{
  final List<List<Offset>> s; final List<Offset> m; final List<List<Offset>> a; final Tool t; final double w,h;
  TacticalPainter(this.s,this.m,this.a,this.t,this.w,this.h);
  @override void paint(Canvas c,Size z){
    final p=Paint()..color=const Color(0xFF18212A)..style=PaintingStyle.fill;c.drawRect(Offset.zero&z,p);
    final grid=Paint()..color=Colors.white10..strokeWidth=1;
    for(double x=0;x<w;x+=32)c.drawLine(Offset(x,0),Offset(x,h),grid);
    for(double y=0;y<h;y+=32)c.drawLine(Offset(0,y),Offset(w,y),grid);
    for(final path in s){final q=Paint()..color=t==Tool.eraser?bg:cyan..strokeWidth=4..strokeCap=StrokeCap.round..style=PaintingStyle.stroke;for(int i=1;i<path.length;i++)c.drawLine(path[i-1],path[i],q);}
    final mp=Paint()..color=gold;for(final x in m)c.drawCircle(x,7,mp);
    final ap=Paint()..color=red..strokeWidth=5;for(final path in a)if(path.length>=2)c.drawLine(path.first,path.last,ap);
    final zone=Paint()..color=gold.withOpacity(.12)..style=PaintingStyle.fill;c.drawCircle(Offset(w*.55,h*.48),w*.22,zone);
    final border=Paint()..color=gold.withOpacity(.65)..style=PaintingStyle.stroke..strokeWidth=3;c.drawCircle(Offset(w*.55,h*.48),w*.22,border);
  }
  @override bool shouldRepaint(covariant TacticalPainter old)=>true;
}

class ChatPage extends StatefulWidget{
  final AppState s; const ChatPage(this.s,{super.key});
  @override State<ChatPage> createState()=>_ChatState();
}
class _ChatState extends State<ChatPage>{
  final msg=TextEditingController(); bool announcement=false;
  Future<void> send()async{if(msg.text.trim().isEmpty)return;await widget.s.col('messages').add({'text':msg.text.trim(),'userId':widget.s.auth.currentUser!.uid,'email':widget.s.auth.currentUser!.email,'type':announcement?'announcement':'chat','createdAt':FieldValue.serverTimestamp()});msg.clear();}
  @override Widget build(BuildContext c)=>Column(children:[
    Expanded(child:StreamBuilder<QuerySnapshot>(stream:widget.s.col('messages').orderBy('createdAt',descending:false).limitToLast(150).snapshots(),builder:(_,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(12),children:snap.data!.docs.map((d){final x=d.data() as Map<String,dynamic>;final ann=x['type']=='announcement';return Align(alignment:x['userId']==widget.s.auth.currentUser!.uid?Alignment.centerRight:Alignment.centerLeft,child:Card(color:ann?const Color(0xFF332819):panel2,child:Padding(padding:const EdgeInsets.all(10),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[if(ann)const Text('ANNOUNCEMENT',style:TextStyle(color:gold,fontWeight:FontWeight.bold)),Text(x['text']??''),const SizedBox(height:3),Text(x['email']??'',style:const TextStyle(fontSize:10,color:Colors.white54))])));}).toList());})),
    Padding(padding:const EdgeInsets.all(8),child:Row(children:[IconButton(onPressed:()=>setState(()=>announcement=!announcement),icon:Icon(announcement?Icons.campaign:Icons.chat,color:announcement?gold:null)),Expanded(child:TextField(controller:msg,decoration:const InputDecoration(hintText:'Team message'))),IconButton(onPressed:send,icon:const Icon(Icons.send,color:gold))]))
  ]);
}

class MatchesPage extends StatefulWidget{
  final AppState s; const MatchesPage(this.s,{super.key});
  @override State<MatchesPage> createState()=>_MatchesState();
}
class _MatchesState extends State<MatchesPage>{
  final title=TextEditingController(), venue=TextEditingController(); DateTime date=DateTime.now();
  Future<void> add()async{await widget.s.col('matches').add({'title':title.text,'venue':venue.text,'date':Timestamp.fromDate(date),'createdAt':FieldValue.serverTimestamp()});title.clear();venue.clear();}
  @override Widget build(BuildContext c)=>Column(children:[
    Padding(padding:const EdgeInsets.all(12),child:ElevatedButton.icon(onPressed:()=>showDialog(context:c,builder:(_)=>AlertDialog(title:const Text('Add Match'),content:Column(mainAxisSize:MainAxisSize.min,children:[TextField(controller:title,decoration:const InputDecoration(labelText:'Match / Scrim')),TextField(controller:venue,decoration:const InputDecoration(labelText:'Map / Venue')),TextButton(onPressed:()async{date=(await showDatePicker(context:c,firstDate:DateTime.now(),lastDate:DateTime(2030),initialDate:date))??date;},child:const Text('SELECT DATE'))]),actions:[TextButton(onPressed:(){add();Navigator.pop(c);},child:const Text('SAVE'))]),),icon:const Icon(Icons.add),label:const Text('ADD MATCH'))),
    Expanded(child:StreamBuilder<QuerySnapshot>(stream:widget.s.col('matches').orderBy('date').snapshots(),builder:(_,snap){if(!snap.hasData)return const Center(child:CircularProgressIndicator());return ListView(padding:const EdgeInsets.all(12),children:snap.data!.docs.map((d){final x=d.data() as Map<String,dynamic>;final dt=(x['date'] as Timestamp?)?.toDate();return Card(child:ListTile(leading:const Icon(Icons.event,color:gold),title:Text(x['title']??'Match'),subtitle:Text('${x['venue']??''}\n${dt==null?'':DateFormat('dd MMM yyyy • HH:mm').format(dt)}')));}).toList());}))
  ]);
}

class RecorderPage extends StatefulWidget{
  final AppState s; const RecorderPage(this.s,{super.key});
  @override State<RecorderPage> createState()=>_RecorderState();
}
class _RecorderState extends State<RecorderPage>{
  int fps=60,res=1080; bool recording=false;
  Future<void> prepare()async{await Permission.microphone.request();setState(()=>recording=true);}
  Future<void> stop()async{setState(()=>recording=false);if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('Recorder stopped. Connect native MediaProjection encoder for final capture export.')));}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(16),children:[
    Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      const Text('NATIVE MATCH RECORDER',style:TextStyle(fontWeight:FontWeight.w900,fontSize:22)),const SizedBox(height:8),
      const Text('Target settings • actual FPS depends on device encoder.'),const SizedBox(height:18),
      const Text('FPS'),Wrap(spacing:8,children:[24,30,60].map((x)=>ChoiceChip(label:Text('$x FPS'),selected:fps==x,onSelected:(_)=>setState(()=>fps=x))).toList()),
      const SizedBox(height:12),const Text('QUALITY'),Wrap(spacing:8,children:[360,480,720,1080].map((x)=>ChoiceChip(label:Text('${x}p'),selected:res==x,onSelected:(_)=>setState(()=>res=x))).toList()),
      const SizedBox(height:18),SizedBox(width:double.infinity,height:52,child:ElevatedButton.icon(onPressed:recording?stop:prepare,icon:Icon(recording?Icons.stop:Icons.fiber_manual_record),label:Text(recording?'STOP RECORDING':'START RECORDING')))
    ]))),
    const SizedBox(height:12),Card(child:ListTile(leading:const Icon(Icons.tune,color:cyan),title:const Text('Background optimization'),subtitle:const Text('Use Android MediaProjection + hardware H.264/HEVC encoder in the native layer for reliable long recordings.')))
  ]);
}
