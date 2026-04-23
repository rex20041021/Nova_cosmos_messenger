class WikiInfo {
  final String title;
  final String? description;
  final String? extract;
  final String? url;
  final String? thumbnail;

  WikiInfo({
    required this.title,
    this.description,
    this.extract,
    this.url,
    this.thumbnail,
  });

  factory WikiInfo.fromJson(Map<String, dynamic> json) {
    return WikiInfo(
      title: json['title'] as String? ?? '',
      description: json['description'] as String?,
      extract: json['extract'] as String?,
      url: json['url'] as String?,
      thumbnail: json['thumbnail'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'extract': extract,
      'url': url,
      'thumbnail': thumbnail,
    };
  }

  factory WikiInfo.fromMap(Map<String, dynamic> map) {
    return WikiInfo(
      title: map['title'] as String,
      description: map['description'] as String?,
      extract: map['extract'] as String?,
      url: map['url'] as String?,
      thumbnail: map['thumbnail'] as String?,
    );
  }
}
