import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

void main() => runApp(const HierarchyApp());

const api = 'https://campuslive-hierarchy-api.onrender.com';

class S {
  static const bg=Color(0xFFF5F7FB), navy=Color(0xFF0B1734), blue=Color(0xFF315EFB),
      green=Color(0xFF22B573), orange=Color(0xFFFFA31A), red=Color(0xFFE74C3C),
      muted=Color(0xFF6D7890);
}

String rlabel(String r){
  if(r=='admin')return 'College Admin';
  if(r=='principal')return 'Principal';
  if(r=='hod')return 'HOD';
  if(r=='staff')return 'Staff';
  return 'Student';
}

String childLabel(String r){
  if(r=='principal')return 'HODs';
  if(r=='hod')return 'Staff';
  if(r=='staff')return 'Students';
  return 'College Users';
}

IconData rIcon(String r){
  if(r=='admin')return Icons.admin_panel_settings_rounded;
  if(r=='principal')return Icons.account_balance_rounded;
  if(r=='hod')return Icons.apartment_rounded;
  if(r=='staff')return Icons.badge_rounded;
  return Icons.school_rounded;
}

class AppState extends ChangeNotifier{
  final http.Client client=http.Client();
  String? token;
  Map<String,dynamic>? me;
  List<dynamic> portal=[],directory=[],inbox=[],departments=[],audit=[];
  Map<String,dynamic> dashboard={};
  bool busy=false,online=false;
  Timer? timer;

  Map<String,String> get h=>{'Content-Type':'application/json',if(token!=null)'Authorization':'Bearer '+token!};

  Future<dynamic> req(String method,String path,{Object? body,bool auth=true})async{
    final u=Uri.parse(api+path);
    final head=auth?h:{'Content-Type':'application/json'};
    final data=body==null?null:jsonEncode(body);
    late http.Response r;
    if(method=='GET')r=await client.get(u,headers:head).timeout(const Duration(seconds:20));
    else if(method=='POST')r=await client.post(u,headers:head,body:data).timeout(const Duration(seconds:20));
    else if(method=='PATCH')r=await client.patch(u,headers:head,body:data).timeout(const Duration(seconds:20));
    else r=await client.put(u,headers:head,body:data).timeout(const Duration(seconds:20));
    dynamic j;
    if(r.body.isNotEmpty){try{j=jsonDecode(r.body);}catch(_){}}
    if(r.statusCode<200||r.statusCode>=300){
      throw Exception(j is Map&&j['detail']!=null?j['detail'].toString():'Request failed '+r.statusCode.toString());
    }
    online=true;
    return j;
  }

  Future<void> login(String code,String email,String pass)async{
    busy=true;notifyListeners();
    try{
      final j=await req('POST','/auth/login',auth:false,body:{
        'college_code':code.trim(),'email':email.trim(),'password':pass
      }) as Map<String,dynamic>;
      token=j['token'].toString();me=j['user'] as Map<String,dynamic>;
      await refresh();
      startPolling();
    }finally{busy=false;notifyListeners();}
  }

  Future<void> setup(String college,String code,String name,String email,String pass)async{
    busy=true;notifyListeners();
    try{
      final j=await req('POST','/setup/college',auth:false,body:{
        'college_name':college.trim(),'college_code':code.trim(),'admin_name':name.trim(),
        'admin_email':email.trim(),'admin_password':pass
      }) as Map<String,dynamic>;
      token=j['token'].toString();me=j['user'] as Map<String,dynamic>;
      await refresh();startPolling();
    }finally{busy=false;notifyListeners();}
  }

  void startPolling(){
    timer?.cancel();
    timer=Timer.periodic(const Duration(seconds:5),(_){refresh();});
  }

  Future<void> refresh()async{
    if(token==null)return;
    try{
      portal=await req('GET','/portal') as List<dynamic>;
      dashboard=await req('GET','/dashboard') as Map<String,dynamic>;
      directory=await req('GET','/directory') as List<dynamic>;
      inbox=await req('GET','/inbox') as List<dynamic>;
      if(me?['role']=='admin'){
        departments=await req('GET','/admin/departments') as List<dynamic>;
        audit=await req('GET','/admin/audit') as List<dynamic>;
      }
      online=true;
    }catch(_){online=false;}
    notifyListeners();
  }

