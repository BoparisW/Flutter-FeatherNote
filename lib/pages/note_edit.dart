import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import '../models/note.dart';
import 'dart:convert';

class NoteEditor extends StatefulWidget {
  final Note? note;
  final int? index;
  const NoteEditor({super.key, this.note, this.index});

  @override
  State<NoteEditor> createState() => _NoteEditorState();
}

class _NoteEditorState extends State<NoteEditor> {
  final titleController = TextEditingController();
  late quill.QuillController quillController;

  @override
  void initState() {
    super.initState();

    if (widget.note != null) {
      titleController.text = widget.note!.title;
      final doc = quill.Document.fromJson(jsonDecode(widget.note!.content));
      quillController = quill.QuillController(
        document: doc, 
        selection: const TextSelection.collapsed(offset: 0),
      )..readOnly = false;
    } else {
      quillController = quill.QuillController.basic()..readOnly = false;
    }
  }

  void saveNote() async {
    if (titleController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title')),
      );
      return;
    }

    final box = Hive.box<Note>('notes');
    final note = Note(
      title: titleController.text,
      content: jsonEncode(quillController.document.toDelta().toJson()),
      timestamp: DateTime.now(),
    );

    if (widget.index == null) {
      await box.add(note);
    } else {
      await box.putAt(widget.index!, note);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  void deleteNote() async {
    if (widget.index == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Note'),
        content: const Text('Are you sure you want to delete this note?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      final box = Hive.box<Note>('notes');
      await box.deleteAt(widget.index!);
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: titleController,
          decoration: InputDecoration(
            hintText: widget.note == null ? 'New Note' : 'Edit Note',
            border: InputBorder.none,
            hintStyle: TextStyle(
              color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            ),
          ),
          style: TextStyle(
            color: Theme.of(context).appBarTheme.titleTextStyle?.color,
            fontSize: 20,
          ),
        ),
        actions: [
          if (widget.note != null)
            IconButton(
              icon: const Icon(Icons.delete, color: Colors.red),
              onPressed: deleteNote,
              tooltip: 'Delete Note',
            ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: saveNote,
            tooltip: 'Save Note',
          ),
        ],
      ),
      body: Column(
        children: [
          quill.QuillSimpleToolbar(
            controller: quillController,
            config: const quill.QuillSimpleToolbarConfig(),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: quill.QuillEditor.basic(
                controller: quillController,
              ),
            ),
          ),
        ],
      ),
    );
  }
}