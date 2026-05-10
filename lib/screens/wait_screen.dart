import 'package:flutter/material.dart';
import '../src/rust/api/simple.dart';
import 'edit_screen.dart';

class WaitResultScreen extends StatefulWidget {
  final List<int> handTiles; 
  const WaitResultScreen({super.key, required this.handTiles});
  @override State<WaitResultScreen> createState() => _WaitResultScreenState();
}

class _WaitResultScreenState extends State<WaitResultScreen> {
  String displayScore = "분석 중...";
  String currentHandStr = "";

  @override void initState() { 
    super.initState(); 
    _calculateWait(); 
  }

  void _calculateWait() {
    try {
      String handToCalculate = currentHandStr;
      List<int> tilesToCalculate = List.from(widget.handTiles);
      List<String> zPrefixesUsed = [];

      // 1z=동, 2z=남, 3z=서, 4z=북, 5z=백, 6z=발, 7z=중
      List<int> zClasses = [3, 7, 11, 15, 19, 23, 27];
      List<String> zPrefixes = ['1', '2', '3', '4', '5', '6', '7'];

      if (currentHandStr.isEmpty) {
        // 카메라 스캔 시: 원래 손패에 없는 자패를 찾아 더미로 채워넣음
        int missingMelds = (13 - tilesToCalculate.length) ~/ 3;
        if (missingMelds > 0) {
          for (int i = 0; i < missingMelds; i++) {
            for (int k = 0; k < zClasses.length; k++) {
              int zCls = zClasses[k];
              if (!tilesToCalculate.contains(zCls)) {
                tilesToCalculate.addAll([zCls, zCls, zCls]);
                zPrefixesUsed.add(zPrefixes[k]);
                break;
              }
            }
          }
        }
      } else {
        // 수동 편집 시: 편집된 텍스트에 없는 자패를 찾아 더미로 채워넣음
        int tileCount = currentHandStr.replaceAll(RegExp(r'[^0-9]'), '').length;
        int missingMelds = (13 - tileCount) ~/ 3;
        if (missingMelds > 0) {
          for (int i = 0; i < missingMelds; i++) {
            for (String p in zPrefixes) {
              bool hasP = RegExp('$p(?=[1-7]*z)').hasMatch(handToCalculate);
              if (!hasP) {
                handToCalculate += '$p$p${p}z';
                zPrefixesUsed.add(p);
                break;
              }
            }
          }
        }
      }

      String rustResult = calculateShantenAndWait(
        tiles: tilesToCalculate, 
        overrideHand: handToCalculate, 
      );

      List<String> parts = rustResult.split('\n---\n');
      if (parts.length == 2) {
        displayScore = parts[0];
        List<String> metaLines = parts[1].split('\n');
        for (var line in metaLines) {
          if (line.startsWith('손패:') && currentHandStr.isEmpty) {
            String parsedHand = line.replaceAll('손패:', '').trim();
            
            // 🔥 Dart에 최적화된 안전한 방식으로 더미(Dummy) 패 찌꺼기 완벽 제거
            for (String p in zPrefixesUsed) {
              // 자패(z) 블록만 찾아내서 우리가 추가한 숫자(p)만 정확히 삭제
              parsedHand = parsedHand.replaceAllMapped(RegExp(r'([1-7]+)z'), (match) {
                String zBlock = match.group(1)!;
                zBlock = zBlock.replaceAll(p, '');
                // 숫자를 지웠을 때 아무것도 안 남으면 'z' 기호도 같이 날림
                return zBlock.isEmpty ? '' : '${zBlock}z';
              });
            }
            currentHandStr = parsedHand;
          }
        }
      } else {
        displayScore = rustResult; 
      }
      setState(() {});
    } catch (e) {
      setState(() => displayScore = "에러: $e");
    }
  }

  Future<void> _openEditScreen() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditHandScreen(initialDora: "", initialHand: currentHandStr, isWaitMode: true)));
    if (result != null && result is Map<String, String>) {
      setState(() { currentHandStr = result['hand'] ?? ""; _calculateWait(); });
    }
  }

  Widget _buildBigScoreText() {
    if (displayScore == "분석 중..." || displayScore.contains("에러") || displayScore.contains("오류")) {
      return Text(displayScore, style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    }

    if (displayScore.contains("텐파이가 아닙니다")) {
      return Text(displayScore.trim(), style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    } else {
      return Text(displayScore.trim(), style: const TextStyle(color: Colors.yellowAccent, fontSize: 40, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    }
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('대기패 분석 결과', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Expanded(child: Center(child: SingleChildScrollView(child: _buildBigScoreText()))),
            InkWell(
              onTap: _openEditScreen, borderRadius: BorderRadius.circular(8),
              child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                  Text("인식된 손패: $currentHandStr", style: const TextStyle(color: Colors.greenAccent, fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 1.5), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 8),
                  const Text("👆 터치하여 수동으로 패 수정하기", style: TextStyle(color: Colors.white54, fontSize: 14)),
                ]),
              ),
            )
          ]
        ),
      ),
    );
  }
}