  Future<List<dynamic>> allUsers()=>req('GET','/admin/users').then((v)=>v as List<dynamic>);

  Future<void> addDept(String n,String c)async{
    await req('POST','/admin/departments',body:{'name':n.trim(),'code':c.trim()});
    await refresh();
  }

  Future<void> addUser(String n,String e,String p,String role,int? dept,String year,String sec)async{
    await req('POST','/admin/users',body:{
      'name':n.trim(),'email':e.trim(),'password':p,'role':role,
      'department_id':dept,'year':year.trim(),'section':sec.trim()
    });
    await refresh();
  }

  Future<void> send(List<int> ids,String title,String body,String kind)async{
    await req('POST','/assignments',body:{
      'target_user_ids':ids,'title':title.trim(),'body':body.trim(),'kind':kind
    });
    await refresh();
  }

  Future<void> mark(int id,String status)async{
    await req('PATCH','/assignments/'+id.toString(),body:{'status':status});
    await refresh();
  }

  Future<List<dynamic>> portalRole(String role)=>req('GET','/admin/portal/'+role).then((v)=>v as List<dynamic>);

  Future<void> savePortal(String role,List<dynamic> items)async{
    for(var i=0;i<items.length;i++)items[i]['position']=i;
    await req('PUT','/admin/portal/'+role,body:{'items':items});
    await refresh();
  }

  void logout(){
    timer?.cancel();token=null;me=null;portal=[];directory=[];inbox=[];departments=[];audit=[];dashboard={};online=false;notifyListeners();
  }
}

final st=AppState();

class HierarchyApp extends StatelessWidget{
  const HierarchyApp({super.key});
  @override Widget build(BuildContext c)=>AnimatedBuilder(
    animation:st,builder:(_,__)=>MaterialApp(
      debugShowCheckedModeBanner:false,title:'CampusLive',
      theme:ThemeData(useMaterial3:true,scaffoldBackgroundColor:S.bg,
        colorScheme:ColorScheme.fromSeed(seedColor:S.blue),
        cardTheme:const CardThemeData(elevation:0,color:Colors.white,
          shape:RoundedRectangleBorder(borderRadius:BorderRadius.all(Radius.circular(20)))),
        inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.white,
          border:OutlineInputBorder(borderRadius:BorderRadius.circular(15),borderSide:BorderSide.none))),
      home:st.me==null?const Login():const Shell()));
}

class Login extends StatefulWidget{const Login({super.key});@override State<Login> createState()=>_Login();}
class _Login extends State<Login>{
  final code=TextEditingController(),email=TextEditingController(),pass=TextEditingController();
  Future<void> go()async{
    if(code.text.trim().isEmpty||email.text.trim().isEmpty||pass.text.isEmpty){msg(context,'Fill all fields',true);return;}
    try{await st.login(code.text,email.text,pass.text);}catch(e){if(mounted)msg(context,e.toString(),true);}
  }
  @override Widget build(BuildContext c)=>Scaffold(backgroundColor:S.navy,body:SafeArea(child:Center(child:
    SingleChildScrollView(padding:const EdgeInsets.all(22),child:ConstrainedBox(constraints:const BoxConstraints(maxWidth:430),child:Column(children:[
      Container(width:78,height:78,decoration:BoxDecoration(color:S.blue,borderRadius:BorderRadius.circular(24)),
        child:const Icon(Icons.account_tree_rounded,color:Colors.white,size:38)),
      const SizedBox(height:15),const Text('CampusLive',style:TextStyle(color:Colors.white,fontSize:31,fontWeight:FontWeight.w900)),
      const Text('Admin → Principal → HOD → Staff → Student',textAlign:TextAlign.center,style:TextStyle(color:Colors.white60)),
      const SizedBox(height:24),Card(child:Padding(padding:const EdgeInsets.all(20),child:Column(children:[
        field(code,'College Code',Icons.domain_rounded),const SizedBox(height:10),
        field(email,'Official Email',Icons.mail_outline_rounded),const SizedBox(height:10),
        TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Password',prefixIcon:Icon(Icons.lock_outline))),
        const SizedBox(height:16),FilledButton(onPressed:st.busy?null:go,style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)),
          child:st.busy?const CircularProgressIndicator():const Text('Login')),
        TextButton.icon(onPressed:()=>Navigator.push(c,MaterialPageRoute(builder:(_)=>const Setup())),
          icon:const Icon(Icons.add_business_rounded),label:const Text('First time? Create College Admin'))
      ]))),
      const SizedBox(height:10),const Text('No dummy users. Admin creates the real hierarchy.',style:TextStyle(color:Colors.white54,fontSize:10.5))
    ]))))));
}

