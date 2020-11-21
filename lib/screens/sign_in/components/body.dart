import 'package:flutter/material.dart';
import 'package:tracking/constants.dart';
import 'package:tracking/screens/fire_map/fire_map_screen.dart';
import 'package:tracking/screens/sign_in/components/user_form.dart';
import 'package:tracking/size_config.dart';

// This is the best practice
import '../components/sign_in_content.dart';
import '../../../components/default_button.dart';

class Body extends StatefulWidget {
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  int currentPage = 0;
  List<Map<String, String>> splashData = [
    {"text": "Welcome to Track me!", "image": "assets/images/track_1.png"},
    {
      "text":
          "We help people easily connect and track with your friends and family",
      "image": "assets/images/track_2.png"
    },
    {
      "text": "Let's start with superfast onboarding!",
      "image": "assets/images/track_3.png"
    },
  ];
  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SizedBox(
        width: double.infinity,
        child: Column(
          children: <Widget>[
            Expanded(
              flex: 3,
              child: PageView.builder(
                onPageChanged: (value) {
                  setState(() {
                    currentPage = value;
                  });
                },
                itemCount: splashData.length,
                itemBuilder: (context, index) => SignInContent(
                  image: splashData[index]["image"],
                  text: splashData[index]['text'],
                ),
              ),
            ),
            Expanded(
              flex: 2,
              child: Padding(
                padding: EdgeInsets.symmetric(
                    horizontal: getProportionateScreenWidth(20)),
                child: Column(
                  children: <Widget>[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        splashData.length,
                        (index) => buildDot(index: index),
                      ),
                    ),
                    UserForm(),
                    DefaultButton(
                      text: "Continue",
                      press: () {
                        Navigator.pushNamedAndRemoveUntil(context,
                            FireMapScreen.routeName, ModalRoute.withName('/'));
                      },
                    ),
                    Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  AnimatedContainer buildDot({int index}) {
    return AnimatedContainer(
      duration: kAnimationDuration,
      margin: EdgeInsets.only(right: 5),
      height: 6,
      width: currentPage == index ? 20 : 6,
      decoration: BoxDecoration(
        color: currentPage == index ? kPrimaryColor : Color(0xFFD8D8D8),
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}