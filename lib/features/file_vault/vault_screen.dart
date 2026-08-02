import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

import '../../core/app_ui.dart';
import '../../core/style.dart';
import 'vault_controller.dart';

class VaultScreen extends GetView<VaultController> {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppUi.gradientScaffold(
      context: context,
      appBar: AppBar(
        title: Text('File Vault', style: openSansBold.copyWith(fontSize: 18)),
        actions: [
          Obx(() {
            if (!controller.isUnlocked.value) return const SizedBox.shrink();
            return IconButton(
              icon: const Icon(Icons.lock_outline_rounded),
              tooltip: 'Lock',
              onPressed: controller.lock,
            );
          }),
        ],
      ),
      floatingActionButton: Obx(() {
        if (!controller.isUnlocked.value) return const SizedBox.shrink();
        return FloatingActionButton(
          onPressed: () => _showImportSheet(context),
          child: const Icon(Icons.add_rounded),
        );
      }),
      body: SafeArea(
        child: Obx(() {
          if (controller.isLoading.value) {
            return const Center(child: CircularProgressIndicator());
          }
          if (!controller.isUnlocked.value) {
            return _LockGate(controller: controller);
          }
          return _FileList(controller: controller);
        }),
      ),
    );
  }

  void _showImportSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Import from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                controller.importFromGallery();
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                controller.importFromCamera();
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LockGate extends StatefulWidget {
  final VaultController controller;

  const _LockGate({required this.controller});

  @override
  State<_LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<_LockGate> {
  final _pinCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  @override
  void dispose() {
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final pin = _pinCtrl.text;
    if (!widget.controller.hasPin.value) {
      if (pin != _confirmCtrl.text) {
        Get.snackbar('Vault', 'PINs do not match');
        return;
      }
      await widget.controller.setPin(pin);
    } else {
      await widget.controller.unlock(pin);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Obx(() {
      final settingUp = !widget.controller.hasPin.value;
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    gradient: AppUi.accentGradient(AppUi.brandPurple),
                    borderRadius: BorderRadius.circular(AppUi.radiusMd),
                    boxShadow: AppUi.softGlow(AppUi.brandPurple),
                  ),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 36),
                ),
                const SizedBox(height: 20),
                Text(
                  settingUp ? 'Set vault PIN' : 'Enter vault PIN',
                  style: openSansBold.copyWith(fontSize: 20),
                ),
                const SizedBox(height: 8),
                Text(
                  settingUp
                      ? 'Choose a PIN to protect your private files.'
                      : 'Unlock to view files stored in your vault.',
                  textAlign: TextAlign.center,
                  style: openSansRegular.copyWith(
                    color: scheme.onSurface.withValues(alpha: 0.65),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _pinCtrl,
                  obscureText: true,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'PIN',
                    border: OutlineInputBorder(),
                  ),
                  onSubmitted: (_) => settingUp ? null : _submit(),
                ),
                if (settingUp) ...[
                  const SizedBox(height: 12),
                  TextField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                ],
                if (widget.controller.errorMessage.value.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    widget.controller.errorMessage.value,
                    style: openSansMedium.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: _submit,
                    child: Text(settingUp ? 'Create PIN' : 'Unlock'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    });
  }
}

class _FileList extends StatelessWidget {
  final VaultController controller;

  const _FileList({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.files.isEmpty) {
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.folder_open_rounded,
                size: 56,
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.35),
              ),
              const SizedBox(height: 12),
              Text(
                'Vault is empty',
                style: openSansSemiBold.copyWith(fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap + to import images',
                style: openSansRegular.copyWith(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.55),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        );
      }

      return ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 88),
        itemCount: controller.files.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final file = controller.files[index];
          final name = file.path.split(Platform.pathSeparator).last;
          final size = controller.formatSize(file.lengthSync());
          final isImage = _isImage(name);

          return Material(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(AppUi.radiusMd),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(AppUi.radiusSm),
                child: SizedBox(
                  width: 48,
                  height: 48,
                  child: isImage
                      ? Image.file(file, fit: BoxFit.cover)
                      : const ColoredBox(
                          color: Color(0xFFE0E0E0),
                          child: Icon(Icons.insert_drive_file_outlined),
                        ),
                ),
              ),
              title: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: openSansMedium,
              ),
              subtitle: Text(size, style: openSansRegular.copyWith(fontSize: 12)),
              trailing: IconButton(
                icon: Icon(Icons.delete_outline, color: Theme.of(context).colorScheme.error),
                onPressed: () => _confirmDelete(context, file),
              ),
            ),
          );
        },
      );
    });
  }

  bool _isImage(String name) {
    final lower = name.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.gif') ||
        lower.endsWith('.heic');
  }

  void _confirmDelete(BuildContext context, File file) {
    Get.dialog(
      AlertDialog(
        title: const Text('Delete file?'),
        content: const Text('This removes the file from your vault permanently.'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              Get.back();
              controller.deleteFile(file);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
