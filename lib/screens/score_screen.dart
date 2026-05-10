import 'package:flutter/material.dart';
import '../src/rust/api/simple.dart';
import 'edit_screen.dart';

class ScoreResultScreen extends StatefulWidget {
  final List<int> handTiles; 
  final List<int> doraIndicatorTiles; 
  final double lastTileAngle;
  final bool hasFuro; 
  
  const ScoreResultScreen({super.key, required this.handTiles, required this.doraIndicatorTiles, required this.lastTileAngle, required this.hasFuro});
  @override State<ScoreResultScreen> createState() => _ScoreResultScreenState();
}

class _ScoreResultScreenState extends State<ScoreResultScreen> {
  bool isTsumo = false; bool isMenzenTsumo = false;
  bool isRiichi = false, isIppatsu = false, isHaitei = false, isHoutei = false, isChankan = false;
  String prevalentWind = '동', seatWind = '동'; int honba = 0; 
  String displayScore = "계산 중..."; String currentDoraStr = ""; String currentHandStr = "";

  @override void initState() { 
    super.initState(); 
    isTsumo = widget.lastTileAngle > 0.5;
    isMenzenTsumo = isTsumo && !widget.hasFuro; 
    _calculateFinalScore(); 
  }

  void _updateLogic({bool? tsumo, bool? menzen, bool? riichi, bool? haitei, bool? houtei}) {
    setState(() {
      if (tsumo != null) { isTsumo = tsumo; if (isTsumo) { isHoutei = false; if (isRiichi) isMenzenTsumo = true; } else { isHaitei = false; isMenzenTsumo = false; } }
      if (menzen != null) { isMenzenTsumo = menzen; if (isMenzenTsumo) { isTsumo = true; isHoutei = false; } }
      if (riichi != null) { isRiichi = riichi; if (isRiichi && isTsumo) isMenzenTsumo = true; }
      if (haitei != null) { isHaitei = haitei; if (isHaitei) { isHoutei = false; isTsumo = true; if (isRiichi) isMenzenTsumo = true; } }
      if (houtei != null) { isHoutei = houtei; if (isHoutei) { isHaitei = false; isTsumo = false; isMenzenTsumo = false; } }
      _calculateFinalScore();
    });
  }

  void _calculateFinalScore() {
    try {
      String rustResult = calculateMahjongFromCamera(
        tiles: widget.handTiles, doraIndicators: widget.doraIndicatorTiles, 
        lastTileAngle: isTsumo ? 1.0 : 0.0, lastTileDistance: isMenzenTsumo ? 1.0 : 0.0, 
        isRiichi: isRiichi, isIppatsu: isIppatsu, isHaitei: isHaitei, isHoutei: isHoutei, isChankan: isChankan,
        prevalentWind: prevalentWind, seatWind: seatWind, honba: honba,
        overrideHand: currentHandStr, overrideDora: currentDoraStr, 
      );
      List<String> parts = rustResult.split('\n---\n');
      if (parts.length == 2) {
        displayScore = parts[0];
        List<String> metaLines = parts[1].split('\n');
        for (var line in metaLines) {
          if (line.startsWith('도라표시패:') && currentDoraStr.isEmpty) currentDoraStr = line.replaceAll('도라표시패:', '').trim();
          if (line.startsWith('손패:') && currentHandStr.isEmpty) currentHandStr = line.replaceAll('손패:', '').trim();
        }
      } else { displayScore = rustResult; }
      setState(() {});
    } catch (e) { setState(() => displayScore = "에러: $e"); }
  }

