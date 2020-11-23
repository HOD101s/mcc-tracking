import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geoflutterfire/geoflutterfire.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tracking/routes.dart';
import 'package:tracking/screens/sign_in/sign_in_screen.dart';
import 'package:flutter_session/flutter_session.dart';
import 'constants.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: "TRACK ME",
      initialRoute: SignInScreen.routeName,
      routes: routes,
    );
  }
}

class FireMap extends StatefulWidget {
  State createState() => FireMapState();
}

class FireMapState extends State<FireMap> {
  GoogleMapController _mapController;
  StreamSubscription _locationSubscription;
  Marker userMarker; // users location
  Map<String, Marker> _neighbours = {};
  Set<Marker> _neighbourSet = {};
  Location _locationTracker = Location();

  List<String> _markerIconsList = [
    "blue",
    "yellow",
    "green",
    "purple",
    "lightblue",
  ];

  Map<String, String> _markerColorCodes = {
    "lightblue": "#3ee3e6",
    "purple": "#c84bde",
    "yellow": "#F4B400",
    "red": "#DB4437",
    "blue": "#4285F4",
    "green": "#0F9D58",
  };

  Map<String, BitmapDescriptor> _markersBitmap = {};

  Map<String, List<LatLng>> _neighboursPolyline = {};
  Map<String, String> _neighbourPolylineColor = {};
  Set<Polyline> _neighbourPolylineSet = {};

  FirebaseFirestore firestore = FirebaseFirestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  final List<LatLng> _polyline = [];

  List<Widget> groupMembers = [];

  String sessionUser;
  String sessionGroup;

  setSession() async {
    var userName = await FlutterSession().get("sessionUser");
    var groupName = await FlutterSession().get("sessionGroup");
    setState(() {
      sessionUser = userName;
      sessionGroup = groupName;
    });
  }