class Setup extends StatefulWidget{const Setup({super.key});@override State<Setup> createState()=>_Setup();}
class _Setup extends State<Setup>{
  final college=TextEditingController(),code=TextEditingController(),name=TextEditingController(),email=TextEditingController(),pass=TextEditingController();
  Future<void> go()async{
    if([college,code,name,email,pass].any((x)=>x.text.trim().isEmpty)){msg(context,'Fill all fields',true);return;}
    try{await st.setup(college.text,code.text,name.text,email.text,pass.text);if(mounted)Navigator.popUntil(context,(r)=>r.isFirst);}
    catch(e){if(mounted)msg(context,e.toString(),true);}
  }
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Create College')),body:ListView(padding:const EdgeInsets.all(18),children:[
    const Note('Creates first College Admin','After setup Admin creates Principal, Departments, HODs, Staff and Students.'),
    const SizedBox(height:14),field(college,'Official College Name',Icons.school_rounded),const SizedBox(height:10),
    field(code,'College Code',Icons.domain_rounded),const SizedBox(height:10),field(name,'Admin Name',Icons.person_rounded),
    const SizedBox(height:10),field(email,'Admin Email',Icons.mail_outline),const SizedBox(height:10),
    TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Admin Password (8+)',prefixIcon:Icon(Icons.lock_outline))),
    const SizedBox(height:16),FilledButton.icon(onPressed:go,icon:const Icon(Icons.rocket_launch_rounded),label:const Text('Create College & Admin'),
      style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)))
  ]));
}

class Shell extends StatefulWidget{const Shell({super.key});@override State<Shell> createState()=>_Shell();}
class _Shell extends State<Shell>{
  String sel='overview';
  @override void initState(){super.initState();st.refresh();}
  @override Widget build(BuildContext c){
    final me=st.me!,items=st.portal.where((x)=>x['enabled']==true).toList()..sort((a,b)=>(a['position']??0).compareTo(b['position']??0));
    if(items.isEmpty)items.add({'module':'overview','label':'Overview','enabled':true,'position':0});
    if(!items.any((x)=>x['module']==sel))sel=items.first['module'].toString();
    return Scaffold(appBar:AppBar(title:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
      Text((me['college_name']??'College').toString(),style:const TextStyle(fontSize:16,fontWeight:FontWeight.w900)),
      Text(rlabel(me['role'].toString()),style:const TextStyle(fontSize:10,color:S.muted))
    ]),actions:[
      Center(child:Chip(side:BorderSide.none,backgroundColor:st.online?const Color(0xFFE9F8F1):const Color(0xFFFFF1E5),
        label:Text(st.online?'LIVE':'OFFLINE',style:TextStyle(color:st.online?S.green:S.orange,fontSize:9,fontWeight:FontWeight.w900)))),
      IconButton(onPressed:st.refresh,icon:const Icon(Icons.refresh_rounded))
    ]),drawer:Drawer(child:SafeArea(child:Column(children:[
      UserAccountsDrawerHeader(decoration:const BoxDecoration(color:S.navy),accountName:Text(me['name'].toString()),
        accountEmail:Text(rlabel(me['role'].toString())+' • '+me['college_code'].toString()),
        currentAccountPicture:CircleAvatar(child:Icon(rIcon(me['role'].toString())))),
      Expanded(child:ListView(children:[for(final x in items)ListTile(selected:sel==x['module'],leading:Icon(mIcon(x['module'].toString())),
        title:Text(x['label'].toString()),onTap:(){setState(()=>sel=x['module'].toString());Navigator.pop(c);})])),
      ListTile(leading:const Icon(Icons.logout_rounded),title:const Text('Logout'),onTap:(){st.logout();Navigator.pop(c);})
    ]))),body:SafeArea(child:page(sel)));
  }
  Widget page(String k){
    if(k=='overview')return const Overview();
    if(k=='directory')return const Directory();
    if(k=='inbox')return const Inbox();
    if(k=='assign')return const Assign();
    if(k=='users')return const Users();
    if(k=='departments')return const Departments();
    if(k=='portal_control')return const PortalControl();
    if(k=='live_activity')return const Activity();
    if(k=='profile')return const Profile();
    return ListView(padding:const EdgeInsets.all(18),children:[EmptyBox(Icons.extension_rounded,k,'Enabled by Admin')]);
  }
}

