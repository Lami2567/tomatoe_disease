class Scan {
  final int id;
  final String disease;
  final double confidence;
  final String image;
  final String imageUrl;
  final String status;
  final String recommendation;
  final String createdAt;

  Scan({
    required this.id,
    required this.disease,
    required this.confidence,
    required this.image,
    required this.imageUrl,
    required this.status,
    required this.recommendation,
    required this.createdAt,
  });

  factory Scan.fromJson(Map<String, dynamic> json) {
    return Scan(
      id: json['id'] ?? 0,
      disease: json['disease'] ?? json['class'] ?? 'Unknown',
      confidence: (json['confidence'] as num?)?.toDouble() ?? 0,
      image: json['image'] ?? '',
      imageUrl: json['image_url'] ?? json['image'] ?? '',
      status: json['status'] ?? ((json['disease'] ?? '').toString().toLowerCase().contains('healthy') ? 'healthy' : 'infected'),
      recommendation: json['recommendation'] ?? '',
      createdAt: json['created_at'] ?? '',
    );
  }

  bool get isHealthy => status == 'healthy' || disease.toLowerCase().contains('healthy');

  String get readableDisease => disease.replaceAll('_', ' ');

  String get confidenceLabel => '${(confidence * 100).toStringAsFixed(1)}%';
}
