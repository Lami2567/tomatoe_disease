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
  static const _minPlantFoodComboConfidence = 0.65;

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
      var bestPlantConfidence = 0.0;
      var bestFoodOrVegetableConfidence = 0.0;
      final labelNames = <String>[];

      for (final label in labels) {
        final text = label.label.toLowerCase();
        labelNames.add(
            '${label.label} ${(label.confidence * 100).toStringAsFixed(0)}%');

        if (_isLeafLabel(text) && label.confidence > bestLeafConfidence) {
          bestLeafConfidence = label.confidence;
        }
        if (_isPlantLabel(text) && label.confidence > bestPlantConfidence) {
          bestPlantConfidence = label.confidence;
        }
        if (_isFoodOrVegetableLabel(text) &&
            label.confidence > bestFoodOrVegetableConfidence) {
          bestFoodOrVegetableConfidence = label.confidence;
        }
      }

      final isLeaf = bestLeafConfidence >= _minLeafConfidence ||
          (bestPlantConfidence >= _minLeafConfidence &&
              bestFoodOrVegetableConfidence >= _minPlantFoodComboConfidence);
      return LeafValidationResult(
        isLeaf: isLeaf,
        confidence: bestLeafConfidence > bestPlantConfidence
            ? bestLeafConfidence
            : bestPlantConfidence,
        labels: labelNames,
      );
    } finally {
      await labeler.close();
    }
  }

  bool _isLeafLabel(String text) {
    return text.contains('leaf') ||
        text.contains('leaves') ||
        text.contains('plant') ||
        text.contains('vegetation') ||
        text.contains('flora') ||
        text.contains('tree') ||
        text.contains('herb');
  }

  bool _isPlantLabel(String text) {
    return text.contains('plant') ||
        text.contains('leaf') ||
        text.contains('leaves') ||
        text.contains('vegetation') ||
        text.contains('flora') ||
        text.contains('herb');
  }

  bool _isFoodOrVegetableLabel(String text) {
    return text.contains('vegetable') ||
        text.contains('food') ||
        text.contains('tomato') ||
        text.contains('produce');
  }
}
