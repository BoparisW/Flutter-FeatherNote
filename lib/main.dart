import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'models/note.dart';
import 'pages/home.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. เริ่มต้น Hive
  await Hive.initFlutter();
  
  // 2. ล้างข้อมูลทั้งหมดจาก Disk (ทุก Box)
  await Hive.deleteBoxFromDisk('notes'); // ล้างเฉพาะ Box 'notes'
  // หรือถ้าต้องการล้างทั้งหมด:
  // await Hive.deleteFromDisk();
  
  // 3. ลงทะเบียน Adapter
  Hive.registerAdapter(NoteAdapter());
  
  // 4. เปิด Box ใหม่
  await Hive.openBox<Note>('notes');

  runApp(const NoteApp());
}

class NoteApp extends StatelessWidget {
  const NoteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'FeatherNote',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFFF1F7FE),
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('th'),
      ],
      home: const HomeScreen(),
    );
  }
}