import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/component_catalog.dart';
import '../../models/component_definition.dart';
import '../../models/component_instance.dart';
import '../../models/enums.dart';
import '../../state/project_controller.dart';
import 'component_painter.dart';

/// لوحة مكتبة المكونات: تصنيفات + بحث + سحب-وإفلات إلى اللوحة
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
    var items = componentCatalog.where((d) {
      if (_showFavoritesOnly && !widget.favoriteTypeIds.contains(d.id)) return false;
      if (_category != null && d.category != _category) return false;
      if (_query.isNotEmpty) {
        final q = _query.toLowerCase();
        return d.nameAr.contains(_query) || d.nameEn.toLowerCase().contains(q);
      }
      return true;
    }).toList();

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
          SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10),
              children: [
                _chip('الكل', null),
                _chip('⭐ المفضلة', null, isFav: true),
                for (final c in ComponentCategory.values) _chip('${c.emoji} ${c.nameAr}', c),
              ],
            ),
          ),
          if (widget.recentTypeIds.isNotEmpty && _query.isEmpty && _category == null && !_showFavoritesOnly)
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
            child: items.isEmpty
                ? const Center(child: Text('لا توجد نتائج', style: TextStyle(color: AppColors.textSecondary)))
                : GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                    ),
                    itemCount: items.length,
                    itemBuilder: (context, i) => _libraryTile(items[i]),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, ComponentCategory? cat, {bool isFav = false}) {
    final selected = isFav ? _showFavoritesOnly : (_category == cat && !_showFavoritesOnly);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: ChoiceChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.bold : FontWeight.normal,
            color: selected ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
        selected: selected,
        onSelected: (_) {
          setState(() {
            if (isFav) {
              _showFavoritesOnly = !_showFavoritesOnly;
            } else {
              _category = cat;
              _showFavoritesOnly = false;
            }
          });
        },
        selectedColor: AppColors.primary.withOpacity(0.22),
        backgroundColor: AppColors.surfaceAlt,
        side: BorderSide(color: selected ? AppColors.primary : Colors.white24),
        checkmarkColor: AppColors.primary,
      ),
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
                top: 0,
                left: 0,
                child: GestureDetector(
                  onTap: () => widget.onToggleFavorite(def.id),
                  child: Icon(isFav ? Icons.star : Icons.star_border, size: 16, color: AppColors.warning),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 2),
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
