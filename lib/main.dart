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
  Location _locationTracker = Location();

  FirebaseFirestore firestore = FirebaseFirestore.instance;
  Geoflutterfire geo = Geoflutterfire();

  static final CameraPosition _initialPosition = const CameraPosition(
    target: LatLng(19.250, 72.855),
    zoom: 18,
  );

  CameraPosition _position = _initialPosition;

  // Updats Marker state
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
              title: "(${newLocation.latitude}, ${newLocation.longitude})"),
          zIndex: 2);
    });
  }

  void zoomToCurrentPosition() async {
    var location = await _locationTracker.getLocation();
    updateLocationMarker(location);
    _mapController.animateCamera(CameraUpdate.newCameraPosition(
        new CameraPosition(
            target: LatLng(location.latitude, location.longitude), zoom: 18)));
  }

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
      }
    });
  }

  Future<void> updateFirestoreLocation(LocationData newLocation) async {
    GeoFirePoint point = geo.point(
        latitude: newLocation.latitude, longitude: newLocation.longitude);
    return firestore
        .collection('users')
        .doc('admin')
        .update({'lastKnownPosition': point.data});
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
        markers: Set.of((marker != null) ? [marker] : []),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => zoomToCurrentPosition(),
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