  Future<void> _openEditScreen() async {
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => EditHandScreen(initialDora: currentDoraStr, initialHand: currentHandStr, isWaitMode: false)));
    if (result != null && result is Map<String, String>) {
      setState(() { currentDoraStr = result['dora'] ?? ""; currentHandStr = result['hand'] ?? ""; _calculateFinalScore(); });
    }
  }

  Widget _buildBigScoreText() {
    if (displayScore == "계산 중..." || displayScore.contains("에러") || displayScore.contains("실패") || displayScore.contains("불가")) {
      return Text(displayScore, style: const TextStyle(color: Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold), textAlign: TextAlign.center);
    }
    List<String> lines = displayScore.split('\n').where((line) => line.trim().isNotEmpty).toList();
    List<Widget> textWidgets = [];
    for (int i = 0; i < lines.length; i++) {
      if (i == 0) { textWidgets.add(Text(lines[i], style: const TextStyle(color: Colors.orangeAccent, fontSize: 42, fontWeight: FontWeight.w900))); } 
      else if (i == 1) { textWidgets.add(Text(lines[i], style: const TextStyle(color: Colors.yellowAccent, fontSize: 36, fontWeight: FontWeight.bold))); textWidgets.add(const SizedBox(height: 16)); } 
      else { textWidgets.add(Text(lines[i], style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold, height: 1.5), textAlign: TextAlign.center)); }
    }
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: textWidgets);
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(title: const Text('점수 계산 결과', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white)),
      body: Row(children: [
        Expanded(flex: 6, child: Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            _buildWindDropdown('장풍', prevalentWind, (v) => setState(() { prevalentWind = v!; _calculateFinalScore(); })), const SizedBox(width: 24),
            _buildWindDropdown('자풍', seatWind, (v) => setState(() { seatWind = v!; _calculateFinalScore(); })), const Spacer(),
            const Text('본장', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.white, size: 36), onPressed: () => setState(() { if (honba > 0) honba--; _calculateFinalScore(); })),
            Text('$honba', style: const TextStyle(color: Colors.yellowAccent, fontSize: 28, fontWeight: FontWeight.bold)),
            IconButton(icon: const Icon(Icons.add_circle_outline, color: Colors.white, size: 36), onPressed: () => setState(() { honba++; _calculateFinalScore(); })),
          ]), const SizedBox(height: 20),
          Expanded(child: LayoutBuilder(builder: (context, constraints) {
            double spacing = 16.0; double baseButtonWidth = ((constraints.maxWidth - (spacing * 2)) / 3).floorToDouble(); double tsumoWidth = constraints.maxWidth;
            return SingleChildScrollView(child: Column(children: [
              _buildBigToggle('쯔모', isTsumo, (v) => _updateLogic(tsumo: v), activeColor: Colors.blueAccent, unselectedColor: Colors.white24, width: tsumoWidth, fontSize: 26), const SizedBox(height: 16),
              Wrap(spacing: spacing, runSpacing: spacing, children: [
                _buildBigToggle('멘젠 쯔모', isMenzenTsumo, (v) => _updateLogic(menzen: v), width: baseButtonWidth), _buildBigToggle('리치', isRiichi, (v) => _updateLogic(riichi: v), width: baseButtonWidth),
                _buildBigToggle('일발', isIppatsu, (v) => setState(() { isIppatsu = v; _calculateFinalScore(); }), width: baseButtonWidth), _buildBigToggle('해저로월', isHaitei, (v) => _updateLogic(haitei: v), width: baseButtonWidth),
                _buildBigToggle('하저로어', isHoutei, (v) => _updateLogic(houtei: v), width: baseButtonWidth), _buildBigToggle('창깡', isChankan, (v) => setState(() { isChankan = v; _calculateFinalScore(); }), width: baseButtonWidth),
              ]),
            ]));
          }))
        ]))),
        Expanded(flex: 4, child: Container(color: Colors.black, padding: const EdgeInsets.all(20.0), child: Column(children: [
          Expanded(child: Center(child: SingleChildScrollView(child: _buildBigScoreText()))),
          InkWell(
            onTap: _openEditScreen, borderRadius: BorderRadius.circular(8),
            child: Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16), decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.white24)),
              child: Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Text("도라표시패: ${currentDoraStr.isEmpty ? '-' : currentDoraStr}", style: const TextStyle(color: Colors.lightBlueAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 6),
                Text("손패: $currentHandStr", style: const TextStyle(color: Colors.greenAccent, fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 1.2), maxLines: 1, overflow: TextOverflow.ellipsis), const SizedBox(height: 6),
                const Text("👆 터치하여 수동으로 패 수정하기", style: TextStyle(color: Colors.white54, fontSize: 12)),
              ]),
            ),
          )
        ])))
      ]),
    );
  }
  
  Widget _buildWindDropdown(String label, String value, void Function(String?) onChanged) {
    return Row(children: [
      Text(label, style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(width: 12), 
      DropdownButton<String>(value: value, dropdownColor: Colors.grey[900], style: const TextStyle(color: Colors.yellowAccent, fontSize: 24, fontWeight: FontWeight.bold), iconSize: 32, iconEnabledColor: Colors.white, items: ['동', '남', '서', '북'].map((w) => DropdownMenuItem(value: w, child: Text(w, style: const TextStyle(color: Colors.yellowAccent)))).toList(), onChanged: onChanged)
    ]);
  }

  Widget _buildBigToggle(String text, bool value, void Function(bool) onChanged, {Color activeColor = Colors.redAccent, Color unselectedColor = Colors.white12, double? width, double fontSize = 18}) {
    return InkWell(onTap: () => onChanged(!value), borderRadius: BorderRadius.circular(12),
      child: Container(width: width, alignment: Alignment.center, padding: const EdgeInsets.symmetric(vertical: 14), decoration: BoxDecoration(color: value ? activeColor.withValues(alpha: 0.8) : unselectedColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: value ? activeColor : Colors.white54, width: 2)),
        child: Text(text, style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.bold)),
      ),
    );
  }
}