IconData mIcon(String m){
  if(m=='overview')return Icons.dashboard_rounded;if(m=='directory')return Icons.groups_rounded;if(m=='inbox')return Icons.inbox_rounded;
  if(m=='assign')return Icons.assignment_add;if(m=='users')return Icons.manage_accounts_rounded;if(m=='departments')return Icons.apartment_rounded;
  if(m=='portal_control')return Icons.dashboard_customize_rounded;if(m=='live_activity')return Icons.monitor_heart_rounded;
  if(m=='profile')return Icons.person_rounded;return Icons.grid_view_rounded;
}

class Overview extends StatelessWidget{const Overview({super.key});
  @override Widget build(BuildContext c)=>AnimatedBuilder(animation:st,builder:(_,__) {
    final me=st.me!,r=me['role'].toString(),d=st.dashboard;final list=<Map<String,dynamic>>[];
    if(r=='admin'){final counts=d['counts'] is Map?d['counts'] as Map:{};
      list.addAll([met('Principal',counts['principal']??0,Icons.account_balance_rounded),met('HODs',counts['hod']??0,Icons.apartment_rounded),
        met('Staff',counts['staff']??0,Icons.badge_rounded),met('Students',counts['student']??0,Icons.school_rounded),
        met('Departments',d['departments']??0,Icons.account_tree_rounded),met('Pending',d['pending_assignments']??0,Icons.pending_actions_rounded)]);
    }else if(r=='principal'){list.addAll([met('HODs',d['hod_count']??0,Icons.apartment_rounded),met('Unread',d['unread']??0,Icons.mark_email_unread_rounded)]);}
    else if(r=='hod'){list.addAll([met('Staff',d['staff_count']??0,Icons.badge_rounded),met('Unread',d['unread']??0,Icons.mark_email_unread_rounded)]);}
    else if(r=='staff'){list.addAll([met('Students',d['student_count']??0,Icons.school_rounded),met('Unread',d['unread']??0,Icons.mark_email_unread_rounded)]);}
    else{list.add(met('New Updates',d['unread']??0,Icons.notifications_active_rounded));}
    return RefreshIndicator(onRefresh:st.refresh,child:ListView(padding:const EdgeInsets.all(18),children:[
      Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:S.navy,borderRadius:BorderRadius.circular(24)),child:Row(children:[
        CircleAvatar(radius:27,backgroundColor:Colors.white12,child:Icon(rIcon(r),color:Colors.white)),const SizedBox(width:12),
        Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
          Text(me['name'].toString(),style:const TextStyle(color:Colors.white,fontSize:19,fontWeight:FontWeight.w900)),
          Text(rlabel(r),style:const TextStyle(color:Color(0xFF8EB0FF),fontWeight:FontWeight.w800)),
          if(me['department']!=null)Text(me['department'].toString(),style:const TextStyle(color:Colors.white60,fontSize:10))
        ]))
      ])),const SizedBox(height:18),
      Text(r=='admin'?'College Monitoring':r=='student'?'My Portal':childLabel(r)+' Monitoring',style:const TextStyle(fontSize:17,fontWeight:FontWeight.w900,color:S.navy)),
      const SizedBox(height:10),GridView.builder(shrinkWrap:true,physics:const NeverScrollableScrollPhysics(),itemCount:list.length,
        gridDelegate:const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount:2,crossAxisSpacing:10,mainAxisSpacing:10,childAspectRatio:1.55),
        itemBuilder:(_,i)=>Card(child:Padding(padding:const EdgeInsets.all(14),child:Row(children:[
          CircleAvatar(backgroundColor:const Color(0xFFEEF2FF),child:Icon(list[i]['icon'] as IconData,color:S.blue)),const SizedBox(width:10),
          Column(mainAxisAlignment:MainAxisAlignment.center,crossAxisAlignment:CrossAxisAlignment.start,children:[
            Text(list[i]['value'].toString(),style:const TextStyle(fontSize:20,fontWeight:FontWeight.w900,color:S.navy)),
            Text(list[i]['label'].toString(),style:const TextStyle(fontSize:10,color:S.muted))
          ])
        ])))),
      const SizedBox(height:18),Note(rlabel(r),r=='admin'?'Admin monitors everything, creates hierarchy and controls every portal page.':
        r=='principal'?'Principal monitors HODs only and sends information to HODs.':
        r=='hod'?'HOD monitors staff in the same department and assigns to staff.':
        r=='staff'?'Staff monitors students in the same department and assigns to students.':
        'Student sees only information assigned to this account.')
    ]));
  });
}

