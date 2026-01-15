import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/order_service.dart';
import '../../../core/theme/theme.dart';
import 'order_details_screen.dart';

class OrdersListScreen extends StatefulWidget {
  const OrdersListScreen({super.key});

  @override
  State<OrdersListScreen> createState() => _OrdersListScreenState();
}

class _OrdersListScreenState extends State<OrdersListScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final ScrollController _scrollController = ScrollController();
  
  // Tab filter status mapping
  final List<int?> _statusFilters = [
    null, // All
    OrderStatus.pending,
    OrderStatus.processing,
    OrderStatus.shipped,
    OrderStatus.delivered,
    OrderStatus.cancelled,
  ];
  
  final List<String> _tabLabels = [
    'All',
    'Pending',
    'Processing',
    'Shipped',
    'Delivered',
    'Cancelled',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
    _tabController.addListener(_onTabChanged);
    _scrollController.addListener(_onScroll);
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchOrders(refresh: true);
    });
  }

  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (!_tabController.indexIsChanging) {
      final status = _statusFilters[_tabController.index];
      context.read<OrderService>().fetchOrders(status: status, refresh: true);
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= 
        _scrollController.position.maxScrollExtent - 200) {
      final orderService = context.read<OrderService>();
      if (!orderService.isLoading && orderService.hasMore) {
        orderService.loadMore();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'My Orders',
          style: AppTypography.headingSmall(
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () {
            // Pop back to root (MainShell/Home)
            Navigator.of(context).popUntil((route) => route.isFirst);
          },
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary500,
          labelColor: AppColors.primary500,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          labelStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal, fontSize: 11),
          indicatorWeight: 2,
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
      body: Consumer<OrderService>(
        builder: (context, orderService, child) {
          if (orderService.isLoading && orderService.orders.isEmpty) {
            return _buildLoadingState(isDark);
          }

          if (orderService.error != null && orderService.orders.isEmpty) {
            return _buildErrorState(orderService.error!, isDark);
          }

          if (orderService.orders.isEmpty) {
            return _buildEmptyState(isDark);
          }

          return RefreshIndicator(
            onRefresh: () => orderService.refresh(),
            color: AppColors.primary500,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: orderService.orders.length + (orderService.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == orderService.orders.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final order = orderService.orders[index];
                return _OrderCard(
                  order: order,
                  onTap: () => _navigateToDetails(order.id),
                ).animate(delay: Duration(milliseconds: 50 * index))
                 .fadeIn()
                 .slideY(begin: 0.1, end: 0);
              },
            ),
          );
        },
      ),
    );
  }

  void _navigateToDetails(int orderId) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OrderDetailsScreen(orderId: orderId),
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 5,
      itemBuilder: (context, index) {
        return Container(
          height: 120,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(16),
          ),
        ).animate(onPlay: (c) => c.repeat())
         .shimmer(duration: 1200.ms, color: isDark ? Colors.white10 : Colors.white54);
      },
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.warning_2,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: AppTypography.headingSmall(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: AppTypography.bodyMedium(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.read<OrderService>().refresh(),
              icon: const Icon(Iconsax.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Iconsax.box,
              size: 64,
              color: isDark ? Colors.white38 : Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Orders Yet',
              style: AppTypography.headingSmall(
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'When you place orders, they will appear here',
              style: AppTypography.bodyMedium(
                color: isDark ? Colors.white54 : Colors.black54,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Order Card Widget
class _OrderCard extends StatelessWidget {
  final OrderSummary order;
  final VoidCallback onTap;

  const _OrderCard({
    required this.order,
    required this.onTap,
  });

  Color _getStatusColor() {
    switch (order.statusId) {
      case OrderStatus.pending:
        return Colors.orange;
      case OrderStatus.confirmed:
        return Colors.blue;
      case OrderStatus.processing:
        return Colors.purple;
      case OrderStatus.shipped:
        return Colors.indigo;
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.cancelled:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.teal;
      case OrderStatus.failed:
        return Colors.red.shade700;
      case OrderStatus.onHold:
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon() {
    switch (order.statusId) {
      case OrderStatus.pending:
        return Iconsax.clock;
      case OrderStatus.confirmed:
        return Iconsax.tick_circle;
      case OrderStatus.processing:
        return Iconsax.refresh;
      case OrderStatus.shipped:
        return Iconsax.truck_fast;
      case OrderStatus.delivered:
        return Iconsax.box_tick;
      case OrderStatus.cancelled:
        return Iconsax.close_circle;
      case OrderStatus.refunded:
        return Iconsax.money_recive;
      case OrderStatus.failed:
        return Iconsax.danger;
      case OrderStatus.onHold:
        return Iconsax.pause_circle;
      default:
        return Iconsax.box;
    }
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy • hh:mm a').format(date);
    } catch (e) {
      return dateString;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final statusColor = _getStatusColor();

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black26 : Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row - Order Number & Status
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      order.orderNumber,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: statusColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_getStatusIcon(), size: 12, color: statusColor),
                          const SizedBox(width: 3),
                          Text(
                            order.status,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: statusColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Order Info Row
                Row(
                  children: [
                    _buildInfoItem(
                      icon: Iconsax.box,
                      label: '${order.quantity} item${order.quantity > 1 ? 's' : ''}',
                      isDark: isDark,
                    ),
                    const SizedBox(width: 16),
                    _buildInfoItem(
                      icon: Iconsax.card,
                      label: order.paymentType,
                      isDark: isDark,
                    ),
                    if (order.isPaid == 1) ...[
                      const SizedBox(width: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'PAID',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 10),
                
                // Divider
                Divider(
                  color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
                ),
                
                const SizedBox(height: 6),
                
                // Footer Row - Date & Total
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _formatDate(order.createdAt),
                      style: TextStyle(
                        fontSize: 10,
                        color: isDark ? Colors.white54 : Colors.black45,
                      ),
                    ),
                    Text(
                      '${order.currencySymbol}${order.total.toStringAsFixed(2)}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 12,
          color: isDark ? Colors.white54 : Colors.black45,
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.white54 : Colors.black54,
          ),
        ),
      ],
    );
  }
}
