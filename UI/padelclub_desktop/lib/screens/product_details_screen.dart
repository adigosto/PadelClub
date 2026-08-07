import 'package:flutter/material.dart';

import 'package:padelclub_desktop/layouts/master_screen.dart';

class ProductDetailsScreen extends StatefulWidget {
  const ProductDetailsScreen({super.key});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    return const MasterScreen(
      title: 'Product Details',
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _DetailHeroCard(),
            SizedBox(height: 16),
            _InfoCard(),
          ],
        ),
      ),
    );
  }
}

class _DetailHeroCard extends StatelessWidget {
  const _DetailHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Row(
        children: const [
          CircleAvatar(
            radius: 28,
            backgroundColor: Color(0xFFE8F4EF),
            child: Icon(Icons.inventory_2_outlined, color: Color(0xFF1F7A63), size: 28),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Premium Padel Ball Pack',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Color(0xFF27423A)),
                ),
                SizedBox(height: 4),
                Text(
                  'Tournament-ready balls selected for club training and weekend play.',
                  style: TextStyle(color: Color(0xFF5C6B64)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFDDE5DC)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          Text('Product details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: Color(0xFF27423A))),
          SizedBox(height: 12),
          _DetailRow(label: 'Price', value: '\$42.00'),
          _DetailRow(label: 'Stock', value: '24 items'),
          _DetailRow(label: 'Category', value: 'Equipment'),
          _DetailRow(label: 'Status', value: 'Available'),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Color(0xFF5C6B64), fontWeight: FontWeight.w600)),
          ),
          Text(value, style: const TextStyle(color: Color(0xFF27423A), fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}