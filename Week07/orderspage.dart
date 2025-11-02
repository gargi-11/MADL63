import 'package:flutter/material.dart';

class OrdersPage extends StatelessWidget {
  const OrdersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('My Orders'),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Active'),
              Tab(text: 'Past'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildActiveOrders(),
            _buildPastOrders(),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveOrders() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildOrderCard(
          orderId: '#12345',
          restaurant: 'Pizza Palace',
          items: '2 items',
          status: 'Preparing',
          statusColor: Colors.orange,
          showTrack: true,
        ),
        _buildOrderCard(
          orderId: '#12344',
          restaurant: 'Burger House',
          items: '1 item',
          status: 'Out for delivery',
          statusColor: Colors.blue,
          showTrack: true,
        ),
      ],
    );
  }

  Widget _buildPastOrders() {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        _buildOrderCard(
          orderId: '#12343',
          restaurant: 'Sushi World',
          items: '3 items',
          status: 'Delivered',
          statusColor: Colors.green,
          showTrack: false,
        ),
        _buildOrderCard(
          orderId: '#12342',
          restaurant: 'Taco Fiesta',
          items: '2 items',
          status: 'Delivered',
          statusColor: Colors.green,
          showTrack: false,
        ),
      ],
    );
  }

  Widget _buildOrderCard({
    required String orderId,
    required String restaurant,
    required String items,
    required String status,
    required Color statusColor,
    required bool showTrack,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  orderId,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              restaurant,
              style: const TextStyle(fontSize: 16),
            ),
            Text(
              items,
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (showTrack) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.location_on_outlined),
                  label: const Text('Track Order'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}