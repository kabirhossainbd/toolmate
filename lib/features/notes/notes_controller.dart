import 'package:get/get.dart';
import 'package:hive/hive.dart';
import 'notes_model.dart';

class NotesController extends GetxController {
  static const _boxName = 'notes';

  late Box _box;

  final notes = <NotesModel>[].obs;
  final filtered = <NotesModel>[].obs;
  final searchQuery = ''.obs;
  final isReady = false.obs;

  @override
  void onInit() {
    super.onInit();
    _initBox();
  }

  Future<void> _initBox() async {
    _box = Hive.isBoxOpen(_boxName)
        ? Hive.box(_boxName)
        : await Hive.openBox(_boxName);
    _reload();
    isReady.value = true;
  }

  void _reload() {
    final list = _box.values
        .whereType<Map>()
        .map((e) => NotesModel.fromMap(Map<dynamic, dynamic>.from(e)))
        .toList();
    list.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    notes.assignAll(list);
    applySearch(searchQuery.value);
  }

  void applySearch(String query) {
    searchQuery.value = query;
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      filtered.assignAll(notes);
      return;
    }
    filtered.assignAll(
      notes.where(
        (n) =>
            n.title.toLowerCase().contains(q) ||
            n.content.toLowerCase().contains(q),
      ),
    );
  }

  Future<void> addNote({
    required String title,
    required String content,
  }) async {
    final note = NotesModel(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.trim(),
      content: content.trim(),
      updatedAt: DateTime.now(),
    );
    await _box.put(note.id, note.toMap());
    _reload();
  }

  Future<void> updateNote(NotesModel note) async {
    note.updatedAt = DateTime.now();
    await _box.put(note.id, note.toMap());
    _reload();
  }

  Future<void> deleteNote(String id) async {
    await _box.delete(id);
    _reload();
  }

  Future<void> togglePin(NotesModel note) async {
    note.isPinned = !note.isPinned;
    note.updatedAt = DateTime.now();
    await _box.put(note.id, note.toMap());
    _reload();
  }
}
