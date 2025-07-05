import 'package:hive/hive.dart';

part 'note.g.dart';

@HiveType(typeId: 0)
class Note extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String content; // 🔁 เก็บ Delta JSON (rich text) แทนข้อความล้วน

  @HiveField(2)
  DateTime timestamp;

  Note({
    required this.title,
    required this.content,
    required this.timestamp,
  });
}
