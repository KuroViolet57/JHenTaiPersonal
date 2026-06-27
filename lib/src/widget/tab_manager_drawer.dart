import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:jhentai/src/config/ui_config.dart';
import 'package:jhentai/src/model/gallery_image.dart';
import 'package:jhentai/src/model/gallery_url.dart';
import 'package:jhentai/src/model/tab_record.dart';
import 'package:jhentai/src/pages/details/details_page_logic.dart';
import 'package:jhentai/src/routes/routes.dart';
import 'package:jhentai/src/service/tab_manager_service.dart';
import 'package:jhentai/src/utils/route_util.dart';
import 'package:jhentai/src/utils/search_util.dart';
import 'package:jhentai/src/widget/eh_image.dart';

/// A right-side drawer that lists all persisted browser-style tabs.
/// Tap a tab to open its underlying route (cold-load if it was suspended);
/// dismiss a tab to remove it from the list.
class TabManagerDrawer extends StatelessWidget {
  const TabManagerDrawer({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          _buildHeader(context),
          const Divider(height: 1),
          Expanded(child: _buildList(context)),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return GetBuilder<TabManagerService>(
      init: tabManagerService,
      id: TabManagerService.tabListId,
      builder: (_) {
        final n = tabManagerService.length;
        return Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              const Icon(Icons.tab),
              const SizedBox(width: 12),
              Text('tabs'.tr, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(width: 8),
              Text('($n)', style: TextStyle(color: UIConfig.galleryCardTextColor(context))),
              const Spacer(),
              IconButton(
                tooltip: 'clearAllTabs'.tr,
                icon: const Icon(Icons.delete_outline),
                onPressed: tabManagerService.isEmpty
                    ? null
                    : () async {
                        final ok = await Get.dialog<bool>(
                          AlertDialog(
                            content: Text('clearAllTabs'.tr),
                            actions: [
                              TextButton(onPressed: () => Get.back(result: false), child: Text('cancel'.tr)),
                              TextButton(onPressed: () => Get.back(result: true), child: Text('confirm'.tr)),
                            ],
                          ),
                        );
                        if (ok == true) tabManagerService.clearAll();
                      },
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(BuildContext context) {
    return GetBuilder<TabManagerService>(
      init: tabManagerService,
      id: TabManagerService.tabListId,
      builder: (_) {
        if (tabManagerService.isEmpty) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.tab_unselected, size: 48, color: UIConfig.galleryCardTextColor(context)),
                const SizedBox(height: 8),
                Text('noTabs'.tr, style: TextStyle(color: UIConfig.galleryCardTextColor(context))),
              ],
            ),
          );
        }

        final tabs = tabManagerService.tabs;
        return ListView.builder(
          padding: const EdgeInsets.symmetric(vertical: 4),
          itemCount: tabs.length,
          itemBuilder: (context, index) => _TabTile(record: tabs[index]),
        );
      },
    );
  }
}

class _TabTile extends StatelessWidget {
  final TabRecord record;

  const _TabTile({Key? key, required this.record}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final warm = tabManagerService.isWarm(record);
    return Dismissible(
      key: ValueKey(record.id),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 24),
        color: Colors.red.withOpacity(0.15),
        child: const Icon(Icons.close, color: Colors.red),
      ),
      onDismissed: (_) => tabManagerService.remove(record.id),
      child: ListTile(
        dense: true,
        leading: _buildLeading(context),
        title: Text(
          record.title.isEmpty ? (record.kind == TabKind.search ? 'search'.tr : 'gallery'.tr) : record.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontWeight: warm ? FontWeight.w500 : FontWeight.w400, fontSize: 13),
        ),
        subtitle: record.subtitle == null
            ? Text(
                record.kind == TabKind.search ? 'search'.tr : (warm ? '' : '· suspended'),
                style: TextStyle(fontSize: 11, color: UIConfig.galleryCardTextColor(context)),
              )
            : Text(record.subtitle!, style: const TextStyle(fontSize: 11), maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          iconSize: 18,
          icon: const Icon(Icons.close),
          onPressed: () => tabManagerService.remove(record.id),
        ),
        onTap: () => _activate(context),
      ),
    );
  }

  Widget _buildLeading(BuildContext context) {
    if (record.kind == TabKind.gallery && record.coverUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: EHImage(
          galleryImage: GalleryImage(url: record.coverUrl!),
          containerColor: UIConfig.galleryCardBackGroundColor(context),
          containerHeight: 56,
          containerWidth: 40,
          fit: BoxFit.cover,
        ),
      );
    }

    final IconData ic = record.kind == TabKind.search ? Icons.search : Icons.menu_book_outlined;
    return Container(
      width: 40,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: UIConfig.galleryCardBackGroundColor(context),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(ic, size: 22),
    );
  }

  void _activate(BuildContext context) {
    tabManagerService.touch(record);

    // close the drawer first
    Navigator.of(context).maybePop();

    if (record.kind == TabKind.gallery) {
      if (record.galleryUrl == null) return;
      final url = GalleryUrl.tryParse(record.galleryUrl!);
      if (url == null) return;
      toRoute(
        Routes.details,
        arguments: DetailsPageArgument(galleryUrl: url),
        preventDuplicates: false,
      );
      return;
    }

    if (record.kind == TabKind.search) {
      final cfg = record.buildSearchConfig();
      if (cfg != null) {
        newSearch(rewriteSearchConfig: cfg, forceNewRoute: true);
      } else {
        newSearch(keyword: record.searchKeyword ?? '', forceNewRoute: true);
      }
    }
  }
}
