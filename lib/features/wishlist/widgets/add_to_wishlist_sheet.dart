import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/services/wishlist_service.dart';
import '../../../core/models/board_model.dart';
import 'create_board_dialog.dart';

class AddToWishlistSheet extends StatefulWidget {
  final int productId;

  const AddToWishlistSheet({
    super.key,
    required this.productId,
  });

  @override
  State<AddToWishlistSheet> createState() => _AddToWishlistSheetState();
}

class _AddToWishlistSheetState extends State<AddToWishlistSheet> {
  int? _selectedBoardId = -1; // -1 for "All Items" (default)
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Fetch boards if empty
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final service = context.read<WishlistService>();
      if (service.boards.isEmpty) {
        service.fetchBoards();
      }
    });
  }

  Future<void> _save() async {
    setState(() => _isLoading = true);
    
    final service = context.read<WishlistService>();
    // If selectedBoardId is -1, we pass null to API (default board)
    final boardId = _selectedBoardId == -1 ? null : _selectedBoardId;
    
    final success = await service.toggleFavorite(widget.productId, boardId: boardId);
    
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Added to wishlist')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to add to wishlist')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<WishlistService>();
    final boards = service.boards;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Save to Wishlist',
            style: TextStyle(
              fontSize: 18, 
              fontWeight: FontWeight.bold,
              color: theme.textTheme.titleLarge?.color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Default "All Items" option
                  RadioListTile<int>(
                    value: -1,
                    groupValue: _selectedBoardId,
                    onChanged: (val) => setState(() => _selectedBoardId = val),
                    title: const Text('All Items'),
                    secondary: const Icon(Icons.favorite_border),
                  ),
                  
                  // User boards
                  ...boards.map((board) => RadioListTile<int>(
                    value: board.id,
                    groupValue: _selectedBoardId,
                    onChanged: (val) => setState(() => _selectedBoardId = val),
                    title: Text(board.name),
                    secondary: const Icon(Icons.folder_open),
                  )),
                  
                  // Create new
                  ListTile(
                    leading: const Icon(Icons.add),
                    title: const Text('Create new collection'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => const CreateBoardDialog(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isLoading ? null : _save,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isLoading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Text('Save'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
