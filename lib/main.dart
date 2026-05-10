import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter/services.dart';

import 'src/rust/frb_generated.dart';
import 'screens/home_screen.dart';

late List<CameraDescription> cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight
  ]);
  await RustLib.init(); 
  cameras = await availableCameras();
  runApp(const MaterialApp(
    debugShowCheckedModeBanner: false, 
    home: HomeScreen() 
  ));
}