import 'package:flutter/material.dart';
import 'package:tracking/constants.dart';
import 'package:tracking/screens/fire_map/fire_map_screen.dart';
import 'package:tracking/screens/sign_in/components/user_form.dart';
import 'package:tracking/size_config.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_session/flutter_session.dart';

// This is the best practice
import '../components/sign_in_content.dart';
import '../../../components/default_button.dart';

// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await Firebase.initializeApp();
//   runApp(Body());
// }

FirebaseFirestore firestore = FirebaseFirestore.instance;

class Body extends StatefulWidget {
  @override
  _BodyState createState() => _BodyState();
}

class _BodyState extends State<Body> {
  var username;
  var groupname;
  int currentPage = 0;
  final userAlreadyExistsSnackBar = SnackBar(
    content: Text('User Already exists'),
    duration: Duration(seconds: 1),
  );
  final creatingGroupSnackBar = SnackBar(content: Text('Creating Group'));
  final joiningGroupSnackBar = SnackBar(content: Text('Joining Group'));
  List<Map<String, String>> splashData = [
    {
      "text": "Welcome to Track me!",
      "image": "assets/images/track_1.png",
      "title": "TRACK ME"
    },
    {
      "text":
          "We help people easily connect and track with your friends and family",
      "image": "assets/images/track_2.png",
      "title": "Track your family"
    },
    {
      "text": "Let's start with superfast onboarding!",
      "image": "assets/images/track_3.png",
      "title": "Track your friends"
    },
  ];

  void usernameCallback(formusername) {
    setState(() {
      username = formusername;
    });
  }

  void groupnameCallback(formgroupname) {
    setState(() {
      groupname = formgroupname;
    });
  }

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
                  title: splashData[index]['title'],
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
                    UserForm(usernameCallback, groupnameCallback),
                    DefaultButton(
                      text: "Start Tracking",
                      press: () async {
                        final fireGroup = await firestore
                            .collection('Groups')
                            .doc(groupname)
                            .get();
                        if (fireGroup.exists) {
                          final userInfo = await firestore
                              .collection('Groups/$groupname/users')
                              .doc(username)
                              .get();
                          if (userInfo.data() != null) {
                            Scaffold.of(context)
                                .showSnackBar(userAlreadyExistsSnackBar);
                          } else {
                            firestore
                                .collection('Groups/$groupname/users')
                                .doc(username)
                                .set({'lastKnownPosition': GeoPoint(0, 0)});
                            Scaffold.of(context)
                                .showSnackBar(joiningGroupSnackBar);
                          }
                        } else {
                          firestore
                              .collection('Groups/$groupname/users')
                              .doc(username)
                              .set({'lastKnownPosition': GeoPoint(0, 0)});
                          Scaffold.of(context)
                              .showSnackBar(creatingGroupSnackBar);
                        }
                        await FlutterSession().set("sessionUser", username);
                        await FlutterSession().set("sessionGroup", groupname);
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
