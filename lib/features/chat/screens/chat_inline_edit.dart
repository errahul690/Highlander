part of 'chat_screen.dart';

extension _ChatInlineEditing on _ChatScreenState {
  bool get _canConfirmInlineEdit =>
      _editingMessage != null &&
      !_savingEdit &&
      _editDeadline != null &&
      DateTime.now().isBefore(_editDeadline!);

  bool get _canSaveInlineEdit =>
      _canConfirmInlineEdit && _text.text.trim().isNotEmpty;

  void _beginInlineEdit(Map<String, dynamic> message) {
    if (!_canChangeMessage(message, edit: true) || _savingEdit) return;
    if (_searching) _closeChatSearch();
    _update(() {
      if (_editingMessage == null) {
        _draftBeforeEdit = _text.value;
        _attachmentBeforeEdit = _attachmentDraft;
        _replyBeforeEdit = _replyTo;
      }
      _editingMessage = Map<String, dynamic>.from(message);
      final window =
          (_chatOptions['editWindowSeconds'] as num?)?.toInt() ?? 900;
      _editDeadline = DateTime.parse('${message['createdAt']}')
          .add(Duration(seconds: window))
          .subtract(_serverTimeOffset);
      _attachmentDraft = null;
      _replyTo = null;
      _editError = null;
      _selectedIds.clear();
      final content = '${message['content'] ?? ''}';
      _text.value = TextEditingValue(
        text: content,
        selection: TextSelection.collapsed(offset: content.length),
      );
    });
    _textFocus.requestFocus();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealEditedMessage());
  }

  void _revealEditedMessage() {
    if (!mounted || _editingMessage == null) return;
    final anchor =
        _messageAnchors['${_editingMessage!['_id']}']?.currentContext;
    if (anchor != null && anchor.mounted) {
      unawaited(
        Scrollable.ensureVisible(
          anchor,
          alignment: .5,
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
        ),
      );
    }
  }

  void _cancelInlineEdit() {
    if (_savingEdit || _editingMessage == null) return;
    _update(() {
      _editingMessage = null;
      _editDeadline = null;
      _editError = null;
      _text.value = _draftBeforeEdit ?? TextEditingValue.empty;
      _attachmentDraft = _attachmentBeforeEdit;
      _replyTo = _replyBeforeEdit;
      _draftBeforeEdit = null;
      _attachmentBeforeEdit = null;
      _replyBeforeEdit = null;
    });
  }

  Future<void> _saveInlineEdit() async {
    if (!_canSaveInlineEdit) return;
    final original = _editingMessage!;
    final content = _text.text.trim();
    // Confirming unchanged text closes edit mode without creating a new edit.
    if (content == original['content']) {
      _cancelInlineEdit();
      return;
    }
    _update(() {
      _savingEdit = true;
      _editError = null;
    });
    try {
      final result = await _messageAction(
        'edit',
        ids: ['${original['_id']}'],
        extra: {'content': content, 'expectedContent': original['content']},
      );
      if (result is! Map ||
          result['action'] != 'edit' ||
          result['message'] is! Map) {
        throw Exception(
          'Message editing is currently unavailable. Please try again.',
        );
      }
      if (!mounted) return;
      final saved = result['message'] as Map;
      if ('${saved['_id']}' != '${original['_id']}' ||
          saved['content'] != content) {
        throw Exception('Your edit could not be saved. Please try again.');
      }
      _applyMessageChange({'action': 'edit', 'message': result['message']});
      _update(() => _savingEdit = false);
      _cancelInlineEdit();
    } catch (error) {
      if (mounted) _update(() => _editError = userFacingError(error));
    } finally {
      if (mounted) _update(() => _savingEdit = false);
    }
  }

  PreferredSizeWidget _editAppBar() => AppBar(
    toolbarHeight: const ClubHeader(title: '').preferredSize.height,
    backgroundColor: authRed,
    foregroundColor: Colors.white,
    elevation: 0,
    centerTitle: false,
    leading: IconButton(
      tooltip: 'Cancel edit',
      onPressed: _savingEdit ? null : _cancelInlineEdit,
      icon: const Icon(Icons.arrow_back),
    ),
    title: const Text('Edit message'),
  );

  Widget _inlineEditNotice() {
    final available =
        _editingMessage != null &&
        _editDeadline != null &&
        DateTime.now().isBefore(_editDeadline!);
    final error =
        _editError ??
        (!available
            ? 'The 15-minute edit window has ended. Cancel to return to your draft.'
            : null);
    return error == null
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Text(
              error,
              style: const TextStyle(color: authRed, fontSize: 13),
            ),
          );
  }
}
