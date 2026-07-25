import 'package:flutter/material.dart';

class MasterScreen extends StatefulWidget {
  const MasterScreen({super.key, required this.child, required this.title});
  final Widget child;
  final String title;

  @override
  State<MasterScreen> createState() => _MasterScreenState();
}

class _MasterScreenState extends State<MasterScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
            title: Text('Master Screen'),
        ),
        drawer: Drawer(
            child: ListView(
                children: [
                    ListTile(title: Text('Back'), onTap: () {
                        Navigator.pop(context);
                        Navigator.pop(context);
                    },),
                    ListTile(title: Text('Products'), onTap: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProductListScreen()));
                    },),
                    ListTile(title: Text('Product details'), onTap: () {
                        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => ProductDetailsScreen()));
                    },)
                ],
            ),
        ),
        body: widget.child
    );
  }
}