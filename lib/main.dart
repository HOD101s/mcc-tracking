import 'dart:async';
import 'package:flutter/material.dart';
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
  Marker marker;
  Map<String, Marker> _neighbours = {};
  Set<Marker> _neightbourSet = {};
  Location _locationTracker = Location();

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
      marker = Marker(
          markerId: MarkerId("gpsLocation"),
          position: LatLng(
            newLocation.latitude,
            newLocation.longitude,
          ),
          draggable: false,
          infoWindow: InfoWindow(
              title: "Me (${newLocation.latitude}, ${newLocation.longitude})"),
          zIndex: 2);
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
  Marker buildNeightbourMarker(GeoPoint loc, int id, String userName) {
    return Marker(
        markerId: MarkerId("$userName marker"),
        position: LatLng(
          loc.latitude,
          loc.longitude,
        ),
        draggable: false,
        infoWindow:
            InfoWindow(title: "$userName (${loc.latitude}, ${loc.longitude})"),
        zIndex: 2);
  }

  /// Gets user lastknownlocation from firebase and updates Neighbour HashMap
  void setNeighboursMap(int id, String user) async {
    if (user == "admin") return;
    print("Added $user Marker");
    DocumentSnapshot userData =
        await firestore.collection('users').doc(user).get();
    GeoPoint loc = userData.data()['lastKnownPosition'];
    setState(() {
      _neighbours[user] = buildNeightbourMarker(loc, id, user);
    });
  }

  /// Gets users groupsMembers and calls setNeighboursMap on them
  void getGroupMembers(String group) async {
    DocumentSnapshot userList =
        await firestore.collection('Groups').doc(group).get();
    userList
        .data()["users"]
        .asMap()
        .forEach((id, user) => {setNeighboursMap(id, user)});
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
      _neightbourSet = {};
    });
    _neighbours.forEach((k, v) => setState(() {
          _neightbourSet.add(v);
        }));
  }

  @override
  void initState() {
    super.initState();
    subscribeToUserLocation();
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
        markers: _neightbourSet.union(Set.of((marker != null) ? [marker] : [])),
        polylines: Set.of([
          Polyline(
            polylineId: PolylineId("User Polyline"),
            visible: true,
            width: 5,
            points: _polyline,
            color: Colors.blue,
          )
        ]),
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
