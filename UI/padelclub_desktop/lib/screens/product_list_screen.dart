import 'package:flutter/material.dart';
import 'package:padelclub_desktop/layouts/master_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key});

  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  @override
  Widget build(BuildContext context) {
    return const MasterScreen(
      title: "Product List",
      child: Center(
        child: Placeholder(),
      ),
    );
  }
}