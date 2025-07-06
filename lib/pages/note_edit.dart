import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

import '../models/note.dart';

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
  final ScreenshotController _screenshotController = ScreenshotController();

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

  void _showShareOptions() {
    final plainText = quillController.document.toPlainText();
    final title = titleController.text.isEmpty ? 'Untitled Note' : titleController.text;

    showModalBottomSheet(
      context: context,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.text_fields),
            title: const Text('Share as Text'),
            onTap: () {
              Navigator.pop(context);
              Share.share('$title\n\n$plainText');
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Share as PDF'),
            onTap: () {
              Navigator.pop(context);
              _shareAsPdf(title, plainText);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Share as Image'),
            onTap: () {
              Navigator.pop(context);
              _shareAsImage();
            },
          ),
        ],
      ),
    );
  }

  Future<void> _shareAsPdf(String title, String content) async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (pw.Context context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 16),
            pw.Text(content),
          ],
        ),
      ),
    );

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$title.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles([XFile(file.path)], text: 'Shared Note: $title');
  }

  Future<void> _shareAsImage() async {
    final image = await _screenshotController.capture();
    if (image == null) return;

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/note_image.png');
    await file.writeAsBytes(image);

    await Share.shareXFiles([XFile(file.path)], text: 'Shared Note Image');
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
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Note',
            onPressed: _showShareOptions,
          ),
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
              child: Screenshot(
                controller: _screenshotController,
                child: quill.QuillEditor.basic(
                  controller: quillController,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