Map<String,dynamic> met(String l,Object v,IconData i)=>{'label':l,'value':v,'icon':i};

class Directory extends StatelessWidget{const Directory({super.key});
  @override Widget build(BuildContext c)=>RefreshIndicator(onRefresh:st.refresh,child:ListView(padding:const EdgeInsets.all(18),children:[
    Head(childLabel(st.me!['role'].toString()),st.me!['role']=='admin'?'All college users':'Only permitted users'),
    const SizedBox(height:14),if(st.directory.isEmpty)const EmptyBox(Icons.groups_outlined,'No users yet','Admin must create real accounts first.')
    else for(final p in st.directory)personCard(p)
  ]));
}

Widget personCard(dynamic p)=>Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(contentPadding:const EdgeInsets.all(13),
  leading:CircleAvatar(backgroundColor:const Color(0xFFEEF2FF),child:Icon(rIcon(p['role'].toString()),color:S.blue)),
  title:Text(p['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w900,color:S.navy)),
  subtitle:Text([rlabel(p['role'].toString()),if(p['department']!=null)p['department'].toString(),p['email'].toString()].join(' • '))));

class Inbox extends StatelessWidget{const Inbox({super.key});
  @override Widget build(BuildContext c)=>RefreshIndicator(onRefresh:st.refresh,child:ListView(padding:const EdgeInsets.all(18),children:[
    const Head('Inbox','Information and tasks sent to you'),const SizedBox(height:14),
    if(st.inbox.isEmpty)const EmptyBox(Icons.inbox_outlined,'Inbox is empty','Parent-role updates appear here in real time.')
    else for(final x in st.inbox)Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(
      leading:CircleAvatar(child:Icon(x['kind']=='task'?Icons.assignment_rounded:Icons.campaign_rounded)),
      title:Text(x['title'].toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
      subtitle:Text(x['body'].toString()+'\nFrom '+x['sender_name'].toString()+' • '+x['status'].toString().toUpperCase()),
      isThreeLine:true,onTap:()async{try{await st.mark((x['id'] as num).toInt(),'done');}catch(e){if(c.mounted)msg(c,e.toString(),true);}})
  ]));
}

class Assign extends StatefulWidget{const Assign({super.key});@override State<Assign> createState()=>_Assign();}
class _Assign extends State<Assign>{
  final title=TextEditingController(),body=TextEditingController();final Set<int> ids={};String kind='information';
  Future<void> go()async{
    if(ids.isEmpty||title.text.trim().isEmpty||body.text.trim().isEmpty){msg(context,'Select recipients and enter title/message',true);return;}
    try{await st.send(ids.toList(),title.text,body.text,kind);ids.clear();title.clear();body.clear();if(mounted){setState((){});msg(context,'Sent in real time',false);}}
    catch(e){if(mounted)msg(context,e.toString(),true);}
  }
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(18),children:[
    Head('Assign to '+childLabel(st.me!['role'].toString()),'Recipients are restricted by role and department'),const SizedBox(height:14),
    if(st.directory.isEmpty)const EmptyBox(Icons.person_add_alt_rounded,'No eligible recipients','Admin must create accounts first.')
    else ...[
      Card(child:Column(children:[for(final p in st.directory)CheckboxListTile(value:ids.contains((p['id'] as num).toInt()),
        title:Text(p['name'].toString()),subtitle:Text(rlabel(p['role'].toString())+(p['department']==null?'':' • '+p['department'].toString())),
        onChanged:(v)=>setState((){final id=(p['id'] as num).toInt();if(v==true)ids.add(id);else ids.remove(id);}))])),
      const SizedBox(height:10),DropdownButtonFormField<String>(value:kind,decoration:const InputDecoration(labelText:'Type'),
        items:const [DropdownMenuItem(value:'information',child:Text('Information / Notice')),DropdownMenuItem(value:'task',child:Text('Task / Assignment'))],
        onChanged:(v)=>setState(()=>kind=v??kind)),const SizedBox(height:10),field(title,'Title',Icons.title_rounded),const SizedBox(height:10),
      TextField(controller:body,maxLines:5,decoration:const InputDecoration(labelText:'Information / Instructions',alignLabelWithHint:true)),
      const SizedBox(height:14),FilledButton.icon(onPressed:go,icon:const Icon(Icons.send_rounded),label:Text('Send to '+ids.length.toString()+' recipient(s)'),
        style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)))
    ]
  ]);
}

