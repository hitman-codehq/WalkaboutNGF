import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'photo_manager.dart';

void main() async {
  // Ensure that plugin services are initialized so that `availableCameras()`
  // can be called before `runApp()`
  WidgetsFlutterBinding.ensureInitialized();

  // Obtain a list of the available cameras on the device.
  final cameras = await availableCameras();

  // Get a specific camera from the list of available cameras.
  final firstCamera = cameras.first;

  runApp(/*const*/ MyApp(camera: firstCamera));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, required /*CameraDescription*/ this.camera});

  final CameraDescription camera;

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorSchemeSeed: Colors.green[700],
        useMaterial3: true,
      ),
      home: /*const*/ MyHomePage(title: 'Maps Sample App', camera: camera),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title, required this.camera});

  final CameraDescription camera;

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  late BitmapDescriptor customIcon;
  late GoogleMapController mapController;
  StreamSubscription<Position>? _positionStreamSubscription;
  bool _isTracking = false;

  final LatLng _center = const LatLng(-27.242426, 153.016637);
  final Map<String, Marker> _markers = {};

  // @date Tuesday 19-Aug-2025 11:07 am, Blu Shaak Coffee Paledecz, Haeundae Beach, Busan, South Korea

  Future<BitmapDescriptor> _getCustomMarkerIcon() async {
    try {
      // Load the custom marker image from assets
      final ByteData byteData = await rootBundle.load('assets/location.png');
      final Uint8List bytes = byteData.buffer.asUint8List();

      // Create a bitmap descriptor from the loaded bytes
      return BitmapDescriptor.fromBytes(bytes, size: const Size(16, 16));
    } catch (e) {
      debugPrint('Error loading custom marker: $e');

      // Fall back to default marker if there's an error
      return BitmapDescriptor.defaultMarker;
    }
  }

  /// Start positioning and determine the current position of the device.
  ///
  /// This function should be called at startup, to set up location services and to determine the current
  /// position of the device.
  ///
  /// If the location services are not enabled or permissions are denied, the function will return an error.
  ///
  /// @date	Saturday 20-Apr-2024 1:40 pm, Starbucks Odaiba
  /// @return	  The position of the device, if successful, else an error
  ///

  Future<Position> _startPositioning() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Test if location services are enabled.
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are not enabled don't continue
      // accessing the position and request users of the
      // App to enable the location services.
      return Future.error('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permissions are denied, next time you could try
        // requesting permissions again (this is also where
        // Android's shouldShowRequestPermissionRationale
        // returned true. According to Android guidelines
        // your App should show an explanatory UI now.
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == LocationPermission.deniedForever) {
      // Permissions are denied forever, handle appropriately.
      return Future.error('Location permissions are permanently denied, we cannot request permissions.');
    }

    // When we reach here, permissions are granted and we can
    // continue accessing the position of the device.
    return await Geolocator.getCurrentPosition();
  }

  /// Update the map and the location marker to the given position
  ///
  /// This function is called either when the position of the device changes, or when the user wishes to
  /// move the map to a given position, such as centring on the current position or a PoI.
  ///
  /// @date Tuesday 19-Aug-2025 4:02 pm
  /// @param  position The position to which to move the map
  /// @return An empty Future is returned, to enable asynchronous updating
  ///

  Future<void> _updatePosition(Position position) async {
    final newLatLng = LatLng(position.latitude, position.longitude);

    // Update camera position to the new latitude and longitude
    mapController.animateCamera(CameraUpdate.newCameraPosition(CameraPosition(target: newLatLng, zoom: 17)));

    setState(() {
      _markers['MyLocation'] = Marker(
        markerId: const MarkerId('MyLocation'),
        position: newLatLng,
        infoWindow: InfoWindow(
          title: 'My Location',
          snippet: '${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)}',
        ),
        icon: customIcon,
      );
    });
  }

  Future<void> _onMapCreated(GoogleMapController controller) async {
    mapController = controller;

    customIcon = await _getCustomMarkerIcon();

    // Initialise location subsystem and get the initial position
    try {
      final _ = await _startPositioning();
      _startTracking();
    } catch (e) {
      debugPrint('Error getting location: $e');
    }
  }

  // @date Tuesday 19-Aug-2025 4:02 pm
  @override
  void dispose() {
    _positionStreamSubscription?.cancel();
    mapController.dispose();
    super.dispose();
  }

  /// Start tracking the user's position.
  ///
  /// Sets up the location subsystem to listen for position updates and, when received, calls _updatePosition()
  /// to move the map and position marker to the new position.
  ///
  /// @date Tuesday 19-Aug-2025 4:02 pm
  ///

  void _startTracking() {
    if (_isTracking) return;

    _isTracking = true;

    // Use high accuracy and update every 5 metres
    const locationSettings = LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 5);

    // Rather than just getting the current position, listen to a stream of position updates, so that
    // we can update the map as the device moves
    _positionStreamSubscription = Geolocator.getPositionStream(locationSettings: locationSettings).listen((
      Position? position,
    ) {
      if (position != null) {
        _updatePosition(position);
      }
    });
  }

  // Method kept for future use if needed
  // @date Tuesday 19-Aug-2025 4:02 pm
  // void _stopTracking() {
  //   _positionStreamSubscription?.cancel();
  //   _isTracking = false;
  // }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
        elevation: 2,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Expanded(
            child: GoogleMap(
              onMapCreated: _onMapCreated,
              initialCameraPosition: CameraPosition(target: _center, zoom: 11.0),
              markers: _markers.values.toSet(),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.camera_alt),
        onPressed: () => {
          Navigator.push(context, MaterialPageRoute(builder: (context) => TakePictureScreen(camera: widget.camera))),
        },
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.startFloat,
    );
  }
}

