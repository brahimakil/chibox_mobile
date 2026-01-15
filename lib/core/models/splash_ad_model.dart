class SplashAdModel {
  final int id;
  final String title;
  final String mediaType; // 'image', 'video', 'lottie'
  final String mediaUrl;
  final String? thumbnailUrl;
  final String linkType; // 'product', 'category', 'url', 'none'
  final String? linkValue;
  final int skipDuration;
  final int totalDuration;

  SplashAdModel({
    required this.id,
    required this.title,
    required this.mediaType,
    required this.mediaUrl,
    this.thumbnailUrl,
    required this.linkType,
    this.linkValue,
    required this.skipDuration,
    required this.totalDuration,
  });

  factory SplashAdModel.fromJson(Map<String, dynamic> json) {
    return SplashAdModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      mediaType: json['media_type'] ?? 'image',
      mediaUrl: json['media_url'] ?? '',
      thumbnailUrl: json['thumbnail_url'],
      linkType: json['link_type'] ?? 'none',
      linkValue: json['link_value'],
      skipDuration: json['skip_duration'] ?? 5,
      totalDuration: json['total_duration'] ?? 10,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'media_type': mediaType,
      'media_url': mediaUrl,
      'thumbnail_url': thumbnailUrl,
      'link_type': linkType,
      'link_value': linkValue,
      'skip_duration': skipDuration,
      'total_duration': totalDuration,
    };
  }

  bool get isImage => mediaType == 'image';
  bool get isVideo => mediaType == 'video';
  bool get isLottie => mediaType == 'lottie';
  bool get hasLink => linkType != 'none' && linkValue != null && linkValue!.isNotEmpty;
}
