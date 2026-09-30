import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/component_catalog.dart';
import '../../models/component_definition.dart';
import '../../models/component_instance.dart';
import '../../models/enums.dart';
import '../../state/project_controller.dart';
import 'component_painter.dart';

/// لوحة مكتبة المكونات الاحترافية: بحث علوي + قائمة تصنيفات جانبية (يمين،
/// مطابقة للهوية البصرية الاحترافية المرجعية) + شبكة مكونات مع بطاقات
/// أنيقة مقسّمة بعناوين تصنيف واضحة عند عرض "الكل".
class ComponentLibraryPanel extends StatefulWidget {
  final ProjectController controller;
  final List<String> recentTypeIds;
  final Set<String> favoriteTypeIds;
  final ValueChanged<String> onToggleFavorite;
  final ValueChanged<String> onQuickAdd;

  const ComponentLibraryPanel({
    super.key,
    required this.controller,
    required this.recentTypeIds,
    required this.favoriteTypeIds,
    required this.onToggleFavorite,
    required this.onQuickAdd,
  });

  @override
  State<ComponentLibraryPanel> createState() => _ComponentLibraryPanelState();
}

class _ComponentLibraryPanelState extends State<ComponentLibraryPanel> {
  String _query = '';
  ComponentCategory? _category;
  bool _showFavoritesOnly = false;

