import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:geolocator/geolocator.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:exif/exif.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:image/image.dart' as img;

Future<void> _requestPermissions() async {
  await [
    Permission.camera,
    Permission.locationWhenInUse,
  ].request();
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _requestPermissions();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a purple toolbar. Then, without quitting the app,
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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

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
  final int _counter = 0;

  final GeolocatorPlatform _geolocatorPlatform = GeolocatorPlatform.instance;

  CameraController? controller;
  List<CameraDescription>? _cameras;

  Future<void> intializeCameras() async {
    _cameras = await availableCameras();

    controller = CameraController(_cameras![0], ResolutionPreset.max);
    controller?.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            // Handle access errors here.
            break;
          default:
            // Handle other errors here.
            break;
        }
      }
    });
  }

  @override
  void initState() {
    super.initState();
    intializeCameras();
  }

  String? imagePath;

  Future<void> _confirmPhoto() async {
    // Handle the confirmed photo (e.g., upload or save permanently)
    if (imagePath != null) {
      await extractAndSendMetadata(imagePath!);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final CameraController cameraController = controller!;

    // App state changed before we got the chance to initialize.
    if (!cameraController.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      cameraController.dispose();
    } else if (state == AppLifecycleState.resumed) {
      intializeCameras();
    }
  }

  void _discardPhoto() {
    // Handle the discarded photo (e.g., delete the file)
    if (imagePath != null) {
      final file = File(imagePath!);
      if (file.existsSync()) {
        file.deleteSync();
      }
    }
    setState(() {
      imagePath = null;
    });
  }

  Future<void> takePhoto() async {
    if (controller != null && controller!.value.isInitialized) {
      try {
        final XFile picture = await controller!.takePicture();
        await getLocation();
        await _addLocationToImage(picture.path);
        setState(() {
          print('Photo taken: ${picture.path}');
          imagePath = picture.path;
        });
        print('asdafasdfasndfolasndofna');
      } catch (e) {
        print('Error taking photo: $e');
        // Handle photo capture error
        showPhotoErrorDialog();
      }
    }
  }

  void showPhotoErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Photo Error'),
        content: const Text('An error occurred while taking the photo. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> initializeCameras() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isNotEmpty) {
        controller = CameraController(
          cameras.first,
          ResolutionPreset.high,
        );
        await controller?.initialize();
      }
    } catch (e) {
      print('Error initializing camera: $e');
      showCameraErrorDialog();
    }
  }

  void showCameraErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Camera Error'),
        content: const Text('An error occurred while initializing the camera. Please try again.'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              initializeCameras();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  Future<void> sendToServer(File imageFile, double lat, double lon) async {
    var uri = Uri.parse('https://your-server-endpoint.com/upload');
    var request = http.MultipartRequest('POST', uri)
      ..fields['latitude'] = lat.toString()
      ..fields['longitude'] = lon.toString()
      ..files.add(await http.MultipartFile.fromPath('image', imageFile.path));
    var response = await request.send();
    if (response.statusCode == 200) {
      print('Upload successful');
    } else {
      print('Upload failed with status: ${response.statusCode}');
    }
  }

  double convertDMSToDD(IfdTag? dms, IfdTag? ref) {
    if (dms == null || ref == null) return 0.0;
    List<String> dmsList = dms.printable.split(',');
    double degrees = double.parse(dmsList[0].split('/')[0]) / double.parse(dmsList[0].split('/')[1]);
    double minutes = double.parse(dmsList[1].split('/')[0]) / double.parse(dmsList[1].split('/')[1]);
    double seconds = double.parse(dmsList[2].split('/')[0]) / double.parse(dmsList[2].split('/')[1]);
    double dd = degrees + (minutes / 60) + (seconds / 3600);
    if (ref.printable.contains('S') || ref.printable.contains('W')) {
      dd = -dd;
    }
    return dd;
  }

  Position? currentLocation;

  Future<void> getLocation() async {
    Position position = await _geolocatorPlatform.getCurrentPosition();
    currentLocation = position;
  }

  Future<void> extractAndSendMetadata(String imagePath) async {
    try {
      File imageFile = File(imagePath);
      List<int> bytes = await imageFile.readAsBytes();
      Map<String, IfdTag> data = await readExifFromBytes(bytes);
      print(data);
      if (data.isNotEmpty && currentLocation != null) {
        double lat = currentLocation!.latitude;
        double lon = currentLocation!.longitude;
        // var lat = convertDMSToDD(data['GPS GPSLatitude'], data['GPS GPSLatitudeRef']);
        // var lon = convertDMSToDD(data['GPS GPSLongitude'], data['GPS GPSLongitudeRef']);
        print('Latitude: $lat, Longitude: $lon');
        await sendToServer(imageFile, lat, lon);
      } else {
        print('No EXIF data found');
      }
    } catch (e) {
      print('Error extracting EXIF data: $e');
    }
  }

  List<String> _decimalToDMS(double decimal) {
    final degrees = decimal.abs().floor();
    final minutes = ((decimal.abs() - degrees) * 60).floor();
    final seconds = (((decimal.abs() - degrees) * 60 - minutes) * 60).round();

    return [
      '$degrees/1',
      '$minutes/1',
      '$seconds/1',
    ];
  }

  Future<void> _addLocationToImage(String imagePath) async {
    if (currentLocation == null) {
      print('No location data available');
      return;
    }

    // Read the existing EXIF data
    File imageFile = File(imagePath);
    Uint8List bytes = await imageFile.readAsBytes();
    img.Image? image = img.decodeImage(bytes);

    if (image == null) {
      print('Error reading image');
      return;
    }

    final exifData = await readExifFromBytes(bytes);
    // Add GPS data to the EXIF data
    final gpsLatitude = _decimalToDMS(currentLocation!.latitude);
    final gpsLongitude = _decimalToDMS(currentLocation!.longitude);

    exifData['GPS GPSLatitude'] = IfdTag(
      tag: 0x0002,
      tagType: 'RATIONAL',
      printable: gpsLatitude.join(', '),
      values: IfdRatios(gpsLatitude.map((v) => Ratio(int.parse(v.split('/')[0]), int.parse(v.split('/')[1]))).toList()),
    );

    exifData['GPS GPSLongitude'] = IfdTag(
      tag: 0x0004,
      tagType: 'RATIONAL',
      printable: gpsLongitude.join(', '),
      values:
          IfdRatios(gpsLongitude.map((v) => Ratio(int.parse(v.split('/')[0]), int.parse(v.split('/')[1]))).toList()),
    );

    exifData['GPS GPSLatitudeRef'] = IfdTag(
      tag: 0x0001,
      tagType: 'ASCII',
      printable: currentLocation!.latitude >= 0 ? 'N' : 'S',
      values: IfdInts([currentLocation!.latitude >= 0 ? 78 : 83]), // ASCII for 'N' and 'S'
    );

    exifData['GPS GPSLongitudeRef'] = IfdTag(
      tag: 0x0003,
      tagType: 'ASCII',
      printable: currentLocation!.longitude >= 0 ? 'E' : 'W',
      values: IfdInts([currentLocation!.longitude >= 0 ? 69 : 87]), // ASCII for 'E' and 'W'
    );

    // Write the updated EXIF data back to the image
    final updatedBytes = img.encodeJpg(image);
    await imageFile.writeAsBytes(updatedBytes);
  }

  @override
  Widget build(BuildContext context) {
    print('imgae path');
    print(imagePath);
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: (controller?.value.isInitialized ?? false) && imagePath == null
                ? CameraPreview(controller!)
                : imagePath != null
                    ? Image.file(File(imagePath!))
                    : const Center(child: CircularProgressIndicator()),
          ),
          if (imagePath == null)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30.0), // Add some padding if desired
                child: SizedBox(
                  width: 90.0, // Set the desired width
                  height: 90.0, // Set the desired height
                  child: FloatingActionButton(
                    backgroundColor: Colors.grey[500],
                    shape: const CircleBorder(eccentricity: 0.8),
                    onPressed: takePhoto,
                    tooltip: 'Camera',
                    child: Icon(size: 60, Icons.camera, color: Colors.grey[100]), // Use camera icon
                  ),
                ),
              ),
            )
          else
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 30.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      iconSize: 60,
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: _confirmPhoto,
                    ),
                    const SizedBox(width: 20),
                    IconButton(
                      iconSize: 60,
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: _discardPhoto,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
