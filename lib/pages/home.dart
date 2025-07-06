import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/note.dart';
import 'note_edit.dart';
import 'package:intl/intl.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:screenshot/screenshot.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/widgets.dart' as pw;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        title: const Row(
          children: [
            Icon(Icons.edit_note_rounded, color: Colors.black),
            SizedBox(width: 8),
            Text('FeatherNote', style: TextStyle(color: Colors.black)),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('New Note'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NoteEditor()),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.lightBlue.shade100,
                foregroundColor: Colors.black,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
      body: ValueListenableBuilder(
        valueListenable: Hive.box<Note>('notes').listenable(),
        builder: (context, Box<Note> box, _) {
          if (box.isEmpty) {
            return const Center(child: Text('No notes yet'));
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Wrap(
              spacing: 16,
              runSpacing: 16,
              children: List.generate(box.length, (index) {
                final note = box.getAt(index)!;
                final doc = quill.Document.fromJson(jsonDecode(note.content));
                final quillController = quill.QuillController(
                  document: doc,
                  selection: const TextSelection.collapsed(offset: 0),
                )..readOnly = true;

                final screenshotController = ScreenshotController();
                final plainText = doc.toPlainText();

                return Screenshot(
                  controller: screenshotController,
                  child: GestureDetector(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => NoteEditor(note: note, index: index),
                      ),
                    ),
                    child: Container(
                      width: 250,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 8,
                            offset: Offset(2, 2),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                note.title,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              const SizedBox(height: 8),
                              SizedBox(
                                height: 80,
                                child: quill.QuillEditor.basic(
                                  controller: quillController,
                                  config: const quill.QuillEditorConfig(
                                    showCursor: false,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Updated ${DateFormat.yMMMd().format(note.timestamp)}',
                                style: const TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                          Positioned(
                            top: 0,
                            right: 0,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.share, color: Colors.blue),
                                  tooltip: 'Share Note',
                                  onPressed: () => _showShareOptions(
                                    context,
                                    note.title,
                                    plainText,
                                    screenshotController,
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.delete, color: Colors.red),
                                  tooltip: 'Delete Note',
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (_) => AlertDialog(
                                        title: const Text('Delete this note?'),
                                        content: const Text('This action cannot be undone.'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                                backgroundColor: Colors.red),
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      await box.deleteAt(index);
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }),
            ),
          );
        },
      ),
    );
  }

  void _showShareOptions(
    BuildContext context,
    String title,
    String content,
    ScreenshotController screenshotController,
  ) {
    if (title.trim().isEmpty) title = 'Untitled Note';

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
              Share.share('$title\n\n$content');
            },
          ),
          ListTile(
            leading: const Icon(Icons.picture_as_pdf),
            title: const Text('Share as PDF'),
            onTap: () {
              Navigator.pop(context);
              _shareAsPdf(title, content);
            },
          ),
          ListTile(
            leading: const Icon(Icons.image),
            title: const Text('Share as Image'),
            onTap: () {
              Navigator.pop(context);
              _shareAsImage(screenshotController);
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

  Future<void> _shareAsImage(ScreenshotController controller) async {
    final image = await controller.capture();
    if (image == null) return;

    final dir = await getTemporaryDirectory();
    final path = '${dir.path}/note_image.png';
    final file = File(path);
    await file.writeAsBytes(image);

    await Share.shareXFiles([XFile(path)], text: 'Shared Note Image');
  }
}
