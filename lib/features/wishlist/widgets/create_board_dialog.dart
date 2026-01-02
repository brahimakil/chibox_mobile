import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/wishlist_service.dart';

class CreateBoardDialog extends StatefulWidget {
  final String? initialName;
  final int? boardId;

  const CreateBoardDialog({
    super.key,
    this.initialName,
    this.boardId,
  });

  @override
  State<CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends State<CreateBoardDialog> {
  late TextEditingController _controller;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;

    setState(() => _isLoading = true);

    final service = context.read<WishlistService>();
    bool success;

    if (widget.boardId != null) {
      success = await service.updateBoard(widget.boardId!, name);
    } else {
      success = await service.createBoard(name);
    }

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to save collection')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.boardId != null;
    
    return AlertDialog(
      title: Text(isEditing ? 'Rename Collection' : 'New Collection'),
      content: TextField(
        controller: _controller,
        decoration: const InputDecoration(
          hintText: 'Collection Name (e.g. Summer Outfits)',
          border: OutlineInputBorder(),
        ),
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isLoading ? null : _save,
          child: _isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(isEditing ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}
