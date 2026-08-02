import 'dart:io';

import 'package:get/get.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

class PdfToolsController extends GetxController {
  final ImagePicker _picker = ImagePicker();

  final RxList<File> images = <File>[].obs;
  final RxBool isWorking = false.obs;
  final RxString lastPdfPath = ''.obs;

  Future<void> pickImages() async {
    try {
      final picked = await _picker.pickMultiImage();
      if (picked.isEmpty) return;
      images.assignAll(picked.map((x) => File(x.path)));
      lastPdfPath.value = '';
    } catch (e) {
      Get.snackbar('PDF Tools', 'Could not pick images: $e');
    }
  }

  void removeImage(int index) {
    if (index < 0 || index >= images.length) return;
    images.removeAt(index);
  }

  void clearImages() {
    images.clear();
    lastPdfPath.value = '';
  }

  Future<File?> buildPdf() async {
    if (images.isEmpty) {
      Get.snackbar('PDF Tools', 'Pick at least one image');
      return null;
    }

    isWorking.value = true;
    try {
      final doc = pw.Document();

      for (final file in images) {
        final bytes = await file.readAsBytes();
        final image = pw.MemoryImage(bytes);
        doc.addPage(
          pw.Page(
            build: (context) => pw.Center(
              child: pw.Image(image, fit: pw.BoxFit.contain),
            ),
          ),
        );
      }

      final docs = await getApplicationDocumentsDirectory();
      final outDir = Directory(p.join(docs.path, 'pdf_tools'));
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }

      final outFile = File(
        p.join(
          outDir.path,
          'toolmate_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
      await outFile.writeAsBytes(await doc.save(), flush: true);
      lastPdfPath.value = outFile.path;
      Get.snackbar('PDF Tools', 'PDF created');
      return outFile;
    } catch (e) {
      Get.snackbar('PDF Tools', 'PDF build failed: $e');
      return null;
    } finally {
      isWorking.value = false;
    }
  }

  Future<void> buildAndShare() async {
    final file = await buildPdf();
    if (file == null) return;
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path)],
        text: 'PDF from Toolmate',
      ),
    );
  }
}
