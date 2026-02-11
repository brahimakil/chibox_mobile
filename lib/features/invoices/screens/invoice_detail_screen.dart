import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:iconsax/iconsax.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../../../core/constants/api_constants.dart';
import '../../../core/models/invoice_model.dart';
import '../../../core/theme/theme.dart';
import '../../orders/screens/order_details_screen.dart';

/// Gesture recognizer that eagerly claims all vertical drag events
/// so the WebView can scroll inside a TabBarView.
class _EagerVerticalDragGestureRecognizer extends VerticalDragGestureRecognizer {
  @override
  void rejectGesture(int pointer) {
    acceptGesture(pointer);
  }
}

class InvoiceDetailScreen extends StatefulWidget {
  final Invoice invoice;

  const InvoiceDetailScreen({super.key, required this.invoice});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late WebViewController _webViewController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initWebViewController();
  }

  void _initWebViewController() {
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.viewInvoice}?id=${widget.invoice.id}';
    _webViewController = WebViewController();
    _webViewController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String finishedUrl) async {
            await _webViewController.runJavaScript('''
              (function() {
                var noPrint = document.querySelector('.no-print');
                if (noPrint) noPrint.style.display = 'none';
              })();
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Invoice get invoice => widget.invoice;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          invoice.invoiceNumber,
          style: AppTypography.headingSmall(
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          IconButton(
            icon: Icon(Iconsax.document_download,
                color: theme.iconTheme.color),
            tooltip: 'View Full Invoice',
            onPressed: _openInvoiceWebView,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary500,
          labelColor: AppColors.primary500,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          labelStyle:
              const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: 'Details'),
            Tab(text: 'Invoice View'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildDetailsTab(isDark),
          _buildWebViewTab(),
        ],
      ),
    );
  }

  Widget _buildDetailsTab(bool isDark) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Invoice Header Card
          _buildHeaderCard(isDark),
          const SizedBox(height: 16),

          // Items List
          _buildItemsSection(isDark),
          const SizedBox(height: 16),

          // Financial Summary
          _buildSummaryCard(isDark),
          const SizedBox(height: 16),

          // Payment Info
          _buildPaymentInfoCard(isDark),
          const SizedBox(height: 16),

          // Billing Address
          if (invoice.billingAddress != null)
            _buildAddressCard(isDark),

          if (invoice.notes != null && invoice.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildNotesCard(isDark),
          ],

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(bool isDark) {
    final typeColor = invoice.isProduct ? AppColors.primary500 : Colors.blue;
    final typeIcon = invoice.isProduct ? Iconsax.box : Iconsax.truck_fast;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            typeColor,
            typeColor.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(typeIcon, color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text(
                    invoice.typeLabel,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  invoice.isVoid ? 'VOID' : 'PAID',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '\$${invoice.total.toStringAsFixed(2)}',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            invoice.invoiceNumber,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Order: ${invoice.orderNumber}',
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
              Text(
                _formatDate(invoice.createdAt),
                style: const TextStyle(
                  color: Colors.white60,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // View Order button
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(orderId: invoice.orderId),
                  ),
                );
              },
              icon: const Icon(Iconsax.eye, size: 16, color: Colors.white),
              label: const Text('View Order', style: TextStyle(color: Colors.white, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.white38),
                padding: const EdgeInsets.symmetric(vertical: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItemsSection(bool isDark) {
    return Container(
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Items',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          ...invoice.items.asMap().entries.map((entry) {
            final item = entry.value;
            final isLast = entry.key == invoice.items.length - 1;
            return Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Item image or icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withOpacity(0.05)
                              : Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: item.mainImage != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.mainImage!,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Icon(
                                    Iconsax.box_1,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white38
                                        : Colors.grey,
                                  ),
                                ),
                              )
                            : Icon(
                                item.productCode == 'SHIPPING'
                                    ? Iconsax.truck_fast
                                    : item.productCode == 'TAX'
                                        ? Iconsax.receipt
                                        : Iconsax.box_1,
                                size: 20,
                                color:
                                    isDark ? Colors.white38 : Colors.grey,
                              ),
                      ),
                      const SizedBox(width: 12),
                      // Item details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.productName,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: isDark ? Colors.white : Colors.black,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (item.variationName != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                item.variationName!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isDark
                                      ? Colors.white54
                                      : Colors.black54,
                                ),
                              ),
                            ],
                            const SizedBox(height: 4),
                            Text(
                              '${item.quantity}x \$${item.unitPrice.toStringAsFixed(2)}',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.white54
                                    : Colors.black54,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Item total
                      Text(
                        '\$${item.total.toStringAsFixed(2)}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isLast)
                  Divider(
                    height: 1,
                    indent: 68,
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                  ),
              ],
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Summary',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildSummaryRow('Subtotal', invoice.subtotal, isDark),
          if (invoice.shippingAmount > 0)
            _buildSummaryRow('Shipping', invoice.shippingAmount, isDark),
          if (invoice.taxAmount > 0)
            _buildSummaryRow('Tax', invoice.taxAmount, isDark),
          if (invoice.discountAmount > 0)
            _buildSummaryRow('Discount', -invoice.discountAmount, isDark,
                isDiscount: true),
          const SizedBox(height: 8),
          Divider(
            color: isDark
                ? Colors.white.withOpacity(0.1)
                : Colors.black.withOpacity(0.1),
          ),
          const SizedBox(height: 8),
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
                '\$${invoice.total.toStringAsFixed(2)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(String label, double amount, bool isDark,
      {bool isDiscount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isDiscount
                  ? Colors.red
                  : (isDark ? Colors.white70 : Colors.black54),
            ),
          ),
          Text(
            '${isDiscount ? '-' : ''}\$${amount.abs().toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: isDiscount
                  ? Colors.red
                  : (isDark ? Colors.white : Colors.black),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentInfoCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Payment Information',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
              Iconsax.card, 'Method', _getPaymentMethodLabel(), isDark),
          if (invoice.paymentReference != null)
            _buildInfoRow(
                Iconsax.key, 'Reference', invoice.paymentReference!, isDark),
          _buildInfoRow(Iconsax.calendar, 'Date',
              _formatDate(invoice.createdAt), isDark),
        ],
      ),
    );
  }

  Widget _buildAddressCard(bool isDark) {
    final addr = invoice.billingAddress!;
    return Container(
      padding: const EdgeInsets.all(16),
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
          Text(
            'Billing Address',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Iconsax.location,
                  size: 18,
                  color: isDark ? Colors.white54 : Colors.black45),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      addr.fullName,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      addr.formattedAddress,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.white54 : Colors.black54,
                      ),
                    ),
                    if (addr.phone != null && addr.phone!.trim().isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        addr.phone!,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.white54 : Colors.black54,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotesCard(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF2D2000)
            : const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.amber.withOpacity(0.3)
              : Colors.amber.withOpacity(0.5),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Iconsax.note, size: 18, color: Colors.amber[700]),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Notes',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  invoice.notes!,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.black54,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
      IconData icon, String label, String value, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon,
              size: 16, color: isDark ? Colors.white54 : Colors.black45),
          const SizedBox(width: 10),
          Text(
            '$label:  ',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.white54 : Colors.black54,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  /// WebView Tab — renders the full HTML invoice from backend
  Widget _buildWebViewTab() {
    return Column(
      children: [
        Expanded(
          child: WebViewWidget(
            controller: _webViewController,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<_EagerVerticalDragGestureRecognizer>(
                () => _EagerVerticalDragGestureRecognizer(),
              ),
            },
          ),
        ),
        // Native action buttons at the bottom
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _openInBrowser,
                    icon: const Icon(Iconsax.printer, size: 18),
                    label: const Text('Download / Print'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary500,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _shareInvoice,
                    icon: const Icon(Iconsax.share, size: 18),
                    label: const Text('Share'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Opens the invoice URL in the device's default browser where
  /// native print/download-as-PDF functionality works
  Future<void> _openInBrowser() async {
    final url = Uri.parse(
        '${ApiConstants.baseUrl}${ApiConstants.viewInvoice}?id=${invoice.id}');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open browser')),
        );
      }
    }
  }

  /// Shares the invoice link
  Future<void> _shareInvoice() async {
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.viewInvoice}?id=${invoice.id}';
    await Share.share(
      'Invoice ${invoice.invoiceNumber}\n$url',
    );
  }

  void _openInvoiceWebView() {
    final url =
        '${ApiConstants.baseUrl}${ApiConstants.viewInvoice}?id=${invoice.id}';

    final webController = WebViewController();
    webController
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.white)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (String finishedUrl) async {
            await webController.runJavaScript('''
              (function() {
                var noPrint = document.querySelector('.no-print');
                if (noPrint) noPrint.style.display = 'none';
              })();
            ''');
          },
        ),
      )
      ..loadRequest(Uri.parse(url));

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(
            title: Text(invoice.invoiceNumber),
            backgroundColor: Theme.of(context).appBarTheme.backgroundColor,
            elevation: 0,
            actions: [
              IconButton(
                icon: const Icon(Iconsax.printer),
                tooltip: 'Download / Print',
                onPressed: _openInBrowser,
              ),
              IconButton(
                icon: const Icon(Iconsax.share),
                tooltip: 'Share',
                onPressed: _shareInvoice,
              ),
            ],
          ),
          body: WebViewWidget(
            controller: webController,
            gestureRecognizers: <Factory<OneSequenceGestureRecognizer>>{
              Factory<_EagerVerticalDragGestureRecognizer>(
                () => _EagerVerticalDragGestureRecognizer(),
              ),
            },
          ),
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return DateFormat('MMM dd, yyyy').format(date);
    } catch (e) {
      return dateString;
    }
  }

  String _getPaymentMethodLabel() {
    final methods = {
      'cash': 'Cash on Delivery',
      'card': 'Credit/Debit Card',
      'paypal': 'PayPal',
      'stripe': 'Stripe',
      'online': 'Online Payment',
      'whish_money': 'Whish Money',
    };
    return methods[invoice.paymentMethod] ??
        (invoice.paymentMethod != null
            ? invoice.paymentMethod!
                .replaceAll('_', ' ')
                .split(' ')
                .map((w) =>
                    w.isNotEmpty ? '${w[0].toUpperCase()}${w.substring(1)}' : '')
                .join(' ')
            : 'Unknown');
  }
}
