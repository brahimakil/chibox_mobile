import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:iconsax/iconsax.dart';
import '../../../core/theme/theme.dart';
import '../../../core/services/address_service.dart';
import '../../../core/models/address_model.dart';
import 'add_address_screen.dart';

class AddressListScreen extends StatefulWidget {
  final bool selectionMode;
  
  const AddressListScreen({super.key, this.selectionMode = false});

  @override
  State<AddressListScreen> createState() => _AddressListScreenState();
}

class _AddressListScreenState extends State<AddressListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<AddressService>().fetchAddresses();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final addressService = context.watch<AddressService>();

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          widget.selectionMode ? 'Select Address' : 'My Addresses',
          style: AppTypography.headingSmall(
            color: theme.textTheme.titleLarge?.color,
          ),
        ),
        backgroundColor: theme.appBarTheme.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, color: theme.iconTheme.color),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: addressService.isLoading
          ? const Center(child: CircularProgressIndicator())
          : addressService.addresses.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Iconsax.location, size: 64, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        'No addresses found',
                        style: AppTypography.bodyLarge(color: Colors.grey),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: addressService.addresses.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 16),
                  itemBuilder: (context, index) {
                    final address = addressService.addresses[index];
                    return _AddressCard(
                      address: address,
                      selectionMode: widget.selectionMode,
                      onSelect: widget.selectionMode 
                          ? () => Navigator.pop(context, address)
                          : null,
                    );
                  },
                ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16),
        child: ElevatedButton(
          onPressed: () async {
            final result = await Navigator.push<Address>(
              context,
              MaterialPageRoute(
                builder: (_) => AddAddressScreen(fromCheckout: widget.selectionMode),
              ),
            );
            // If in selection mode and got a new address back, return it to checkout
            if (widget.selectionMode && result != null && mounted) {
              Navigator.pop(context, result);
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary500,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text(
            'Add New Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _AddressCard extends StatelessWidget {
  final Address address;
  final bool selectionMode;
  final VoidCallback? onSelect;

  const _AddressCard({
    required this.address,
    this.selectionMode = false,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return InkWell(
      onTap: selectionMode 
          ? onSelect
          : (address.isDefault
              ? null
              : () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Set as Default'),
                      content: Text('This address (${address.routeName}) will be your default address.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final success = await context.read<AddressService>().setDefaultAddress(address.id);
                            if (success && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Default address updated')),
                              );
                            }
                          },
                          child: const Text('Set Default'),
                        ),
                      ],
                    ),
                  );
                }),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.cardTheme.color,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: address.isDefault ? AppColors.primary500 : theme.dividerColor,
            width: address.isDefault ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Iconsax.location5,
                  color: address.isDefault ? AppColors.primary500 : Colors.grey,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    address.routeName,
                    style: AppTypography.bodyLarge(
                      color: theme.textTheme.bodyLarge?.color,
                    ).copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                if (address.isDefault)
                  Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.primary500.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Default',
                      style: AppTypography.labelSmall(color: AppColors.primary500),
                    ),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: theme.iconTheme.color),
                  onSelected: (value) async {
                    if (value == 'edit') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => AddAddressScreen(addressToEdit: address),
                        ),
                      );
                    } else if (value == 'delete') {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Delete Address'),
                          content: const Text('Are you sure you want to delete this address?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: const Text('Cancel'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.pop(context, true),
                              style: TextButton.styleFrom(foregroundColor: Colors.red),
                              child: const Text('Delete'),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        final success = await context.read<AddressService>().deleteAddress(address.id);
                        if (!success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to delete address')),
                          );
                        }
                      }
                    }
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Iconsax.edit, size: 18),
                          SizedBox(width: 8),
                          Text('Edit'),
                        ],
                      ),
                    ),
                    if (!address.isDefault)
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(Iconsax.trash, size: 18, color: Colors.red),
                            SizedBox(width: 8),
                            Text('Delete', style: TextStyle(color: Colors.red)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              '${address.buildingName}, Floor ${address.floorNumber}',
              style: AppTypography.bodyMedium(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${address.city?.name}, ${address.country?.name}',
              style: AppTypography.bodyMedium(
                color: theme.textTheme.bodyMedium?.color,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${address.firstName} ${address.lastName} • ${address.countryCode} ${address.phoneNumber}',
              style: AppTypography.bodySmall(
                color: theme.textTheme.bodySmall?.color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
