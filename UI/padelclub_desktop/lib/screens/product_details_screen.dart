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
      title: "Product Details",
      child: Center(
        child: Text("Product Details"),
      ),
    );
  }
}