import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:typed_data'; 
import 'dart:math'; 

import '../main.dart';
import 'wait_screen.dart';

class Recognition { 
  final Rect rect; 
  final int classIndex; 
  final double score; 
  Recognition(this.rect, this.classIndex, this.score); 
}

class WaitScannerScreen extends StatefulWidget {
  const WaitScannerScreen({super.key});
  @override State<WaitScannerScreen> createState() => _WaitScannerScreenState();
}

class _WaitScannerScreenState extends State<WaitScannerScreen> {
  CameraController? controller; 
  Interpreter? interpreter; 
  IsolateInterpreter? isolateInterpreter; 
  
  bool isAppReady = false; 
  bool isProcessing = false; 
  bool isNavigating = false; 
  String resultText = "인식 준비 중..."; 

  late Float32List inputBufferFlat;
  late List<List<List<double>>> outputBuffer;
  int lastFrameTime = 0; 

  final List<String> tileNames = [
    '1m', '1p', '1s', '1z', '2m', '2p', '2s', '2z', '3m', '3p', '3s', '3z', 
    '4m', '4p', '4s', '4z', '5m', '5p', '5s', '5z', '6m', '6p', '6s', '6z', 
    '7m', '7p', '7s', '7z', '8m', '8p', '8s', '9m', '9p', '9s', '5mr', '5pr', '5sr', '0b'
  ];

