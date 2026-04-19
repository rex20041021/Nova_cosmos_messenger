class ApodData {
  final String title;
  final String date;
  final String explanation;
  final String url;
  final String? hdurl;
  final String mediaType;
  final String? copyright;

  ApodData({
    required this.title,
    required this.date,
    required this.explanation,
    required this.url,
    required this.mediaType,
    this.hdurl,
    this.copyright,
  });

  factory ApodData.fromJson(Map<String, dynamic> json) {
    return ApodData(
      title: json['title'] as String? ?? '',
      date: json['date'] as String? ?? '',
      explanation: json['explanation'] as String? ?? '',
      url: json['url'] as String? ?? '',
      hdurl: json['hdurl'] as String?,
      mediaType: json['media_type'] as String? ?? 'image',
      copyright: json['copyright'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'date': date,
      'title': title,
      'explanation': explanation,
      'url': url,
      'hdurl': hdurl,
      'media_type': mediaType,
      'copyright': copyright,
    };
  }

  factory ApodData.fromMap(Map<String, dynamic> map) {
    return ApodData(
      date: map['date'] as String,
      title: map['title'] as String,
      explanation: map['explanation'] as String,
      url: map['url'] as String,
      hdurl: map['hdurl'] as String?,
      mediaType: map['media_type'] as String,
      copyright: map['copyright'] as String?,
    );
  }

  bool get isVideo => mediaType == 'video';
}
