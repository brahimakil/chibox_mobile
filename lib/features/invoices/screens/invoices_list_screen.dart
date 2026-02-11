import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../../core/models/invoice_model.dart';
import '../../../core/models/order_model.dart';
import '../../../core/services/invoice_service.dart';
import '../../../core/services/order_service.dart';
import '../../../core/theme/theme.dart';
import 'invoice_detail_screen.dart';

class InvoicesListScreen extends StatefulWidget {
  const InvoicesListScreen({super.key});

  @override
  State<InvoicesListScreen> createState() => _InvoicesListScreenState();
}

class _InvoicesListScreenState extends State<InvoicesListScreen> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orderService = context.read<OrderService>();
      if (orderService.orders.isEmpty) {
        orderService.fetchOrders(refresh: true);
      }
    });
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      final orderService = context.read<OrderService>();
      if (orderService.hasMore && !orderService.isLoading) {
        orderService.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Invoices'),
      ),
      body: Consumer<OrderService>(
        builder: (context, orderService, _) {
          if (orderService.isLoading && orderService.orders.isEmpty) {
            return const Center(child: CircularProgressIndicator());
          }

          if (orderService.error != null && orderService.orders.isEmpty) {
            return _buildErrorState(orderService);
          }

          if (orderService.orders.isEmpty) {
            return _buildEmptyState();
          }

          return RefreshIndicator(
            onRefresh: () => orderService.refresh(),
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: orderService.orders.length +
                  (orderService.hasMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index >= orderService.orders.length) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final order = orderService.orders[index];
                return _OrderInvoiceCard(order: order);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildErrorState(OrderService orderService) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Iconsax.warning_2, size: 48, color: Colors.red.shade300),
            const SizedBox(height: 16),
            Text(
              orderService.error ?? 'Something went wrong',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => orderService.fetchOrders(refresh: true),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Iconsax.document, size: 64, color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4)),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your invoices will appear here\nonce you place an order.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.6)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Expandable Order Card — shows order summary, expands to show its invoices
// ---------------------------------------------------------------------------
class _OrderInvoiceCard extends StatefulWidget {
  final OrderSummary order;
  const _OrderInvoiceCard({required this.order});

  @override
  State<_OrderInvoiceCard> createState() => _OrderInvoiceCardState();
}

class _OrderInvoiceCardState extends State<_OrderInvoiceCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  bool _loadingInvoices = false;
  List<Invoice>? _invoices;
  String? _invoiceError;

  void _toggle() async {
    if (_expanded) {
      setState(() => _expanded = false);
      return;
    }

    setState(() {
      _expanded = true;
    });

    // Fetch invoices the first time we expand
    if (_invoices == null && !_loadingInvoices) {
      setState(() => _loadingInvoices = true);
      try {
        final invoiceService = context.read<InvoiceService>();
        final invoices =
            await invoiceService.fetchOrderInvoices(widget.order.id);
        if (mounted) {
          setState(() {
            _invoices = invoices;
            _loadingInvoices = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _invoiceError = 'Failed to load invoices';
            _loadingInvoices = false;
          });
        }
      }
    }
  }

  Color _statusColor(int statusId) {
    switch (statusId) {
      case OrderStatus.delivered:
        return Colors.green;
      case OrderStatus.shipped:
        return Colors.blue;
      case OrderStatus.processing:
      case OrderStatus.confirmed:
        return Colors.orange;
      case OrderStatus.cancelled:
      case OrderStatus.failed:
        return Colors.red;
      case OrderStatus.refunded:
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final order = widget.order;
    final statusColor = _statusColor(order.statusId);
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String formattedDate = order.createdAt;
    try {
      final dt = DateTime.parse(order.createdAt);
      formattedDate = DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {}

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: _expanded
              ? AppColors.primary500.withOpacity(0.4)
              : theme.colorScheme.outline.withOpacity(0.3),
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: _toggle,
        child: Column(
          children: [
            // ---- Order header row ----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
              child: Row(
                children: [
                  // Order icon
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: AppColors.primary500.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Iconsax.box_1,
                        color: AppColors.primary500, size: 22),
                  ),
                  const SizedBox(width: 12),
                  // Order info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Order #${order.orderNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                            color: theme.colorScheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                order.status,
                                style: TextStyle(
                                  color: statusColor,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Text(
                              formattedDate,
                              style: TextStyle(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Total + chevron
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${order.currencySymbol}${order.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Icon(
                        _expanded
                            ? Iconsax.arrow_up_2
                            : Iconsax.arrow_down_1,
                        size: 18,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // ---- Expanded invoices section ----
            AnimatedCrossFade(
              firstChild: const SizedBox.shrink(),
              secondChild: _buildInvoicesSection(),
              crossFadeState: _expanded
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              duration: const Duration(milliseconds: 250),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInvoicesSection() {
    if (_loadingInvoices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(
            child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        )),
      );
    }

    if (_invoiceError != null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _invoiceError!,
          style: TextStyle(color: Colors.red.shade400, fontSize: 13),
        ),
      );
    }

    if (_invoices == null || _invoices!.isEmpty) {
      final emptyTheme = Theme.of(context);
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: emptyTheme.colorScheme.surfaceContainerHighest.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            children: [
              Icon(Iconsax.document, color: emptyTheme.colorScheme.onSurfaceVariant.withOpacity(0.5), size: 28),
              const SizedBox(height: 8),
              Text(
                'No invoices for this order yet',
                style: TextStyle(
                  color: emptyTheme.colorScheme.onSurfaceVariant.withOpacity(0.6),
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final sectionTheme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Divider(color: sectionTheme.colorScheme.outline.withOpacity(0.2), height: 1),
          const SizedBox(height: 10),
          Text(
            'INVOICES (${_invoices!.length})',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: sectionTheme.colorScheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          ..._invoices!.map((invoice) => _InvoiceTile(invoice: invoice)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Single invoice tile inside an expanded order card
// ---------------------------------------------------------------------------
class _InvoiceTile extends StatelessWidget {
  final Invoice invoice;
  const _InvoiceTile({required this.invoice});

  IconData _typeIcon() {
    switch (invoice.type) {
      case 'products':
        return Iconsax.box_1;
      case 'shipping':
        return Iconsax.truck;
      default:
        return Iconsax.document_text;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPaid = invoice.status == 'paid';
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    String formattedDate = '';
    try {
      final dt = DateTime.parse(invoice.createdAt);
      formattedDate = DateFormat('MMM dd, yyyy').format(dt);
    } catch (_) {}

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => InvoiceDetailScreen(invoice: invoice),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark
              ? theme.colorScheme.surfaceContainerHighest.withOpacity(0.3)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: theme.colorScheme.outline.withOpacity(0.2),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary500.withOpacity(0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(_typeIcon(), size: 18, color: AppColors.primary500),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.invoiceNumber,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: theme.colorScheme.onSurface,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formattedDate.isNotEmpty
                        ? '${invoice.typeLabel} · $formattedDate'
                        : invoice.typeLabel,
                    style: TextStyle(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${invoice.currency}${invoice.total.toStringAsFixed(2)}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: isPaid
                        ? Colors.green.withOpacity(0.1)
                        : Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    invoice.statusLabel.toUpperCase(),
                    style: TextStyle(
                      color: isPaid ? Colors.green : Colors.orange,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(Iconsax.arrow_right_3,
                size: 16, color: theme.colorScheme.onSurfaceVariant),
          ],
        ),
      ),
    );
  }
}