  @override
  Widget build(BuildContext context) {
    final searching = _query.isNotEmpty;
    var items = componentCatalog.where((d) {
      if (_showFavoritesOnly && !widget.favoriteTypeIds.contains(d.id)) return false;
      if (!searching && _category != null && d.category != _category) return false;
      if (searching) {
        final q = _query.toLowerCase();
        return d.nameAr.contains(_query) || d.nameEn.toLowerCase().contains(q);
      }
      return true;
    }).toList();

    // عند عدم البحث وعدم اختيار تصنيف محدد نعرض كل شيء مُجمَّعاً بعناوين
    // تصنيف (كما في المكتبات الاحترافية المرجعية) بدل شبكة واحدة مختلطة.
    final groupByCategory = !searching && _category == null && !_showFavoritesOnly;

    return Container(
      color: AppColors.surface,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
            child: TextField(
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                hintText: 'ابحث عن مكون...',
                prefixIcon: const Icon(Icons.search, size: 20),
                isDense: true,
                filled: true,
                fillColor: AppColors.surfaceAlt,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              ),
            ),
          ),
          if (widget.recentTypeIds.isNotEmpty && !searching && _category == null && !_showFavoritesOnly)
            SizedBox(
              height: 86,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                children: [
                  for (final id in widget.recentTypeIds)
                    if (componentCatalogById.containsKey(id)) _miniTile(componentCatalogById[id]!),
                ],
              ),
            ),
          const Divider(height: 1),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: items.isEmpty
                      ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: AppColors.textSecondary)))
                      : (groupByCategory ? _groupedList() : _flatGrid(items)),
                ),
                _categoryRail(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// عمود التصنيفات الجانبي (على اليمين — يطابق تخطيط المكتبات الاحترافية
  /// المرجعية ويناسب واجهتنا العربية RTL).
  Widget _categoryRail() {
    return Container(
      width: 92,
      decoration: const BoxDecoration(
        color: AppColors.surfaceAlt,
        border: Border(right: BorderSide(color: Colors.white12)),
      ),
      child: ListView(
        padding: const EdgeInsets.symmetric(vertical: 6),
        children: [
          _railItem('الكل', null),
          _railItem('⭐ المفضلة', null, isFav: true),
          for (final c in ComponentCategory.values) _railItem('${c.emoji}\n${c.nameAr}', c),
        ],
      ),
    );
  }

  Widget _railItem(String label, ComponentCategory? cat, {bool isFav = false}) {
    final selected = isFav ? _showFavoritesOnly : (!_showFavoritesOnly && _category == cat);
    return InkWell(
      onTap: () => setState(() {
        if (isFav) {
          _showFavoritesOnly = !_showFavoritesOnly;
          _category = null;
        } else {
          _category = cat;
          _showFavoritesOnly = false;
        }
        _query = '';
      }),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 6),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withOpacity(0.16) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
          border: selected ? Border.all(color: AppColors.primary.withOpacity(0.6)) : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.3,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.primary : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _flatGrid(List<ComponentDefinition> items) {
    return GridView.builder(
      padding: const EdgeInsets.all(10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) => _libraryTile(items[i]),
    );
  }

  /// عرض كل المكتبة دفعة واحدة مقسّمة بعناوين تصنيف واضحة (تمرير واحد
  /// متواصل بدل تبديل تبويبات) — يطابق أسلوب "Select Comps" المرجعي.
  Widget _groupedList() {
    final byCat = <ComponentCategory, List<ComponentDefinition>>{};
    for (final d in componentCatalog) {
      byCat.putIfAbsent(d.category, () => []).add(d);
    }
    final orderedCats = ComponentCategory.values.where((c) => byCat.containsKey(c)).toList();

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: orderedCats.length,
      itemBuilder: (context, i) {
        final cat = orderedCats[i];
        final defs = byCat[cat]!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
              child: Row(
                children: [
                  Container(width: 4, height: 16, decoration: BoxDecoration(color: categoryColor(cat), borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text('${cat.emoji} ${cat.nameAr}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5)),
                  const SizedBox(width: 6),
                  Text('(${defs.length})', style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                ],
              ),
            ),
            GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: defs.length,
              itemBuilder: (context, j) => _libraryTile(defs[j]),
            ),
          ],
        );
      },
    );
  }

  Widget _miniTile(ComponentDefinition def) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: _DraggableComponentThumb(def: def, size: 60, onQuickAdd: widget.onQuickAdd),
    );
  }

  Widget _libraryTile(ComponentDefinition def) {
    final isFav = widget.favoriteTypeIds.contains(def.id);
    return Column(
      children: [
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(child: _DraggableComponentThumb(def: def, onQuickAdd: widget.onQuickAdd)),
              Positioned(
                top: 2,
                left: 2,
                child: GestureDetector(
                  onTap: () => widget.onToggleFavorite(def.id),
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(color: Colors.black.withOpacity(0.35), borderRadius: BorderRadius.circular(6)),
                    child: Icon(isFav ? Icons.star : Icons.star_border, size: 14, color: AppColors.warning),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 3),
        Text(def.nameAr, style: const TextStyle(fontSize: 10.5), textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
  }
}

class _DraggableComponentThumb extends StatelessWidget {
  final ComponentDefinition def;
  final double? size;
  final ValueChanged<String> onQuickAdd;

  const _DraggableComponentThumb({required this.def, this.size, required this.onQuickAdd});

  @override
  Widget build(BuildContext context) {
    final thumbSize = size ?? 64.0;
    final preview = SizedBox(
      width: thumbSize,
      height: thumbSize,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: categoryColor(def.category).withOpacity(0.5)),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: CustomPaint(
            painter: ComponentPainter(
              def: def,
              comp: _dummyInstance(def),
              realistic: true,
              selected: false,
              animPhase: 0,
              showTerminalLabels: false,
            ),
          ),
        ),
      ),
    );

    return Draggable<String>(
      data: def.id,
      feedback: Opacity(opacity: 0.85, child: preview),
      childWhenDragging: Opacity(opacity: 0.3, child: preview),
      onDragEnd: (_) {},
      child: GestureDetector(
        // ضغطة واحدة تكفي لإضافة المكون مباشرة لمنتصف اللوحة (أسهل على
        // الهاتف من الاعتماد فقط على Drag & Drop) — والسحب يبقى متاحاً لمن يفضّله.
        onTap: () => onQuickAdd(def.id),
        child: preview,
      ),
    );
  }
}

// نسخة وهمية فقط لعرض شكل المكون داخل المكتبة (لا تُضاف للمشروع)
ComponentInstance _dummyInstance(ComponentDefinition def) => ComponentInstance(
      id: 'preview',
      typeId: def.id,
      position: Offset.zero,
      properties: Map<String, double>.from(def.defaultProperties),
    );
