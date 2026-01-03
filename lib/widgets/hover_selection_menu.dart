import 'package:flutter/material.dart';

import '../config/app_theme.dart';

class HoverMenuOption {
  final Widget Function(bool isHover) builder;

  const HoverMenuOption({required this.builder});
}

class HoverSelectionMenu extends StatelessWidget {
  static const double itemExtent = 48.0;
  static const double menuWidth = 64.0;

  static double totalHeightForCount(int count) {
    // Padding (12) + each row height + small vertical margins per row
    return 12 + (itemExtent + 4) * count;
  }

  final List<HoverMenuOption> options;
  final int initialHover;
  final ValueNotifier<int> hoverNotifier;
  final ValueChanged<int> onHover;
  final ValueChanged<int> onSelect;
  final VoidCallback onDismiss;
  final GlobalKey? menuKey;

  const HoverSelectionMenu({
    super.key,
    required this.options,
    required this.initialHover,
    required this.hoverNotifier,
    required this.onHover,
    required this.onSelect,
    required this.onDismiss,
    required this.menuKey,
  });

  void _setHover(int next) {
    if (hoverNotifier.value != next) {
      hoverNotifier.value = next;
      onHover(next);
    }
  }

  void _handlePointer(Offset localPosition) {
    final idx = (localPosition.dy / itemExtent).floor();
    final clamped = idx.clamp(0, options.length - 1);
    _setHover(clamped);
  }

  void _handleSelect() {
    final idx = hoverNotifier.value;
    if (idx >= 0 && idx < options.length) {
      onSelect(idx);
    } else {
      onDismiss();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Seed the hover state so the initial option is highlighted immediately.
    if (hoverNotifier.value != initialHover) {
      hoverNotifier.value = initialHover;
    }

    return Material(
      color: Colors.transparent,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) {
          _handlePointer(d.localPosition);
          _handleSelect();
        },
        onPanStart: (d) => _handlePointer(d.localPosition),
        onPanUpdate: (d) => _handlePointer(d.localPosition),
        onPanEnd: (_) => _handleSelect(),
        child: MouseRegion(
          key: menuKey,
          opaque: false,
          onHover: (event) => _handlePointer(event.localPosition),
          onExit: (_) => _setHover(-1),
          child: ValueListenableBuilder<int>(
            valueListenable: hoverNotifier,
            builder: (context, hoverIndex, _) {
              return Container(
                width: menuWidth,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                decoration: ShapeDecoration(
                  color: AppTheme.darkGrey,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: const BorderSide(color: Colors.white24),
                  ),
                  shadows: const [BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(options.length, (index) {
                    final isHover = index == hoverIndex;
                    return Container(
                      height: itemExtent,
                      width: double.infinity,
                      margin: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: isHover ? Colors.white10 : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: options[index].builder(isHover),
                    );
                  }),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