class Departments extends StatelessWidget{const Departments({super.key});
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(18),children:[
    Head('Departments',st.departments.length.toString()+' configured',action:FilledButton.icon(onPressed:()=>deptDialog(c),icon:const Icon(Icons.add),label:const Text('Add'))),
    const SizedBox(height:14),if(st.departments.isEmpty)const EmptyBox(Icons.apartment_outlined,'No departments','Add real college departments first.')
    else for(final d in st.departments)Card(margin:const EdgeInsets.only(bottom:10),child:ListTile(
      leading:CircleAvatar(child:Text(d['code'].toString(),style:const TextStyle(fontSize:8,fontWeight:FontWeight.w900))),
      title:Text(d['name'].toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
      subtitle:Text('HOD: '+(d['hod_name']??'Not assigned').toString()+' • '+d['staff_count'].toString()+' staff • '+d['student_count'].toString()+' students')))
  ]);
}

Future<void> deptDialog(BuildContext c)async{
  final n=TextEditingController(),co=TextEditingController();
  await showDialog(context:c,builder:(x)=>AlertDialog(title:const Text('Add Department'),content:Column(mainAxisSize:MainAxisSize.min,children:[
    field(n,'Department Name',Icons.apartment_rounded),const SizedBox(height:10),field(co,'Code',Icons.tag_rounded)
  ]),actions:[TextButton(onPressed:()=>Navigator.pop(x),child:const Text('Cancel')),FilledButton(onPressed:()async{
    try{await st.addDept(n.text,co.text);if(x.mounted)Navigator.pop(x);}catch(e){if(x.mounted)msg(x,e.toString(),true);}
  },child:const Text('Create'))]));
}

class Users extends StatefulWidget{const Users({super.key});@override State<Users> createState()=>_Users();}
class _Users extends State<Users>{
  List<dynamic> users=[];bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void> load()async{setState(()=>loading=true);try{users=await st.allUsers();}catch(e){if(mounted)msg(context,e.toString(),true);}if(mounted)setState(()=>loading=false);}
  @override Widget build(BuildContext c)=>RefreshIndicator(onRefresh:load,child:ListView(padding:const EdgeInsets.all(18),children:[
    Head('Users','Create real Principal, HOD, Staff and Student accounts',action:FilledButton.icon(onPressed:()async{
      await Navigator.push(c,MaterialPageRoute(builder:(_)=>const AddUser()));await load();
    },icon:const Icon(Icons.person_add),label:const Text('Create'))),const SizedBox(height:14),
    if(loading)const Center(child:CircularProgressIndicator())else if(users.isEmpty)const EmptyBox(Icons.group_add_outlined,'No users','Create Principal first, then HOD, Staff and Students.')
    else for(final p in users)personCard(p)
  ]));
}

