import 'package:flutter/foundation.dart';
import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:image_picker/image_picker.dart';

class LeafValidationResult {
  const LeafValidationResult({
    required this.isLeaf,
    required this.confidence,
    required this.labels,
  });

  final bool isLeaf;
  final double confidence;
  final List<String> labels;
}

class LeafValidationService {
  static const _minLeafConfidence = 0.55;

  Future<LeafValidationResult> validateTomatoLeaf(XFile image) async {
    if (kIsWeb) {
      return const LeafValidationResult(
          isLeaf: true, confidence: 1, labels: ['web upload']);
    }

    final labeler =
        ImageLabeler(options: ImageLabelerOptions(confidenceThreshold: 0.45));
    try {
      final labels =
          await labeler.processImage(InputImage.fromFilePath(image.path));
      var bestLeafConfidence = 0.0;
      var bestFruitConfidence = 0.0;
      final labelNames = <String>[];

      for (final label in labels) {
        final text = label.label.toLowerCase();
        labelNames.add(
            '${label.label} ${(label.confidence * 100).toStringAsFixed(0)}%');

        if (_isLeafLabel(text) && label.confidence > bestLeafConfidence) {
          bestLeafConfidence = label.confidence;
        }
        if (_isFruitOrFoodLabel(text) &&
            label.confidence > bestFruitConfidence) {
          bestFruitConfidence = label.confidence;
        }
      }

      final isLeaf = bestLeafConfidence >= _minLeafConfidence &&
          bestLeafConfidence >= bestFruitConfidence;
      return LeafValidationResult(
        isLeaf: isLeaf,
        confidence: bestLeafConfidence,
        labels: labelNames,
      );
    } finally {
      await labeler.close();
    }
  }

  bool _isLeafLabel(String text) {
    return text.contains('leaf') ||
        text.contains('plant') ||
        text.contains('vegetation') ||
        text.contains('flora') ||
        text.contains('tree') ||
        text.contains('herb');
  }

  bool _isFruitOrFoodLabel(String text) {
    return text.contains('fruit') ||
        text.contains('vegetable') ||
        text.contains('food') ||
        text.contains('tomato') ||
        text.contains('produce');
  }
}
