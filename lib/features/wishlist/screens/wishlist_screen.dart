import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/wishlist_service.dart';
import '../../../core/services/navigation_provider.dart';
import '../../../core/theme/theme.dart';
import '../../../shared/widgets/widgets.dart';
import '../../auth/screens/login_screen.dart';
import '../../../core/models/board_model.dart';
import '../widgets/board_card.dart';
import '../widgets/create_board_dialog.dart';
import 'collection_detail_screen.dart';

class WishlistScreen extends StatefulWidget {
  const WishlistScreen({super.key});

  @override
  State<WishlistScreen> createState() => _WishlistScreenState();
}

class _WishlistScreenState extends State<WishlistScreen> {
  int _lastIndex = -1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final navProvider = Provider.of<NavigationProvider>(context);
    // Check if we just switched TO this tab (index 2)
    if (navProvider.currentIndex == 2 && _lastIndex != 2) {
      _refreshData();
    }
    _lastIndex = navProvider.currentIndex;
  }

  void _refreshData() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        final authService = context.read<AuthService>();
        // Force refresh of auth state
        if (!authService.isGuest) {
          final service = context.read<WishlistService>();
          // Avoid fetching if already loading to prevent loops, 
          // but we might need to force it if the user just added something.
          // For now, just fetch.
          service.fetchBoards(silent: service.boards.isNotEmpty);
          service.fetchWishlist(silent: service.wishlistItems.isNotEmpty); 
        }
      }
    });
  }

  void _openCollection(Board board) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CollectionDetailScreen(
          boardId: board.id == -1 ? null : board.id,
          boardName: board.name,
        ),
      ),
    ).then((_) {
      // When returning from a collection, ensure we reset to "All Items" view
      // This ensures the next time we enter "All Items", it's fresh,
      // and also ensures any deletions inside the collection are reflected globally if needed.
      if (mounted) {
        // We don't necessarily need to fetch everything again if we use globalTotalItems,
        // but it's good practice to refresh the main view state.
        // However, to avoid a network call just for the count (which we track locally now),
        // we might skip this or just fetch boards to update their counts.
        context.read<WishlistService>().fetchBoards();
      }
    });
  }

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (context) => const CreateBoardDialog(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final authService = context.watch<AuthService>();
    final wishlistService = context.watch<WishlistService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Wishlist'),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          if (!authService.isGuest)
            IconButton(
              icon: const Icon(Icons.add),
              onPressed: _showCreateDialog,
            ),
        ],
      ),
      body: authService.isGuest
          ? _buildUnauthenticatedState(context, isDark)
          : wishlistService.isLoading && wishlistService.boards.isEmpty
              ? _buildLoadingState()
              : wishlistService.boards.isEmpty && wishlistService.totalItems == 0
                  ? _buildEmptyState(context, isDark)
                  : _buildBoardsGrid(context, wishlistService, isDark),
    );
  }

  Widget _buildUnauthenticatedState(BuildContext context, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 250,
              height: 250,
              child: Lottie.asset(
                'assets/animations/login_required.json',
                repeat: true,
              ),
            ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
           
            const SizedBox(height: 32),
            AppButton(
              text: 'Login / Register',
              width: 200,
              fullWidth: false,
              onPressed: () {
                Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
              },
            ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2, end: 0),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Lottie.asset(
        'assets/animations/loadingproducts.json',
        width: 200,
        height: 200,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            height: 220,
            child: Lottie.asset(
              'assets/animations/whishlist.json',
              repeat: true,
              fit: BoxFit.contain,
            ),
          ).animate().scale(delay: 200.ms, duration: 500.ms, curve: Curves.elasticOut),
          const SizedBox(height: 0),
          Padding(
            padding: AppSpacing.paddingHorizontalBase,
            child: AppButton(
              text: 'Create Collection',
              onPressed: _showCreateDialog,
              width: 200,
              fullWidth: false,
            ),
          ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3, end: 0),
        ],
      ),
    );
  }

  Widget _buildBoardsGrid(BuildContext context, WishlistService service, bool isDark) {
    // Create virtual "All Items" board
    final allItemsBoard = Board(
      id: -1,
      name: 'All Items',
      orderNumber: -1,
      favoritesCount: service.globalTotalItems, // Use global total instead of current view total
    );

    final allBoards = [allItemsBoard, ...service.boards];

    return RefreshIndicator(
      onRefresh: () async {
        await service.fetchBoards();
        await service.fetchWishlist();
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(16),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.8,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
        ),
        itemCount: allBoards.length,
        itemBuilder: (context, index) {
          final board = allBoards[index];
          return BoardCard(
            board: board,
            onTap: () => _openCollection(board),
            onLongPress: () {
              if (board.id != -1) {
                showModalBottomSheet(
                  context: context,
                  builder: (_) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit),
                        title: const Text('Rename'),
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (_) => CreateBoardDialog(
                              initialName: board.name,
                              boardId: board.id,
                            ),
                          );
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.delete, color: Colors.red),
                        title: const Text('Delete', style: TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.pop(context);
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Collection?'),
                              content: const Text('Items will remain in All Items.'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    service.deleteBoard(board.id);
                                  },
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              }
            },
          ).animate().fadeIn(delay: (50 * index).ms).slideY(begin: 0.1, end: 0);
        },
      ),
    );
  }
}