class AddUser extends StatefulWidget{const AddUser({super.key});@override State<AddUser> createState()=>_AddUser();}
class _AddUser extends State<AddUser>{
  final name=TextEditingController(),email=TextEditingController(),pass=TextEditingController(),year=TextEditingController(),sec=TextEditingController();
  String role='principal';int? dept;
  bool get need=>role=='hod'||role=='staff'||role=='student';
  Future<void> save()async{
    if(name.text.trim().isEmpty||email.text.trim().isEmpty||pass.text.length<8){msg(context,'Enter name, email and 8+ password',true);return;}
    if(need&&dept==null){msg(context,'Select department',true);return;}
    try{await st.addUser(name.text,email.text,pass.text,role,need?dept:null,year.text,sec.text);if(mounted)Navigator.pop(context);}
    catch(e){if(mounted)msg(context,e.toString(),true);}
  }
  @override Widget build(BuildContext c)=>Scaffold(appBar:AppBar(title:const Text('Create Real User')),body:ListView(padding:const EdgeInsets.all(18),children:[
    const Note('Verified records only','Create accounts using official college data. Permissions are enforced by backend.'),const SizedBox(height:14),
    field(name,'Full Name',Icons.person),const SizedBox(height:10),field(email,'Official Email',Icons.mail_outline),const SizedBox(height:10),
    TextField(controller:pass,obscureText:true,decoration:const InputDecoration(labelText:'Temporary Password (8+)',prefixIcon:Icon(Icons.lock_outline))),
    const SizedBox(height:10),DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Role'),
      items:const [DropdownMenuItem(value:'principal',child:Text('Principal')),DropdownMenuItem(value:'hod',child:Text('HOD')),
        DropdownMenuItem(value:'staff',child:Text('Staff')),DropdownMenuItem(value:'student',child:Text('Student'))],
      onChanged:(v)=>setState((){role=v??role;if(!need)dept=null;})),
    if(need)...[const SizedBox(height:10),DropdownButtonFormField<int>(value:dept,decoration:const InputDecoration(labelText:'Department'),
      items:st.departments.map((d)=>DropdownMenuItem<int>(value:(d['id'] as num).toInt(),child:Text(d['code'].toString()+' • '+d['name'].toString()))).toList(),
      onChanged:(v)=>setState(()=>dept=v))],
    if(role=='student')...[const SizedBox(height:10),field(year,'Year',Icons.calendar_view_month),const SizedBox(height:10),field(sec,'Section',Icons.view_column)],
    const SizedBox(height:16),FilledButton.icon(onPressed:save,icon:const Icon(Icons.person_add_alt_1),label:const Text('Create Account'),
      style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)))
  ]));
}

class PortalControl extends StatefulWidget{const PortalControl({super.key});@override State<PortalControl> createState()=>_PortalControl();}
class _PortalControl extends State<PortalControl>{
  String role='student';List<dynamic> items=[];bool loading=true;
  @override void initState(){super.initState();load();}
  Future<void> load()async{setState(()=>loading=true);try{items=await st.portalRole(role);}catch(e){if(mounted)msg(context,e.toString(),true);}if(mounted)setState(()=>loading=false);}
  void move(int i,int d){final to=i+d;if(to<0||to>=items.length)return;setState((){final x=items.removeAt(i);items.insert(to,x);});}
  @override Widget build(BuildContext c)=>ListView(padding:const EdgeInsets.all(18),children:[
    const Head('Portal Control','Admin controls page visibility, label and order for every role'),const SizedBox(height:14),
    DropdownButtonFormField<String>(value:role,decoration:const InputDecoration(labelText:'Configure Role'),
      items:const [DropdownMenuItem(value:'admin',child:Text('Admin')),DropdownMenuItem(value:'principal',child:Text('Principal')),
        DropdownMenuItem(value:'hod',child:Text('HOD')),DropdownMenuItem(value:'staff',child:Text('Staff')),DropdownMenuItem(value:'student',child:Text('Student'))],
      onChanged:(v)async{if(v==null)return;setState(()=>role=v);await load();}),const SizedBox(height:12),
    if(loading)const Center(child:CircularProgressIndicator())else ...[
      for(var i=0;i<items.length;i++)Card(margin:const EdgeInsets.only(bottom:9),child:Padding(padding:const EdgeInsets.all(8),child:Row(children:[
        Switch(value:items[i]['enabled']==true,onChanged:(v)=>setState(()=>items[i]['enabled']=v)),
        Expanded(child:TextFormField(initialValue:items[i]['label'].toString(),onChanged:(v)=>items[i]['label']=v,
          decoration:InputDecoration(labelText:items[i]['module'].toString(),filled:false))),
        Column(children:[IconButton(onPressed:i==0?null:()=>move(i,-1),icon:const Icon(Icons.keyboard_arrow_up)),
          IconButton(onPressed:i==items.length-1?null:()=>move(i,1),icon:const Icon(Icons.keyboard_arrow_down))])
      ]))),
      FilledButton.icon(onPressed:()async{try{await st.savePortal(role,items);if(mounted)msg(context,'Portal saved',false);}catch(e){if(mounted)msg(context,e.toString(),true);}},
        icon:const Icon(Icons.save),label:const Text('Save Portal Layout'),style:FilledButton.styleFrom(minimumSize:const Size.fromHeight(52)))
    ]
  ]);
}

