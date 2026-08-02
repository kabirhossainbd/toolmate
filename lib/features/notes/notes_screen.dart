import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:intl/intl.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'notes_controller.dart';
import 'notes_model.dart';

class NotesScreen extends GetView<NotesController> {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Get.back(),
        ),
        title: Text('Notes', style: openSansBold.copyWith(fontSize: 17)),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context),
        backgroundColor: AppUi.brandTeal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New note'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              onChanged: controller.applySearch,
              style: const TextStyle(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search notes…',
                hintStyle: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: scheme.onSurface.withValues(alpha: 0.4),
                ),
                filled: true,
                fillColor: scheme.onSurface.withValues(alpha: 0.05),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          Expanded(
            child: Obx(() {
              if (!controller.isReady.value) {
                return const Center(child: CircularProgressIndicator());
              }
              final items = controller.filtered;
              if (items.isEmpty) {
                return _EmptyNotes(
                  onCreate: () => _openEditor(context),
                  searching: controller.searchQuery.value.isNotEmpty,
                );
              }
              return ListView.separated(
                physics: const ClampingScrollPhysics(),
                cacheExtent: 250,
                addAutomaticKeepAlives: false,
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                itemCount: items.length,
                separatorBuilder: (_, _) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final note = items[i];
                  return _NoteCard(
                    note: note,
                    onTap: () => _openEditor(context, note: note),
                    onPin: () => controller.togglePin(note),
                    onDelete: () => _confirmDelete(context, note),
                  );
                },
              );
            }),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, NotesModel note) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete note?'),
        content: Text('“${note.title}” will be removed permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) await controller.deleteNote(note.id);
  }

  Future<void> _openEditor(BuildContext context, {NotesModel? note}) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => _NoteEditorPage(
          note: note,
          onSave: (title, content) async {
            if (note == null) {
              await controller.addNote(title: title, content: content);
            } else {
              note.title = title;
              note.content = content;
              await controller.updateNote(note);
            }
          },
        ),
      ),
    );
  }
}

class _EmptyNotes extends StatelessWidget {
  final VoidCallback onCreate;
  final bool searching;

  const _EmptyNotes({required this.onCreate, required this.searching});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              searching ? Icons.search_off_rounded : Icons.note_add_outlined,
              size: 48,
              color: scheme.onSurface.withValues(alpha: 0.28),
            ),
            const SizedBox(height: 12),
            Text(
              searching ? 'No matching notes' : 'No notes yet',
              style: openSansSemiBold.copyWith(fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              searching
                  ? 'Try a different search.'
                  : 'Tap New note to write something.',
              textAlign: TextAlign.center,
              style: openSansRegular.copyWith(
                fontSize: 13,
                color: scheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
            if (!searching) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create note'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NoteCard extends StatelessWidget {
  final NotesModel note;
  final VoidCallback onTap;
  final VoidCallback onPin;
  final VoidCallback onDelete;

  const _NoteCard({
    required this.note,
    required this.onTap,
    required this.onPin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: isDark ? const Color(0xFF161B22) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: note.isPinned
              ? AppUi.brandTeal.withValues(alpha: 0.45)
              : scheme.outline.withValues(alpha: 0.08),
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.isPinned) ...[
                          const Icon(Icons.push_pin_rounded,
                              size: 14, color: AppUi.brandTeal),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            note.title.isEmpty ? 'Untitled' : note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: openSansSemiBold.copyWith(fontSize: 14.5),
                          ),
                        ),
                      ],
                    ),
                    if (note.content.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        note.content,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: openSansRegular.copyWith(
                          fontSize: 12.5,
                          height: 1.35,
                          color: scheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      DateFormat('MMM d, y · h:mm a').format(note.updatedAt),
                      style: openSansRegular.copyWith(
                        fontSize: 11,
                        color: scheme.onSurface.withValues(alpha: 0.4),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: note.isPinned ? 'Unpin' : 'Pin',
                icon: Icon(
                  note.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                  size: 18,
                  color: note.isPinned ? AppUi.brandTeal : null,
                ),
                onPressed: onPin,
              ),
              IconButton(
                tooltip: 'Delete',
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteEditorPage extends StatefulWidget {
  final NotesModel? note;
  final Future<void> Function(String title, String content) onSave;

  const _NoteEditorPage({required this.note, required this.onSave});

  @override
  State<_NoteEditorPage> createState() => _NoteEditorPageState();
}

class _NoteEditorPageState extends State<_NoteEditorPage> {
  late final TextEditingController _title;
  late final TextEditingController _content;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.note?.title ?? '');
    _content = TextEditingController(text: widget.note?.content ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _title.text.trim();
    final content = _content.text.trim();
    if (title.isEmpty && content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Write something first')),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.onSave(title.isEmpty ? 'Untitled' : title, content);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.note != null;
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          isEdit ? 'Edit note' : 'New note',
          style: openSansBold.copyWith(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(
                    'Save',
                    style: openSansSemiBold.copyWith(color: AppUi.brandTeal),
                  ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _title,
            style: openSansBold.copyWith(fontSize: 20),
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Title',
              border: InputBorder.none,
            ),
          ),
          const Divider(height: 1),
          const SizedBox(height: 8),
          TextField(
            controller: _content,
            style: openSansRegular.copyWith(fontSize: 15, height: 1.45),
            maxLines: null,
            minLines: 12,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Start writing…',
              border: InputBorder.none,
            ),
          ),
        ],
      ),
    );
  }
}
