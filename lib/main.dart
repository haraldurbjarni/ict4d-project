import 'dart:io';

import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';

void main() {
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

  void _confirmPhoto() {
    // Handle the confirmed photo (e.g., upload or save permanently)
    print('Photo confirmed: $imagePath');
    setState(() {
      imagePath = null;
    });
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

  Future<void> _takePhoto() async {
    if (controller != null && controller!.value.isInitialized) {
      try {
        final XFile picture = await controller!.takePicture();
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
                    backgroundColor: Colors.grey[600],
                    shape: const CircleBorder(eccentricity: 0.8),
                    onPressed: _takePhoto,
                    tooltip: 'Camera',
                    child: Icon(size: 60, Icons.camera, color: Colors.grey[400]), // Use camera icon
                  ),
                ),
              ),
            ),
          if (imagePath != null)
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
