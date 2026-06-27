import 'dart:convert';

import 'package:get/get.dart';
import 'package:jhentai/src/enum/config_enum.dart';
import 'package:jhentai/src/model/gallery.dart';
import 'package:jhentai/src/model/search_config.dart';
import 'package:jhentai/src/model/tab_record.dart';
import 'package:jhentai/src/service/jh_service.dart';

TabManagerService tabManagerService = TabManagerService();

/// Browser-style persistent tabs.
///
/// Stores a list of [TabRecord] entries. Tabs are NOT controllers - they
/// are lightweight (route, args, title) bundles. Activation = navigation,
/// which creates fresh controllers via the existing GetX routing.
///
/// "Lazy load" requirement: at most [warmLimit] tabs are considered "warm"
/// (the most recently accessed). Older tabs stay persisted but their entry
/// reports [TabRecord.lastAccessedMs] far in the past, signalling to UI that
/// a tap will re-fetch their content from scratch.
class TabManagerService extends GetxController with JHLifeCircleBeanWithConfigStorage implements JHLifeCircleBean {
  static const int warmLimit = 20;
  static const int hardLimit = 200;

  final List<TabRecord> _records = <TabRecord>[];

  List<TabRecord> get tabs => List.unmodifiable(_records);

  int get length => _records.length;

  bool get isEmpty => _records.isEmpty;

  static const String tabListId = 'tabManagerTabListId';

  @override
  ConfigEnum get configEnum => ConfigEnum.tabManagerRecords;

  @override
  void applyBeanConfig(String configString) {
    final dynamic decoded = jsonDecode(configString);
    if (decoded is! List) return;

    _records.clear();
    for (final entry in decoded) {
      if (entry is Map<String, dynamic>) {
        try {
          _records.add(TabRecord.fromJson(entry));
        } catch (_) {}
      }
    }
    _sortByRecency();
  }

  @override
  String toConfigString() {
    return jsonEncode(_records.map((t) => t.toJson()).toList());
  }

  @override
  Future<void> doInitBean() async {}

  @override
  void doAfterBeanReady() {}

  TabRecord? findById(String id) {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  TabRecord? findGalleryTab(String galleryUrl) {
    for (final r in _records) {
      if (r.kind == TabKind.gallery && r.galleryUrl == galleryUrl) return r;
    }
    return null;
  }

  /// Add or refresh a gallery tab. Returns the record (existing or new).
  TabRecord addGalleryTab(Gallery gallery) {
    final existing = findGalleryTab(gallery.galleryUrl.url);
    if (existing != null) {
      existing.title = gallery.title;
      _touch(existing);
      _persist();
      return existing;
    }

    final record = TabRecord(
      id: 'gal_${gallery.gid}_${DateTime.now().microsecondsSinceEpoch}',
      kind: TabKind.gallery,
      title: gallery.title,
      subtitle: gallery.uploader,
      coverUrl: gallery.cover.url,
      lastAccessedMs: DateTime.now().millisecondsSinceEpoch,
      galleryUrl: gallery.galleryUrl.url,
      gid: gallery.gid,
      token: gallery.token,
    );
    _records.insert(0, record);
    _enforceHardLimit();
    _persist();
    return record;
  }

  TabRecord addSearchTab({String? keyword, SearchConfig? config, String? displayTitle}) {
    final title = displayTitle ?? keyword ?? config?.keyword ?? 'search'.tr;
    final record = TabRecord(
      id: 'sch_${DateTime.now().microsecondsSinceEpoch}',
      kind: TabKind.search,
      title: title,
      lastAccessedMs: DateTime.now().millisecondsSinceEpoch,
      searchKeyword: keyword,
      searchConfigJson: config?.toJson(),
    );
    _records.insert(0, record);
    _enforceHardLimit();
    _persist();
    return record;
  }

  void touch(TabRecord record) {
    _touch(record);
    _persist();
  }

  void remove(String id) {
    _records.removeWhere((r) => r.id == id);
    _persist();
  }

  void clearAll() {
    _records.clear();
    _persist();
  }

  /// Marks the given record as just-accessed and resorts the list.
  void _touch(TabRecord record) {
    record.lastAccessedMs = DateTime.now().millisecondsSinceEpoch;
    _sortByRecency();
  }

  void _sortByRecency() {
    _records.sort((a, b) => b.lastAccessedMs.compareTo(a.lastAccessedMs));
  }

  void _enforceHardLimit() {
    if (_records.length > hardLimit) {
      _records.removeRange(hardLimit, _records.length);
    }
  }

  void _persist() {
    update([tabListId]);
    saveBeanConfig();
  }

  /// True iff this tab is within the warm window of [warmLimit] most-recent tabs.
  bool isWarm(TabRecord record) {
    final idx = _records.indexWhere((r) => r.id == record.id);
    return idx >= 0 && idx < warmLimit;
  }
}
