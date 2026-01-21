import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:iconsax/iconsax.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/models/order_model.dart';
import '../../../core/models/product_model.dart';
import '../../../core/services/order_service.dart';
import '../../../core/theme/theme.dart';
import '../../product/screens/product_details_screen.dart';

class OrderDetailsScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailsScreen({super.key, required this.orderId});

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  bool _hasFetched = false;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<OrderService>().fetchOrderDetails(widget.orderId).then((_) {
        if (mounted) setState(() => _hasFetched = true);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? Colors.black : const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: Text(
          'Order Details',
          style: AppTypography.headingSmall(
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () {
            debugPrint('🔴 OrderDetailsScreen: Back button pressed, mounted=$mounted');
            Navigator.pop(context);
          },
        ),
      ),
      body: Consumer<OrderService>(
        builder: (context, orderService, child) {
          // Show loading skeleton until fetch completes (prevents brief error flash)
          if (!_hasFetched || (orderService.isLoading && orderService.selectedOrder == null)) {
            return _buildLoadingState(isDark);
          }

          final order = orderService.selectedOrder;
          if (order == null) {
            return _buildErrorState(
              orderService.error ?? 'Order not found',
              isDark,
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Order Header Card
                _buildOrderHeader(order, isDark),
                
                const SizedBox(height: 16),
                
                // Order Tracking
                _buildTrackingSection(order, isDark),
                
                const SizedBox(height: 16),
                
                // Products Section
                _buildProductsSection(order, isDark),
                
                const SizedBox(height: 16),
                
                // Delivery Address
                _buildAddressSection(order, isDark),
                
                const SizedBox(height: 16),
                
                // Payment Summary
                _buildPaymentSummary(order, isDark),
                
                const SizedBox(height: 32),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
    final baseColor = isDark ? Colors.grey[800]! : Colors.grey[300]!;
    final highlightColor = isDark ? Colors.grey[700]! : Colors.grey[100]!;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Header skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(width: 120, height: 20, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                    Container(width: 80, height: 24, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(12))),
                  ],
                ),
                const SizedBox(height: 12),
                Container(width: 180, height: 14, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: highlightColor),
          
          const SizedBox(height: 16),
          
          // Order Tracking skeleton
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 100, height: 16, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                ...List.generate(3, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(width: 24, height: 24, decoration: BoxDecoration(color: baseColor, shape: BoxShape.circle)),
                      const SizedBox(width: 12),
                      Expanded(child: Container(height: 14, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4)))),
                    ],
                  ),
                )),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: highlightColor),
          
          const SizedBox(height: 16),
          
          // Products skeleton with fallback images
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(width: 80, height: 16, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                const SizedBox(height: 16),
                // Product items with fallback image
                ...List.generate(2, (index) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      // Product image with fallback
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          'assets/images/productfailbackorskeleton_loading.png',
                          width: 70,
                          height: 70,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(height: 14, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 8),
                            Container(width: 80, height: 12, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                            const SizedBox(height: 8),
                            Container(width: 60, height: 16, decoration: BoxDecoration(color: baseColor, borderRadius: BorderRadius.circular(4))),
                          ],
                        ),
                      ),
                    ],
                  ),
                )),
              ],
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: highlightColor),
          
          const SizedBox(height: 16),
          
          // Address skeleton
          Container(
            height: 100,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: highlightColor),
          
          const SizedBox(height: 16),
          
          // Payment summary skeleton
          Container(
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1200.ms, color: highlightColor),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error, bool isDark) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Iconsax.warning_2, size: 64, color: AppColors.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load order',
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
              onPressed: () => context.read<OrderService>().fetchOrderDetails(widget.orderId),
              icon: const Icon(Iconsax.refresh),
              label: const Text('Try Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary500,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderHeader(OrderDetails order, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Order Number & Copy
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Number',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black45,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    order.orderNumber,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: order.orderNumber));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Order number copied'),
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  );
                },
                icon: Icon(
                  Iconsax.copy,
                  color: isDark ? Colors.white54 : Colors.black45,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Status Badge
          _buildStatusBadge(order),
          
          const SizedBox(height: 16),
          
          // Order Date & Payment
          Row(
            children: [
              Expanded(
                child: _buildInfoColumn(
                  icon: Iconsax.calendar,
                  label: 'Order Date',
                  value: _formatDate(order.createdAt),
                  isDark: isDark,
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
              ),
              Expanded(
                child: _buildInfoColumn(
                  icon: Iconsax.card,
                  label: 'Payment',
                  value: order.paymentType,
                  isDark: isDark,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildStatusBadge(OrderDetails order) {
    final color = _getStatusColor(order.statusId);
    final icon = _getStatusIcon(order.statusId);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Text(
            order.status,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          if (order.isPaid == 1) ...[
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text(
                'PAID',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingSection(OrderDetails order, bool isDark) {
    if (order.tracking.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.location, size: 20, color: AppColors.primary500),
              const SizedBox(width: 8),
              Text(
                'Order Tracking',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...List.generate(order.tracking.length, (index) {
            final track = order.tracking[index];
            final isFirst = index == 0;
            final isLast = index == order.tracking.length - 1;
            final color = _getStatusColor(track.statusId);

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Timeline
                Column(
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: isFirst ? color : Colors.grey.shade300,
                        shape: BoxShape.circle,
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2,
                        height: 50,
                        color: Colors.grey.shade300,
                      ),
                  ],
                ),
                const SizedBox(width: 16),
                // Content
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.status,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: isFirst ? FontWeight.bold : FontWeight.normal,
                            color: isFirst 
                                ? (isDark ? Colors.white : Colors.black)
                                : (isDark ? Colors.white54 : Colors.black54),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(track.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white38 : Colors.black38,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          }),
        ],
      ),
    ).animate(delay: 100.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildProductsSection(OrderDetails order, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.box, size: 20, color: AppColors.primary500),
              const SizedBox(width: 8),
              Text(
                'Products (${order.quantity})',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...order.products.map((product) => _buildProductItem(product, order.currencySymbol, isDark)),
        ],
      ),
    ).animate(delay: 200.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildProductItem(OrderProduct product, String currencySymbol, bool isDark) {
    return GestureDetector(
      onTap: () {
        // Navigate to product details
        if (product.productId > 0) {
          // Create a minimal Product object to pass to ProductDetailsScreen
          final minimalProduct = Product(
            id: product.productId,
            name: product.productName,
            mainImage: product.displayImage ?? '',
            price: product.price,
            currencySymbol: currencySymbol,
          );
          
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ProductDetailsScreen(product: minimalProduct),
            ),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.only(bottom: 16),
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05),
            ),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Product Image
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: product.displayImage != null
                  ? CachedNetworkImage(
                      imageUrl: product.displayImage!,
                      width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      width: 80,
                      height: 80,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      child: Icon(Iconsax.image, color: Colors.grey),
                    ),
                    errorWidget: (context, url, error) => Container(
                      width: 80,
                      height: 80,
                      color: isDark ? Colors.white10 : Colors.grey.shade200,
                      child: Icon(Iconsax.image, color: Colors.grey),
                    ),
                  )
                : Container(
                    width: 80,
                    height: 80,
                    color: isDark ? Colors.white10 : Colors.grey.shade200,
                    child: Icon(Iconsax.image, color: Colors.grey),
                  ),
          ),
          const SizedBox(width: 12),
          // Product Details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.productName,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                if (product.variationName != null && product.variationName!.isNotEmpty)
                  Text(
                    product.variationName!,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.white54 : Colors.black54,
                    ),
                  ),
                if (product.variations.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: product.variations.map((v) {
                      return Container(
                        margin: const EdgeInsets.only(top: 4),
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${v.optionName}: ${v.valueName}',
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Qty: ${product.quantity}',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          '$currencySymbol${product.total.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary500,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_forward_ios,
                          size: 12,
                          color: isDark ? Colors.white38 : Colors.black26,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        ),
      ),
    );
  }

  Widget _buildAddressSection(OrderDetails order, bool isDark) {
    final address = order.address;

    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.location, size: 20, color: AppColors.primary500),
              const SizedBox(width: 8),
              Text(
                'Delivery Address',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            address.fullName,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            address.fullPhone,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white70 : Colors.black54,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            address.fullAddress,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.white54 : Colors.black54,
              height: 1.4,
            ),
          ),
          if (order.clientNotes != null && order.clientNotes!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Iconsax.note,
                    size: 16,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      order.clientNotes!,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    ).animate(delay: 300.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildPaymentSummary(OrderDetails order, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Iconsax.receipt, size: 20, color: AppColors.primary500),
              const SizedBox(width: 8),
              Text(
                'Payment Summary',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const Spacer(),
              // Payment status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: order.isPaid == 1 
                      ? Colors.green.withOpacity(0.15)
                      : Colors.orange.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order.isPaid == 1 ? 'PAID' : 'UNPAID',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: order.isPaid == 1 ? Colors.green : Colors.orange,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildSummaryRow('Subtotal', order.subtotal, order.currencySymbol, isDark),
          // Shipping row with method badge
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Shipping',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: order.shippingMethod == 'air'
                          ? Colors.blue.withOpacity(0.1)
                          : Colors.teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      order.shippingMethod == 'air' ? '✈️ Air' : '🚢 Sea',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: order.shippingMethod == 'air' ? Colors.blue : Colors.teal,
                      ),
                    ),
                  ),
                ],
              ),
              Text(
                '${order.currencySymbol}${order.shippingAmount.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (order.taxAmount > 0)
            _buildSummaryRow('Tax', order.taxAmount, order.currencySymbol, isDark),
          if (order.discountAmount > 0)
            _buildSummaryRow('Discount', -order.discountAmount, order.currencySymbol, isDark, isDiscount: true),
          const SizedBox(height: 12),
          Divider(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              Text(
                '${order.currencySymbol}${order.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate(delay: 400.ms).fadeIn().slideY(begin: 0.1, end: 0);
  }

  Widget _buildSummaryRow(String label, double amount, String symbol, bool isDark, {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}$symbol${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              color: isDiscount ? Colors.green : (isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoColumn({
    required IconData icon,
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppColors.primary500),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: isDark ? Colors.white54 : Colors.black45,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Color _getStatusColor(int status) {
    switch (status) {
      case OrderStatus.pending: return Colors.orange;
      case OrderStatus.confirmed: return Colors.blue;
      case OrderStatus.processing: return Colors.purple;
      case OrderStatus.shipped: return Colors.indigo;
      case OrderStatus.delivered: return Colors.green;
      case OrderStatus.cancelled: return Colors.red;
      case OrderStatus.refunded: return Colors.teal;
      case OrderStatus.failed: return Colors.red.shade700;
      case OrderStatus.onHold: return Colors.amber;
      default: return Colors.grey;
    }
  }

  IconData _getStatusIcon(int status) {
    switch (status) {
      case OrderStatus.pending: return Iconsax.clock;
      case OrderStatus.confirmed: return Iconsax.tick_circle;
      case OrderStatus.processing: return Iconsax.refresh;
      case OrderStatus.shipped: return Iconsax.truck_fast;
      case OrderStatus.delivered: return Iconsax.box_tick;
      case OrderStatus.cancelled: return Iconsax.close_circle;
      case OrderStatus.refunded: return Iconsax.money_recive;
      case OrderStatus.failed: return Iconsax.danger;
      case OrderStatus.onHold: return Iconsax.pause_circle;
      default: return Iconsax.box;
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
}
