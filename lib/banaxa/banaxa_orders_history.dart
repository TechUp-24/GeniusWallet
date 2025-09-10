// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:genius_wallet/banaxa/banaxa_api_services.dart';
import 'package:genius_wallet/banaxa/banaxa_model.dart';
import 'package:genius_wallet/banaxa/handle_banaxa_drawer.dart';
import 'package:genius_wallet/banxa_order/banxa_order_cubit.dart';
import 'package:genius_wallet/banxa_order/banxa_order_state.dart';
import 'package:genius_wallet/theme/genius_wallet_colors.g.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});

  @override
  State<OrdersPage> createState() => _OrdersPageState();
}

class _OrdersPageState extends State<OrdersPage> {
  @override
  void initState() {
    super.initState();
    BlocProvider.of<OrdersCubit>(context).fetchOrders('your-cust-id');
  }

  final List<String> statuses = [
    "",
    "pendingPayment",
    "completed",
    "declined",
    "inProgress",
    "expired"
  ];
  String? selectedStatus = "";
  DateTime? startDate;
  DateTime? endDate;

  Future<void> _pickDateRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: startDate != null && endDate != null
          ? DateTimeRange(start: startDate!, end: endDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        startDate = picked.start;
        endDate = picked.end;
      });

      context.read<OrdersCubit>().applyFilters(
            status: selectedStatus,
            startDate: startDate,
            endDate: endDate,
          );
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'pendingpayment':
      case 'pending':
        return Colors.orange;
      case 'declined':
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String formatDate(DateTime? dateTime) {
    if (dateTime == null) return '';
    try {
      return DateFormat('MMM dd, yyyy • hh:mm a').format(dateTime.toLocal());
    } catch (_) {
      return dateTime.toString();
    }
  }

  String _shortId(String id, {int head = 6, int tail = 4}) {
    if (id.length <= head + tail + 1) return id;
    return '${id.substring(0, head)}…${id.substring(id.length - tail)}';
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: TextStyle(color: Colors.grey[700])),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildActionButton(BuildContext context, Map<String, dynamic> order) {
    final status = order['status']?.toString().toLowerCase() ?? '';
    final orderStatusUrl = order['orderStatusUrl'];
    final redirectUrl = Uri(
      scheme: 'geniuswallet',
      host: 'banxa',
      path: 'callback',
      queryParameters: {'extOrderId': order['externalOrderId']},
    ).toString();

    if (status == 'pendingpayment') {
      return ElevatedButton(
        onPressed: () async {
          showCheckoutOptionsSheet(
            context,
            checkoutUrl: orderStatusUrl,
            orderId: order['id'],
            redirectUrl: redirectUrl,
          );
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Complete Payment'),
      );
    } else if (status == 'declined') {
      return OutlinedButton(
        onPressed: () {
          context.push(
            '/createOrder',
            extra: {
              'fiat': order['fiat'],
              'crypto': order['crypto']['id'],
              'method': order['paymentMethodId'],
              'amount': order['fiatAmount'],
              'wallet': order['walletAddress'],
            },
          );
        },
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.red,
          side: const BorderSide(color: Colors.red),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        child: const Text('Retry Order'),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final status = order.status;
    final fiat = "${order.fiatAmount} ${order.fiat}";
    final crypto = "${order.cryptoAmount} ${order.crypto.id}";
    final paymentMethod = order.paymentMethodName;

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
      color: GeniusWalletColors.deepBlueCardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(
          color: GeniusWalletColors.lightGreenSecondary,
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Order #${_shortId(order.id)}",
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: _getStatusColor(status).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status.toUpperCase(),
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildInfoRow("Fiat:", fiat),
            _buildInfoRow("Crypto:", crypto),
            _buildInfoRow("Payment:", paymentMethod),
            const Divider(height: 20),
            _buildInfoRow("Created:", formatDate(order.createdAt)),
            _buildInfoRow("Updated:", formatDate(order.updatedAt)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildActionButton(context, order.toJson()),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: () {
                    context.push(
                      '/orderDetails',
                      extra: {
                        'orderId': order.id,
                        'checkoutUrl': order.orderStatusUrl,
                        'redirectUrl': BanxaApiService.redirectUrl,
                      },
                    );
                  },
                  child: const Text('See Details'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canGoBack = GoRouter.of(context).canPop();
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: canGoBack,
        leading: canGoBack
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  context.go('/dashboard');
                },
              ),
        title: const Text("My Orders"),
        actions: [
          IconButton(
            icon: const Icon(Icons.app_registration_rounded),
            onPressed: () {
              context.push('/kyc');
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              context.read<OrdersCubit>().fetchOrders('your-cust-id');
            },
          ),
          Semantics(
            label: 'Create new order',
            button: true,
            child: IconButton(
              onPressed: () => context.push('/createOrder'),
              icon: const Row(
                children: [
                  Icon(Icons.add),
                  SizedBox(width: 4),
                  Text('New Order'),
                ],
              ),
              tooltip: 'Create new order',
            ),
          )
        ],
      ),
      body: BlocBuilder<OrdersCubit, OrdersState>(
        builder: (context, state) {
          if (state.status == OrdersStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == OrdersStatus.error) {
            return Center(
              child: Text("❌ ${state.error}",
                  style: const TextStyle(color: Colors.red)),
            );
          }

          final orders = state.filteredOrders ?? [];

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 🔹 Status Dropdown
                    SizedBox(
                      height: 56,
                      child: DropdownButtonFormField<String>(
                        value: selectedStatus,
                        decoration: const InputDecoration(
                          labelText: "Status",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 12, vertical: 16),
                        ),
                        items: statuses.map((status) {
                          return DropdownMenuItem(
                            value: status,
                            child: Text(status.isEmpty ? "All" : status),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() => selectedStatus = value ?? "");
                          context.read<OrdersCubit>().applyFilters(
                                status: selectedStatus,
                                startDate: startDate,
                                endDate: endDate,
                              );
                        },
                      ),
                    ),
                    const SizedBox(height: 12),

                    // 🔹 Date Range Picker Button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          side: const BorderSide(color: Colors.white),
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        onPressed: () => _pickDateRange(context),
                        child: const Text("Pick Date Range"),
                      ),
                    ),

                    // 🔹 Show Selected Dates (under button)
                    if (startDate != null && endDate != null)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 8),
                        child: Text(
                          "Selected: ${startDate!.toLocal().toString().split(' ')[0]} "
                          "→ ${endDate!.toLocal().toString().split(' ')[0]}",
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              // 🔹 Total count
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Text(
                  "Total Orders: ${orders.length}",
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // 🔹 Responsive order grid/list
              Expanded(child: LayoutBuilder(builder: (context, constraints) {
                final isWide = constraints.maxWidth > 900;
                final crossAxisCount = isWide ? 2 : 1;
                final spacing = 16.0;
                final totalSpacing = spacing * (crossAxisCount - 1);
                final cardWidth =
                    (constraints.maxWidth - totalSpacing) / crossAxisCount;

                // Set a target card height (based on your design, e.g. 250)
                const targetHeight = 300.0;
                double childAspectRatio = cardWidth / targetHeight;

                childAspectRatio = childAspectRatio.clamp(1.2, 2.5);

                return GridView.builder(
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: spacing,
                    crossAxisSpacing: spacing,
                    childAspectRatio: childAspectRatio,
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: orders.length,
                  itemBuilder: (context, index) {
                    final order = orders[index];
                    return _buildOrderCard(context, order);
                  },
                );
              })),
            ],
          );
        },
      ),
    );
  }
}
