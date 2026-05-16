import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../app_theme.dart';
import '../services/api_service.dart';

class ScanScreen extends StatefulWidget {
  final VoidCallback? onScanComplete;

  const ScanScreen({super.key, this.onScanComplete});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final ImagePicker _picker = ImagePicker();
  final ApiService _api = ApiService();

  Uint8List? _imageBytes;
  bool _isLoading = false;
  ScanUploadResult? _result;
  String? _error;

  Future<void> _pickImage(ImageSource source) async {
    try {
      final image = await _picker.pickImage(source: source, maxWidth: 1280, maxHeight: 1280, imageQuality: 92);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      setState(() {
        _imageBytes = bytes;
        _result = null;
        _error = null;
      });
      await _uploadImage(image);
    } catch (error) {
      setState(() => _error = 'Could not open image source: $error');
    }
  }

  Future<void> _uploadImage(XFile image) async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final result = await _api.uploadScan(image);
      setState(() => _result = result);
      widget.onScanComplete?.call();
    } catch (error) {
      setState(() => _error = 'Scan failed: $error');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _reset() {
    setState(() {
      _imageBytes = null;
      _result = null;
      _error = null;
    });
  }

  void _showImageSourceSheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Choose leaf image', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              _SourceTile(
                icon: Icons.photo_camera_outlined,
                title: 'Camera',
                subtitle: 'Capture a fresh leaf photo',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.camera);
                },
              ),
              const SizedBox(height: 8),
              _SourceTile(
                icon: Icons.photo_library_outlined,
                title: 'Gallery',
                subtitle: 'Upload a saved tomato leaf image',
                onTap: () {
                  Navigator.pop(context);
                  _pickImage(ImageSource.gallery);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan leaf')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: AppShell(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 240),
              child: _result != null
                  ? _ResultView(
                      key: const ValueKey('result'),
                      result: _result!,
                      imageBytes: _imageBytes,
                      onScanAgain: _showImageSourceSheet,
                      onReset: _reset,
                    )
                  : _ScanEntryView(
                      key: const ValueKey('entry'),
                      isLoading: _isLoading,
                      error: _error,
                      imageBytes: _imageBytes,
                      onPick: _showImageSourceSheet,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ScanEntryView extends StatelessWidget {
  final bool isLoading;
  final String? error;
  final Uint8List? imageBytes;
  final VoidCallback onPick;

  const _ScanEntryView({
    super.key,
    required this.isLoading,
    required this.error,
    required this.imageBytes,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          constraints: const BoxConstraints(minHeight: 280),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: AgroColors.sky, borderRadius: BorderRadius.circular(8)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (imageBytes != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(imageBytes!, height: 220, width: double.infinity, fit: BoxFit.cover),
                )
              else
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.eco_outlined, size: 44, color: AgroColors.field),
                ),
              const SizedBox(height: 20),
              Text('Scan a tomato leaf', style: Theme.of(context).textTheme.headlineMedium),
              const SizedBox(height: 8),
              Text(
                'Use a clear image with one leaf centered. The backend will preprocess it to 224 x 224 for TFLite inference.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 22),
              ElevatedButton.icon(
                onPressed: isLoading ? null : onPick,
                icon: isLoading
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.add_a_photo_outlined),
                label: Text(isLoading ? 'Analyzing leaf' : 'Choose image'),
              ),
            ],
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AgroColors.danger),
                  const SizedBox(width: 10),
                  Expanded(child: Text(error!, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AgroColors.danger))),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  final ScanUploadResult result;
  final Uint8List? imageBytes;
  final VoidCallback onScanAgain;
  final VoidCallback onReset;

  const _ResultView({
    super.key,
    required this.result,
    required this.imageBytes,
    required this.onScanAgain,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final scan = result.scan;
    final statusColor = scan.isHealthy ? AgroColors.field : AgroColors.danger;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (imageBytes != null)
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.memory(imageBytes!, height: 260, fit: BoxFit.cover),
          ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
                  child: Text(
                    scan.isHealthy ? 'Healthy leaf' : 'Disease detected',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(color: statusColor),
                  ),
                ),
                const SizedBox(height: 14),
                Text(scan.readableDisease, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  minHeight: 8,
                  value: result.confidence.clamp(0, 1),
                  borderRadius: BorderRadius.circular(8),
                  color: statusColor,
                  backgroundColor: statusColor.withValues(alpha: 0.12),
                ),
                const SizedBox(height: 8),
                Text('${scan.confidenceLabel} model confidence', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(color: AgroColors.sand, borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.lightbulb_outline, color: AgroColors.clay),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recommendation', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 6),
                      Text(result.recommendation, style: Theme.of(context).textTheme.bodyMedium),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        ElevatedButton.icon(onPressed: onScanAgain, icon: const Icon(Icons.photo_camera_outlined), label: const Text('Scan another leaf')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onReset, child: const Text('Back to scan start')),
      ],
    );
  }
}

class _SourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _SourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 6),
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(color: AgroColors.sky, borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: AgroColors.field),
      ),
      title: Text(title, style: Theme.of(context).textTheme.titleMedium),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded),
    );
  }
}