// A screen that allows users to take a picture using a given camera.
class TakePictureScreen extends StatefulWidget {
  const TakePictureScreen({super.key, required this.camera});

  final CameraDescription camera;

  @override
  TakePictureScreenState createState() => TakePictureScreenState();
}

class TakePictureScreenState extends State<TakePictureScreen> {
  late CameraController _controller;
  late Future<void> _initialiseControllerFuture;

  @override
  void initState() {
    super.initState();
    // To display the current output from the Camera,
    // create a CameraController.
    _controller = CameraController(
      // Get a specific camera from the list of available cameras.
      widget.camera,
      // Define the resolution to use.
      ResolutionPreset.high,
    );

    // Next, initialize the controller. This returns a Future.
    _initialiseControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    // Dispose of the controller when the widget is disposed.
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Take a picture')),
      // You must wait until the controller is initialized before displaying the
      // camera preview. Use a FutureBuilder to display a loading spinner until the
      // controller has finished initializing.
      body: FutureBuilder<void>(
        future: _initialiseControllerFuture,
        builder: (context, snapsthot) {
          if (snapsthot.connectionState == ConnectionState.done) {
            // If the Future is complete, display the preview.
            return CameraPreview(_controller);
          } else {
            // Otherwise, display a loading indicator.
            return const Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: FloatingActionButton(
        // Provide an onPressed callback.
        onPressed: () async {
          final navigator = Navigator.of(context);

          // Take the Picture in a try / catch block. If anything goes wrong,
          // catch the error.
          try {
            // Ensure that the camera is initialized.
            await _initialiseControllerFuture;

            // Attempt to take a picture and then get the location
            // where the image file is saved.
            final image = await _controller.takePicture();

            late final Uint8List imageData;

            if (kIsWeb) {
              try {
                final response = await http.get(Uri.parse(image.path));

                if (response.statusCode == 200) {
                  imageData = response.bodyBytes;
                  savePhoto(imageData);
                } else {
                  debugPrint("Failed to fetch image data. Status code: ${response.statusCode}");
                }
              } catch (e) {
                debugPrint("Error fetching blob data: $e");

                return;
              }
            } else {
              imageData = await File(image.path).readAsBytes();
              savePhoto(imageData);
            }

            if (!mounted) return;

            await navigator.push(MaterialPageRoute(builder: (context) => DisplayPictureScreen(imageData: imageData)));
          } catch (e) {
            // If an error occurs, log the error to the console.
            debugPrint(e.toString());
          }
        },
        child: const Icon(Icons.camera_alt),
      ),
    );
  }
}

// A widget that displays the picture taken by the user.
class DisplayPictureScreen extends StatelessWidget {
  final Uint8List imageData;

  const DisplayPictureScreen({super.key, required this.imageData});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Display the picture')),
      body: Image.memory(imageData),
    );
  }
}
