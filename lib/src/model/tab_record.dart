import 'dart:convert';

import 'package:jhentai/src/model/search_config.dart';

/// A persisted browser-style tab. Each tab is a saved (route, args) pair
/// plus presentation metadata. Tabs are NOT eagerly loaded - tapping a tab
/// navigates to its route, which spins up controllers normally. The 'loaded'
/// flag tracks whether the tab has been activated since app start; only the
/// most-recently-touched tabs are kept "warm".
enum TabKind {
  gallery,
  search,
}

class TabRecord {
  final String id;
  final TabKind kind;
  String title;
  final String? subtitle;
  final String? coverUrl;
  int lastAccessedMs;

  /// gallery tab payload
  final String? galleryUrl;
  final int? gid;
  final String? token;

  /// search tab payload
  final String? searchKeyword;
  final Map<String, dynamic>? searchConfigJson;

  TabRecord({
    required this.id,
    required this.kind,
    required this.title,
    this.subtitle,
    this.coverUrl,
    required this.lastAccessedMs,
    this.galleryUrl,
    this.gid,
    this.token,
    this.searchKeyword,
    this.searchConfigJson,
  });

  factory TabRecord.fromJson(Map<String, dynamic> json) {
    return TabRecord(
      id: json['id'] as String,
      kind: TabKind.values.firstWhere((e) => e.name == json['kind'], orElse: () => TabKind.gallery),
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      coverUrl: json['coverUrl'] as String?,
      lastAccessedMs: json['lastAccessedMs'] as int? ?? 0,
      galleryUrl: json['galleryUrl'] as String?,
      gid: json['gid'] as int?,
      token: json['token'] as String?,
      searchKeyword: json['searchKeyword'] as String?,
      searchConfigJson: (json['searchConfigJson'] as Map?)?.cast<String, dynamic>(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'title': title,
        'subtitle': subtitle,
        'coverUrl': coverUrl,
        'lastAccessedMs': lastAccessedMs,
        if (galleryUrl != null) 'galleryUrl': galleryUrl,
        if (gid != null) 'gid': gid,
        if (token != null) 'token': token,
        if (searchKeyword != null) 'searchKeyword': searchKeyword,
        if (searchConfigJson != null) 'searchConfigJson': searchConfigJson,
      };

  String encode() => jsonEncode(toJson());

  factory TabRecord.decode(String s) => TabRecord.fromJson(jsonDecode(s) as Map<String, dynamic>);

  SearchConfig? buildSearchConfig() {
    if (searchConfigJson != null) {
      return SearchConfig.fromJson(searchConfigJson!);
    }
    if (searchKeyword != null) {
      return SearchConfig(keyword: searchKeyword);
    }
    return null;
  }
}
