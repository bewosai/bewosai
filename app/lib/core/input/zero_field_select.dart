import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// Tapping into a number box that still holds 0 (or 0.00) selects that 0, so
/// the first digit typed replaces it instead of producing "05". Installed once
/// from main() and applies to every numeric TextField/TextFormField in the app,
/// so individual screens don't each need their own handling.
class ZeroFieldSelect {
  ZeroFieldSelect._();

  static FocusManager? _attachedTo;

  static void install() {
    final manager = FocusManager.instance;
    if (identical(manager, _attachedTo)) return;
    _attachedTo = manager;
    manager.addListener(_onFocusChanged);
  }

  static void _onFocusChanged() {
    final context = FocusManager.instance.primaryFocus?.context;
    if (context == null) return;
    final editable = context.findAncestorStateOfType<EditableTextState>();
    if (editable == null) return;
    if (editable.widget.keyboardType.index != TextInputType.number.index) return;

    // After the frame: a tap places the caret first, then focuses the field,
    // so selecting any earlier would be undone by the tap's own caret.
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (!editable.mounted) return;
      final controller = editable.widget.controller;
      final text = controller.text.trim();
      if (text.isEmpty || double.tryParse(text.replaceAll(',', '')) != 0) return;
      controller.selection = TextSelection(baseOffset: 0, extentOffset: controller.text.length);
    });
    SchedulerBinding.instance.ensureVisualUpdate();
  }
}