  @override void initState() {
    super.initState();
    inputBufferFlat = Float32List(1 * 640 * 640 * 3);
    outputBuffer = List.generate(1, (_) => List.generate(42, (_) => List.generate(8400, (_) => 0.0)));
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      interpreter = await Interpreter.fromAsset('assets/best.tflite', options: InterpreterOptions()..threads = 4);
      isolateInterpreter = await IsolateInterpreter.create(address: interpreter!.address);
      
      controller = CameraController(cameras[0], ResolutionPreset.medium, enableAudio: false);
      await controller!.initialize();
      controller!.startImageStream((image) {
        if (!isAppReady || isNavigating || isProcessing || isolateInterpreter == null) return;
        int currentTime = DateTime.now().millisecondsSinceEpoch;
        if (currentTime - lastFrameTime < 200) return;
        lastFrameTime = currentTime;
        isProcessing = true; 
        _runInference(image);
      });

      if (mounted) setState(() { isAppReady = true; resultText = "스캔을 시작합니다! 패를 비춰주세요."; });
    } catch (e) {
      if (mounted) setState(() => resultText = "초기화 에러: $e");
    }
  }

  Future<void> _runInference(CameraImage image) async {
    try {
      _fillInputBufferFast(image); 
      var inputShape = [1, 640, 640, 3];
      var inputTensor = inputBufferFlat.buffer.asFloat32List().reshape(inputShape);
      await isolateInterpreter!.run(inputTensor, outputBuffer);
      
      List<Recognition> recognitions = [];
      var outData = outputBuffer[0]; 

      for (int i = 0; i < 8400; i++) {
        double maxScore = 0.0; int maxClass = -1;
        for (int c = 0; c < 38; c++) {
          double score = outData[c + 4][i];
          if (score > maxScore) { maxScore = score; maxClass = c; }
        }
        double threshold = 0.22; 
        if (maxClass != -1 && tileNames[maxClass] == '0b') threshold = 0.05; 

        if (maxScore > threshold) { 
          double cx = outData[0][i]; double cy = outData[1][i];
          double w = outData[2][i]; double h = outData[3][i];
          recognitions.add(Recognition(Rect.fromCenter(center: Offset(cx, cy), width: w, height: h), maxClass, maxScore));
        }
      }

      recognitions.sort((a, b) => b.score.compareTo(a.score));
      List<Recognition> finalBoxes = [];
      for (var rec in recognitions) {
        bool isOverlap = finalBoxes.any((b) => _calculateIoU(rec.rect, b.rect) > 0.45);
        bool isSamePosition = finalBoxes.any((b) {
            double dxDiff = (rec.rect.center.dx - b.rect.center.dx).abs();
            double dyDiff = (rec.rect.center.dy - b.rect.center.dy).abs();
            return dxDiff < rec.rect.width * 0.4 && dyDiff < rec.rect.height * 0.5;
        });
        if (!isOverlap && !isSamePosition) finalBoxes.add(rec); 
      }

      // 대기패 모드: 바닥패 무시 (위아래 30% 영역 제외)
      double topBound = 0.3;
      double bottomBound = 0.7;
      if (finalBoxes.isNotEmpty) {
        double maxDy = finalBoxes.map((b) => b.rect.center.dy).reduce(max);
        if (maxDy > 2.0) {
          topBound = 192.0; 
          bottomBound = 448.0; 
        }
      }
      List<Recognition> handBoxes = finalBoxes.where((b) => b.rect.center.dy >= topBound && b.rect.center.dy <= bottomBound).toList();
      handBoxes.sort((a, b) => a.rect.center.dx.compareTo(b.rect.center.dx));

      double avgWidth = 0;
      List<double> uprightWidths = [];
      for (var b in handBoxes) {
        if (b.rect.width / b.rect.height < 0.95) uprightWidths.add(b.rect.width);
      }
      if (uprightWidths.isNotEmpty) {
        uprightWidths.sort();
        avgWidth = uprightWidths[uprightWidths.length ~/ 2]; 
      } 

      List<int> rawSeq = [];
      List<bool> isSidewaysRaw = [];

      for (int i = 0; i < handBoxes.length; i++) {
        var b = handBoxes[i];
        int cls = b.classIndex;
        double ratio = b.rect.width / b.rect.height;
        
        // 대기패 모드: 가로/세로 비율 완전 무시, 무조건 세워진 패(멘젠)로 강제 처리!
        bool sideways = false;

        if (i > 0 && avgWidth > 0) {
          var prevB = handBoxes[i - 1];
          double gap = b.rect.left - prevB.rect.right;
          if (gap > avgWidth * 0.65) {
            int missingCount = (gap / avgWidth).round();
            for (int m = 0; m < missingCount; m++) {
              rawSeq.add(tileNames.indexOf('0b')); 
              isSidewaysRaw.add(false);
            }
          }
        }

        int count = 1;
        if (avgWidth > 0 && b.rect.width / avgWidth >= 1.75) { count = 2; } 
        else if (ratio >= 1.75) { count = 2; }

        for (int k = 0; k < count; k++) {
          rawSeq.add(cls);
          isSidewaysRaw.add(count == 1 ? sideways : false); 
        }
      }

      bool isPartOfNextAnkan(int idx) {
        if (idx + 3 >= rawSeq.length) return false;
        String t0 = tileNames[rawSeq[idx]]; String t1 = tileNames[rawSeq[idx+1]];
        String t2 = tileNames[rawSeq[idx+2]]; String t3 = tileNames[rawSeq[idx+3]];
        if (t0 == '0b' && t3 == '0b' && t1 == t2 && t1 != '0b') return true;
        if (t0 == '0b' && t1 == '0b' && t2 == '0b' && t3 == '0b') return true;
        return false;
      }

      List<int> seq = [];
      List<bool> isAnkan = [];
      List<bool> isSideways = [];

      int i = 0;
      while (i < rawSeq.length) {
        String s0 = i < rawSeq.length ? tileNames[rawSeq[i]] : '';
        String s1 = i + 1 < rawSeq.length ? tileNames[rawSeq[i+1]] : '';
        String s2 = i + 2 < rawSeq.length ? tileNames[rawSeq[i+2]] : '';
        String s3 = i + 3 < rawSeq.length ? tileNames[rawSeq[i+3]] : '';

        if (s0 == '0b' && s3 == '0b' && s1 == s2 && s1 != '0b' && s1 != '') { 
            int t = rawSeq[i+1]; seq.addAll([t, t, t, t]); isAnkan.addAll([true, true, true, true]); isSideways.addAll([false, false, false, false]); i += 4; continue;
        }
        if (s0 != '' && s0 == s1 && s1 == s2 && s2 == s3 && s0 != '0b') { 
            if (!isSidewaysRaw[i] && !isSidewaysRaw[i+1] && !isSidewaysRaw[i+2] && !isSidewaysRaw[i+3]) {
                int t = rawSeq[i]; seq.addAll([t, t, t, t]); isAnkan.addAll([true, true, true, true]); isSideways.addAll([false, false, false, false]); i += 4; continue;
            }
        }
        if (s0 == '0b' && s1 == '0b' && s2 == '0b' && s3 == '0b') { 
            int t = tileNames.indexOf('5z'); seq.addAll([t, t, t, t]); isAnkan.addAll([true, true, true, true]); isSideways.addAll([false, false, false, false]); i += 4; continue;
        }
        if (s2 == '0b' && s0 == s1 && s0 != '0b' && s0 != '') { 
            if (!isPartOfNextAnkan(i + 2)) { 
                int t = rawSeq[i]; seq.addAll([t, t, t, t]); isAnkan.addAll([true, true, true, true]); isSideways.addAll([false, false, false, false]); i += 3; continue;
            }
        }
        if (s0 == '0b' && s1 == s2 && s1 != '0b' && s1 != '') { 
            if (!isPartOfNextAnkan(i)) {
                int t = rawSeq[i+1]; seq.addAll([t, t, t, t]); isAnkan.addAll([true, true, true, true]); isSideways.addAll([false, false, false, false]); i += 3; continue;
            }
        }
        if (s0 == '0b' && s2 == '0b' && s1 != '0b' && s1 != '') { 
            if (!isPartOfNextAnkan(i) && !isPartOfNextAnkan(i + 2)) {
                int t = rawSeq[i+1]; seq.addAll([t, t, t, t]); isAnkan.addAll([true, true, true, true]); isSideways.addAll([false, false, false, false]); i += 3; continue;
            }
        }
        seq.add(rawSeq[i]);
        isAnkan.add(false);
        isSideways.add(isSidewaysRaw[i]);
        i++;
      }

      if (mounted && !isNavigating) {
        setState(() {
          String getTileDisplayName(int cls) {
            String name = tileNames[cls];
            if (name == '0b') return '뒷면';
            if (name == '5mr') return '0m';
            if (name == '5pr') return '0p';
            if (name == '5sr') return '0s';
            return name;
          }
          resultText = "🀄 내 패: ${seq.map(getTileDisplayName).join(', ')}";
        });
      }

      List<int> finalSeq = [];
      List<bool> finalIsAnkan = [];
      List<bool> finalIsSideways = [];

      for (int k = 0; k < seq.length; k++) {
        if (!isAnkan[k] && tileNames[seq[k]] == '0b') continue;
        finalSeq.add(seq[k]);
        finalIsAnkan.add(isAnkan[k]);
        finalIsSideways.add(isSideways[k]);
      }

      bool shouldNavigate = false;
      int len = finalSeq.length;
      // 🔥 안정화 로직 삭제됨! 13, 10, 7, 4, 1장 중 하나가 인식되면 즉각 반응합니다.
      if (len == 13 || len == 10 || len == 7 || len == 4 || len == 1) {
          shouldNavigate = true;
      }

      if (shouldNavigate && !isNavigating) {
        isNavigating = true; 
        List<int> encodedHandTiles = [];
        
        for (int j = 0; j < finalSeq.length; j++) {
          int cls = finalSeq[j];
          if (finalIsAnkan[j]) {
            encodedHandTiles.add(cls + 200); 
          } else {
            if (finalIsSideways[j]) {
              encodedHandTiles.add(cls + 100); 
            } else {
              encodedHandTiles.add(cls);
            }
          }
        }
        
        if(!mounted) {return;}
        await Navigator.push(context, MaterialPageRoute(builder: (context) => WaitResultScreen(
          handTiles: encodedHandTiles,
        )));
        
        if (mounted) {
          setState(() { resultText = "다시 스캔을 준비합니다..."; });
          Future.delayed(const Duration(milliseconds: 500), () {
            if (mounted) isNavigating = false; 
          });
        }
      }
    } catch (e) { debugPrint("추론 에러: $e"); } finally { isProcessing = false; }
  }

  double _calculateIoU(Rect a, Rect b) {
    var i = a.intersect(b);
    if (i.width <= 0 || i.height <= 0) return 0.0;
    return (i.width * i.height) / (a.width * a.height + b.width * b.height - i.width * i.height);
  }

  void _fillInputBufferFast(CameraImage image) {
    final int sw = image.width, sh = image.height, yRS = image.planes[0].bytesPerRow;
    final Uint8List yB = image.planes[0].bytes, uB = image.planes[1].bytes, vB = image.planes[2].bytes;
    int index = 0;
    for (int y = 0; y < 640; y++) {
      int sy = ((y * sh) ~/ 640).clamp(0, sh - 1);
      int py = sy * yRS, puv = (sy >> 1) * image.planes[1].bytesPerRow;
      for (int x = 0; x < 640; x++) {
        int sx = ((x * sw) ~/ 640).clamp(0, sw - 1);
        int yp = yB[py + sx], uvIdx = (sx >> 1) * (image.planes[1].bytesPerPixel ?? 1);
        int u = uB[puv + uvIdx] - 128; int v = vB[puv + uvIdx] - 128;
        double r = (yp + 1.402 * v).clamp(0, 255) / 255.0;
        double g = (yp - 0.344 * u - 0.714 * v).clamp(0, 255) / 255.0;
        double b = (yp + 1.772 * u).clamp(0, 255) / 255.0;
        inputBufferFlat[index++] = r; inputBufferFlat[index++] = g; inputBufferFlat[index++] = b;
      }
    }
  }

  @override Widget build(BuildContext context) {
    if (!isAppReady || controller == null || !controller!.value.isInitialized) {
      return const Scaffold(backgroundColor: Colors.black, body: Center(child: CircularProgressIndicator(color: Colors.greenAccent)));
    }
    
    return Scaffold(
      backgroundColor: Colors.black, 
      body: Stack(children: [
        SizedBox.expand(child: FittedBox(fit: BoxFit.cover, child: SizedBox(width: 100 * controller!.value.aspectRatio, height: 100, child: CameraPreview(controller!)))),
        
        Positioned.fill(child: Column(children: [
          Expanded(flex: 3, child: Container(color: Colors.black54)),
          Expanded(
            flex: 4, 
            child: Container(
              width: double.infinity,
              decoration: const BoxDecoration(
                border: Border(
                  top: BorderSide(color: Colors.greenAccent, width: 2),
                  bottom: BorderSide(color: Colors.greenAccent, width: 2),
                )
              ),
              child: const Align(
                alignment: Alignment.topLeft,
                child: Padding(
                  padding: EdgeInsets.only(left: 16.0, top: 8.0),
                  child: Text('이 구역에 패를 일렬로 맞추세요', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            )
          ),
          Expanded(flex: 3, child: Container(color: Colors.black54)),
        ])),
          
        Positioned(
          bottom: 20, left: 10, right: 10, 
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), 
            decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(12)), 
            child: Text(resultText, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, height: 1.5), textAlign: TextAlign.left)
          )
        ),
    ]));
  }
}