class Activity extends StatelessWidget{const Activity({super.key});
  @override Widget build(BuildContext c)=>RefreshIndicator(onRefresh:st.refresh,child:ListView(padding:const EdgeInsets.all(18),children:[
    const Head('Live Activity','Admin audit trail'),const SizedBox(height:14),
    if(st.audit.isEmpty)const EmptyBox(Icons.history,'No activity yet','Real actions appear here.')
    else for(final a in st.audit)Card(margin:const EdgeInsets.only(bottom:9),child:ListTile(title:Text(a['action'].toString(),style:const TextStyle(fontWeight:FontWeight.w900)),
      subtitle:Text(a['actor'].toString()+' • '+a['detail'].toString()+'\n'+a['created_at'].toString()),isThreeLine:true))
  ]));
}

class Profile extends StatelessWidget{const Profile({super.key});
  @override Widget build(BuildContext c){final m=st.me!;return ListView(padding:const EdgeInsets.all(18),children:[
    const Head('My Profile','Role context from college'),const SizedBox(height:14),Card(child:Padding(padding:const EdgeInsets.all(18),child:Column(children:[
      CircleAvatar(radius:34,child:Icon(rIcon(m['role'].toString()),size:31)),const SizedBox(height:10),
      Text(m['name'].toString(),style:const TextStyle(fontSize:19,fontWeight:FontWeight.w900)),Text(m['email'].toString(),style:const TextStyle(color:S.muted)),
      const Divider(),row('Role',rlabel(m['role'].toString())),row('College',m['college_name'].toString()),row('College Code',m['college_code'].toString()),
      if(m['department']!=null)row('Department',m['department'].toString()),if((m['year']??'').toString().isNotEmpty)row('Year',m['year'].toString()),
      if((m['section']??'').toString().isNotEmpty)row('Section',m['section'].toString())
    ])))
  ]);}
}

class Head extends StatelessWidget{const Head(this.title,this.sub,{super.key,this.action});final String title,sub;final Widget? action;
  @override Widget build(BuildContext c)=>Row(crossAxisAlignment:CrossAxisAlignment.start,children:[
    Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontSize:21,fontWeight:FontWeight.w900,color:S.navy)),
      Text(sub,style:const TextStyle(fontSize:11,color:S.muted))])),if(action!=null)action!
  ]);
}
class Note extends StatelessWidget{const Note(this.title,this.text,{super.key});final String title,text;
  @override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(14),decoration:BoxDecoration(color:const Color(0xFFEEF2FF),borderRadius:BorderRadius.circular(17)),
    child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.info_outline,color:S.blue),const SizedBox(width:9),
      Expanded(child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),
        Text(text,style:const TextStyle(color:S.muted,fontSize:10.5,height:1.4))]))]));
}
class EmptyBox extends StatelessWidget{const EmptyBox(this.icon,this.title,this.text,{super.key});final IconData icon;final String title,text;
  @override Widget build(BuildContext c)=>Card(child:Padding(padding:const EdgeInsets.all(26),child:Column(children:[CircleAvatar(radius:28,child:Icon(icon)),
    const SizedBox(height:10),Text(title,style:const TextStyle(fontWeight:FontWeight.w900,fontSize:16)),const SizedBox(height:4),
    Text(text,textAlign:TextAlign.center,style:const TextStyle(color:S.muted,fontSize:11))])));
}
Widget field(TextEditingController c,String l,IconData i)=>TextField(controller:c,decoration:InputDecoration(labelText:l,prefixIcon:Icon(i)));
Widget row(String l,String v)=>Padding(padding:const EdgeInsets.symmetric(vertical:7),child:Row(children:[SizedBox(width:105,child:Text(l,style:const TextStyle(color:S.muted,fontSize:11))),
  Expanded(child:Text(v,textAlign:TextAlign.right,style:const TextStyle(fontWeight:FontWeight.w800)))]));
void msg(BuildContext c,String t,bool e)=>ScaffoldMessenger.of(c).showSnackBar(SnackBar(content:Text(t),backgroundColor:e?S.red:S.navy));