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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
        home: Scaffold(
      body: FireMap(),
    ));
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
              title: "Me (${newLocation.latitude}, ${newLocation.longitude})"),
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
        print("location Subscription Triggered : ${newLocation}");
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
    GeoFirePoint point = geo.point(
        latitude: newLocation.latitude, longitude: newLocation.longitude);
    return firestore
        .collection('users')
        .doc('admin')
        .update({'lastKnownPosition': point.geoPoint});
  }

  /// Returns Marker object with location, id and userName params
  ///
  /// GeoPoint loc holds GPS co-ords for marker location
  /// @TODO use id to assign custom color
  /// Marker Icontext is set to userName
  Marker buildNeightbourMarker(LatLng newPt, String userName) {
    return Marker(
        icon: _markersBitmap[_neighbourPolylineColor[userName]],
        markerId: MarkerId("$userName marker"),
        position: newPt,
        draggable: false,
        infoWindow: InfoWindow(
            title: "$userName (${newPt.latitude}, ${newPt.longitude})"),
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

  /// Gets user lastknownlocation from firebase and updates Neighbour HashMap
  void setNeighboursViz(int id, String user) async {
    if (user == "admin") return;
    print("Added $user Marker");
    DocumentSnapshot userData =
        await firestore.collection('users').doc(user).get();
    GeoPoint loc = userData.data()['lastKnownPosition'];
    setState(() {
      var newPt = LatLng(
        loc.latitude,
        loc.longitude,
      );
      var flag = !_neighboursPolyline.containsKey(user);
      if (flag) {
        _neighbourPolylineColor[user] =
            _markerColorCodes[_markerIconsList[id % 4]];
        print(_neighbourPolylineColor);
      }
      _neighbours[user] = buildNeightbourMarker(newPt, user);

      if (flag) {
        _neighboursPolyline[user] = [];
        _neighboursPolyline[user].add(newPt);
      } else if (_neighboursPolyline[user].last != newPt) {
        _neighboursPolyline[user].add(newPt);
      }
    });
  }

  /// Gets users groupsMembers and calls setNeighboursViz on them
  void getGroupMembers(String group) async {
    DocumentSnapshot userList =
        await firestore.collection('Groups').doc(group).get();
    userList
        .data()["users"]
        .asMap()
        .forEach((id, user) => {setNeighboursViz(id, user)});
  }

  /// Gets users groups to set neighbour markers
  Future<void> setGroupMarkers() async {
    DocumentSnapshot userInfo =
        await firestore.collection('users').doc('admin').get();
    userInfo.data()["userGroups"].forEach((group) => {getGroupMembers(group)});
  }

  /// Converts Neighbours HashMap values into Set to populate google map
  void setNeighbourMarkerSet() {
    setState(() {
      _neighbourSet = {};
      _neighbourPolylineSet = {};
    });
    _neighbours.forEach((k, v) => setState(() {
          _neighbourSet.add(v);
        }));
    _neighboursPolyline.forEach((k, v) => setState(() {
          _neighbourPolylineSet.add(buildNeighboutPolyline(v, k));
        }));
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
      // appBar: AppBar(
      //   title: Text("MCC"),
      // ),
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
