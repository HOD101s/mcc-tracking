import 'package:flutter/widgets.dart';
import 'package:tracking/screens/fire_map/fire_map_screen.dart';
import 'package:tracking/screens/sign_in/sign_in_screen.dart';

// We use name route
// All our routes will be available here
final Map<String, WidgetBuilder> routes = {
  SignInScreen.routeName: (context) => SignInScreen(),
  FireMapScreen.routeName: (context) => FireMapScreen(),
};