  static final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(19.250, 72.855),
    zoom: 18,
  );

  CameraPosition _position = _initialPosition;

  /// Updates User Marker state
  void updateLocationMarker(LocationData newLocation) {
    this.setState(() {
      userMarker = Marker(
          markerId: MarkerId("userLocation"),
          position: LatLng(
            newLocation.latitude,
            newLocation.longitude,
          ),
          draggable: false,
          infoWindow: InfoWindow(
              title:
                  "Me (${newLocation.latitude.toStringAsFixed(4)}, ${newLocation.longitude.toStringAsFixed(4)})"),
          zIndex: 3);
    });
  }

  /// Zooms Map to Location
  ///
  /// set named parameter {current = true} to zoom to users current location
  /// or pass custom location to zoom map to
  void zoomToPosition(LocationData location, {bool current = false}) async {
    if (current) {
      location = await _locationTracker.getLocation();
    }
    updateLocationMarker(location);
    _mapController.animateCamera(CameraUpdate.newCameraPosition(
        new CameraPosition(
            target: LatLng(location.latitude, location.longitude), zoom: 18)));
  }

  /// Subscriber to auto update user location via GPS
  void subscribeToUserLocation() async {
    if (_locationSubscription != null) {
      _locationSubscription.cancel();
    }
    _locationSubscription =
        _locationTracker.onLocationChanged().listen((newLocation) {
      if (_mapController != null) {
        print("location Subscription Triggered : $newLocation");
        updateLocationMarker(newLocation);
        updateFirestoreLocation(newLocation);
        updatePolyline(newLocation);
        setGroupMarkers();
        setNeighbourMarkerSet();
      }
    });
  }

  /// Updates users movement polyline state variable
  updatePolyline(LocationData newLocation) {
    setState(() {
      _polyline.add(LatLng(newLocation.latitude, newLocation.longitude));
    });
  }

  /// Updates users current location in firebase
  Future<void> updateFirestoreLocation(LocationData newLocation) async {
    print("### SESSION $sessionUser $sessionGroup");
    GeoFirePoint point = geo.point(
        latitude: newLocation.latitude, longitude: newLocation.longitude);
    return firestore
        .collection('Groups/$sessionGroup/users')
        .doc(sessionUser)
        .update({'lastKnownPosition': point.geoPoint});
  }

  /// Returns Marker object with location, id and userName params
  ///
  /// GeoPoint loc holds GPS co-ords for marker location
  /// @TODO use id to assign custom color
  /// Marker Icontext is set to userName
  Marker buildNeighbourMarker(LatLng newPt, String userName) {
    return Marker(
        icon: _markersBitmap[_neighbourPolylineColor[userName]],
        markerId: MarkerId("$userName marker"),
        position: newPt,
        draggable: false,
        infoWindow: InfoWindow(
            title:
                "$userName (${newPt.latitude.toStringAsFixed(4)}, ${newPt.longitude.toStringAsFixed(4)})"),
        zIndex: 2);
  }

  Color hexToColor(String hexString, {String alphaChannel = 'FF'}) {
    if (hexString == null) return Colors.blue;
    return Color(int.parse(hexString.replaceFirst('#', '0x$alphaChannel')));
  }

  Polyline buildNeighboutPolyline(List<LatLng> polylinePoints, String user) {
    return Polyline(
      polylineId: PolylineId("$user Polyline"),
      visible: true,
      width: 8,
      points: polylinePoints,
      color: hexToColor(_neighbourPolylineColor[user]),
    );
  }

  /// Updates Neighbour location and polyline information
  void setNeighboursViz(int id, String user, GeoPoint loc) async {
    if (user == sessionUser) return;
    print("Added $user Marker");
    setState(() {
      var newPt = LatLng(
        loc.latitude,
        loc.longitude,
      );
      var flag = !_neighboursPolyline.containsKey(user);
      if (flag) {
        _neighbourPolylineColor[user] =
            _markerColorCodes[_markerIconsList[id % 4]];
        groupMembers
            .add(ListTile(leading: Icon(Icons.group), title: Text(user)));
        _neighboursPolyline[user] = [];
        // _neighboursPolyline[user].add(newPt);
        // _neighbours[user] = buildNeighbourMarker(newPt, user);
      }
      if ((_neighboursPolyline[user].length == 0 && newPt != LatLng(0, 0)) ||
          _neighboursPolyline[user].last != newPt) {
        _neighboursPolyline[user].add(newPt);
        _neighbours[user] = buildNeighbourMarker(newPt, user);
      }
    });
  }

  /// Gets users to set neighbour markers
  Future<void> setGroupMarkers() async {
    await firestore
        .collection('Groups')
        .doc(sessionGroup)
        .collection('users')
        .get()
        .then((value) => value.docs.asMap().forEach((id, element) {
              setNeighboursViz(id, element.id, element['lastKnownPosition']);
            }));
  }

  /// Converts Neighbours HashMap values into Set to populate google map
  void setNeighbourMarkerSet() {
    Set<Marker> _neighbourSetTemp = {};
    Set<Polyline> _neighbourPolylineSetTemp = {};

    _neighbours.forEach((k, v) => _neighbourSetTemp.add(v));
    _neighboursPolyline.forEach(
        (k, v) => _neighbourPolylineSetTemp.add(buildNeighboutPolyline(v, k)));

    setState(() {
      _neighbourSet = _neighbourSetTemp;
      _neighbourPolylineSet = _neighbourPolylineSetTemp;
    });
  }

  Future<Uint8List> getBytesFromAsset(String path, int width) async {
    ByteData data = await rootBundle.load(path);
    ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(),
        targetWidth: width);
    ui.FrameInfo fi = await codec.getNextFrame();
    return (await fi.image.toByteData(format: ui.ImageByteFormat.png))
        .buffer
        .asUint8List();
  }

  /// Initialize various marker Icons into a list
  buildMarkerIcons() {
    setState(() {
      _markerIconsList.forEach((color) async {
        _markersBitmap[_markerColorCodes[color]] = BitmapDescriptor.fromBytes(
            await getBytesFromAsset("assets/markerIcons/$color.png", 55));
      });
    });
  }

  @override
  void initState() {
    super.initState();
    setSession();
    subscribeToUserLocation();
    buildMarkerIcons();
  }

  @override
  void dispose() {
    if (_locationSubscription != null) {
      _locationSubscription.cancel();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Track Me"),
        backgroundColor: kPrimaryColor,
      ),
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            DrawerHeader(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                        child: Text(
                      'Track Me',
                      style: TextStyle(color: kPrimaryLightColor, fontSize: 50),
                    )),
                    Container(
                        child: Text(
                      sessionGroup,
                      style: TextStyle(color: kTextColor, fontSize: 50),
                    ))
                  ]),
              decoration: BoxDecoration(
                color: kPrimaryColor,
              ),
            ),
            ListTile(
                leading: Icon(Icons.person),
                title: Text(
                  sessionUser,
                )),

            /// list of username ListTiles
            ...groupMembers,
          ],
        ),
      ),
      body: GoogleMap(
        initialCameraPosition: _position,
        onMapCreated: _onMapCreated,
        myLocationButtonEnabled: false,
        myLocationEnabled: false,
        zoomControlsEnabled: false,
        mapType: MapType.normal,
        compassEnabled: true,
        onCameraMove: _updateCameraPosition,
        markers: _neighbourSet
            .union(Set.of((userMarker != null) ? [userMarker] : [])),
        polylines: _neighbourPolylineSet.union(Set.of([
          Polyline(
            polylineId: PolylineId("User Polyline"),
            visible: true,
            width: 8,
            points: _polyline,
            color: Colors.blue,
          )
        ])),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => zoomToPosition(null, current: true),
        child: Icon(Icons.location_searching),
      ),
    );
  }

  _onMapCreated(GoogleMapController controller) {
    setState(() {
      _mapController = controller;
    });
  }

  _updateCameraPosition(CameraPosition position) {
    setState(() {
      _position = position;
    });
  }
}
