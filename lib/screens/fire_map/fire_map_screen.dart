import 'package:flutter/material.dart';
import 'package:tracking/main.dart';
import '../../size_config.dart';

class FireMapScreen extends StatelessWidget {
  static String routeName = "/fire_map";
  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return Scaffold(
      body: FireMap(),
    );
  }
}
