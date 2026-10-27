import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable Multi-Select Controller.
///
/// Manages selected IDs, anchor indices for desktop Shift+Click range selection,
/// Ctrl+Click toggles, and Android long-press activation.
class MultiSelectController extends ChangeNotifier {
  final Set<int> _selectedIds = <int>{};
  bool _isSelectionMode = false;
  int? _anchorIndex;

  Set<int> get selectedIds => Set.unmodifiable(_selectedIds);
  int get selectedCount => _selectedIds.length;
  bool get isSelectionMode => _isSelectionMode;
  bool get hasSelection => _selectedIds.isNotEmpty;
  bool get isEmpty => _selectedIds.isEmpty;

  bool isSelected(int id) => _selectedIds.contains(id);

  void startSelection(int initialId, {int? index}) {
    _isSelectionMode = true;
    _selectedIds.clear();
    _selectedIds.add(initialId);
    _anchorIndex = index;
    notifyListeners();
  }

  void toggleSelection(int id, {int? index}) {
    if (_selectedIds.contains(id)) {
      _selectedIds.remove(id);
      if (_selectedIds.isEmpty) {
        // Automatically exit selection mode if no items remain
        _isSelectionMode = false;
        _anchorIndex = null;
      }
    } else {
      _selectedIds.add(id);
      _isSelectionMode = true;
      _anchorIndex = index;
    }
    notifyListeners();
  }

  /// Handles desktop Shift+Click range selection over a visible list of songs.
  void selectRange(List<int> visibleIds, int targetIndex) {
    if (visibleIds.isEmpty) return;
    _isSelectionMode = true;

    final startIndex = (_anchorIndex ?? 0).clamp(0, visibleIds.length - 1);
    final endIndex = targetIndex.clamp(0, visibleIds.length - 1);

    final from = startIndex < endIndex ? startIndex : endIndex;
    final to = startIndex < endIndex ? endIndex : startIndex;

    for (int i = from; i <= to; i++) {
      _selectedIds.add(visibleIds[i]);
    }

    notifyListeners();
  }

  /// Selects all visible songs currently matching search / active filters.
  void selectAll(List<int> visibleIds) {
    if (visibleIds.isEmpty) return;
    _isSelectionMode = true;
    _selectedIds.addAll(visibleIds);
    notifyListeners();
  }

  /// Deselects all songs currently in selection.
  void deselectAll() {
    _selectedIds.clear();
    _isSelectionMode = false;
    _anchorIndex = null;
    notifyListeners();
  }

  /// Exits selection mode and clears all selected items.
  void clear() {
    _selectedIds.clear();
    _isSelectionMode = false;
    _anchorIndex = null;
    notifyListeners();
  }

  /// Handles tap or click on an item with platform modifier keys check.
  ///
  /// Returns `true` if the event was handled as a selection, `false` if it should trigger default play/open.
  bool handleItemTap({
    required int id,
    required int index,
    required List<int> visibleIds,
  }) {
    final isControlPressed =
        HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShiftPressed = HardwareKeyboard.instance.isShiftPressed;

    if (isShiftPressed) {
      selectRange(visibleIds, index);
      return true;
    }

    if (isControlPressed) {
      toggleSelection(id, index: index);
      return true;
    }

    if (_isSelectionMode) {
      toggleSelection(id, index: index);
      return true;
    }

    return false;
  }
}
