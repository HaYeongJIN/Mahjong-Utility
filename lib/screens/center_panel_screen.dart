import 'package:flutter/material.dart';
import 'dart:math';

class CenterPanelScreen extends StatefulWidget {
  const CenterPanelScreen({super.key});
  @override State<CenterPanelScreen> createState() => _CenterPanelScreenState();
}

class _CenterPanelScreenState extends State<CenterPanelScreen> {
  List<int> scores = [25000, 25000, 25000, 25000];
  List<bool> isRiichi = [false, false, false, false];
  List<String> winds = ['동', '남', '서', '북'];
  List<String> roundNames = ['동', '남', '서', '북'];

  int kyotaku = 0; int honba = 0;
  int roundIndex = 0; 
  int handIndex = 1;  
  int? diceSum; 
  int? diffTargetIndex;

  // 🔥 keepHonba 파라미터 추가 (유국으로 인한 오야 교체 시 본장 유지)
  void _nextRound({bool keepHonba = false}) {
    setState(() {
      handIndex++;
      if (handIndex > 4) {
        handIndex = 1;
        if (roundIndex == 1) { 
          bool anyAbove30k = scores.any((score) => score >= 30000);
          if (!anyAbove30k) { roundIndex = 2; } else { roundIndex = 0; }
        } else { roundIndex = (roundIndex + 1) % 4; }
      }
      
      if (!keepHonba) {
        honba = 0; // 누군가 화료해서 국이 넘어갈 때만 본장 초기화
      }
      
      winds = [winds[3], winds[0], winds[1], winds[2]];
      isRiichi = [false, false, false, false];
    });
  }

  void _rollDice() {
    setState(() { diceSum = (Random().nextInt(6) + 1) + (Random().nextInt(6) + 1); });
  }

  void _toggleRiichi(int index) {
    setState(() {
      if (isRiichi[index]) { isRiichi[index] = false; scores[index] += 1000; kyotaku--; } 
      else if (scores[index] >= 1000) { isRiichi[index] = true; scores[index] -= 1000; kyotaku++; }
    });
  }

  int _calculateMahjongScore(int han, int fu, bool isDealer, bool isTsumo, {bool isChildToDealer = false}) {
    if (han >= 13) return isDealer ? 48000 : 32000;
    if (han >= 11) return isDealer ? 36000 : 24000;
    if (han >= 8) return isDealer ? 24000 : 16000;
    if (han >= 6) return isDealer ? 18000 : 12000;
    int basic = fu * pow(2, han + 2).toInt();
    if (basic > 2000) basic = 2000; 
    if (isTsumo) {
      if (isDealer) return ((basic * 2 / 100).ceil() * 100) * 3;
      if (isChildToDealer) return (basic * 2 / 100).ceil() * 100;
      return (basic / 100).ceil() * 100;
    }
    return (basic * (isDealer ? 6 : 4) / 100).ceil() * 100;
  }

  Widget _buildDirectionButton({
    required int index, 
    required Alignment alignment, 
    required IconData iconData, 
    required bool isSelected, 
    required VoidCallback onTap, 
    Color activeColor = Colors.orangeAccent,
    bool isWinner = false,
  }) {
    return Align(
      alignment: alignment,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 75, height: 75,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isSelected ? activeColor : (isWinner ? Colors.green.withValues(alpha: 0.3) : Colors.grey[800]),
              border: Border.all(color: isSelected ? activeColor : (isWinner ? Colors.greenAccent : Colors.white24), width: 2),
            ),
            alignment: Alignment.center,
            child: Icon(iconData, size: 50, color: isSelected ? Colors.black : (isWinner ? Colors.greenAccent : Colors.white54)),
          ),
        ),
      ),
    );
  }

  void _showWinProcessDialog() {
    int step = 0; 
    List<int> winners = [];
    int? loser = -1; 
    int scoreStep = 0;
    List<int> sortedWinners = [];
    List<Map<String, int>> winnerInputs = [];

    int tempHan = 1;
    int tempFu = 30;

    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setDialogState) {
        Widget content;
        String btnText = '다음';

        if (step == 0) {
          content = SizedBox(
            width: 250, height: 250,
            child: Stack(
              children: [
                _buildDirectionButton(index: 2, alignment: Alignment.topCenter, iconData: Icons.arrow_drop_up, isSelected: winners.contains(2), onTap: () => setDialogState(() => winners.contains(2) ? winners.remove(2) : winners.add(2))),
                _buildDirectionButton(index: 3, alignment: Alignment.centerLeft, iconData: Icons.arrow_left, isSelected: winners.contains(3), onTap: () => setDialogState(() => winners.contains(3) ? winners.remove(3) : winners.add(3))),
                _buildDirectionButton(index: 1, alignment: Alignment.centerRight, iconData: Icons.arrow_right, isSelected: winners.contains(1), onTap: () => setDialogState(() => winners.contains(1) ? winners.remove(1) : winners.add(1))),
                _buildDirectionButton(index: 0, alignment: Alignment.bottomCenter, iconData: Icons.arrow_drop_down, isSelected: winners.contains(0), onTap: () => setDialogState(() => winners.contains(0) ? winners.remove(0) : winners.add(0))),
              ],
            ),
          );
        } else if (step == 1) {
          content = SizedBox(
            width: 250, height: 250,
            child: Stack(
              children: [
                for (int i = 0; i < 4; i++)
                  _buildDirectionButton(
                    index: i,
                    alignment: i == 2 ? Alignment.topCenter : (i == 3 ? Alignment.centerLeft : (i == 1 ? Alignment.centerRight : Alignment.bottomCenter)),
                    iconData: i == 2 ? Icons.arrow_drop_up : (i == 3 ? Icons.arrow_left : (i == 1 ? Icons.arrow_right : Icons.arrow_drop_down)),
                    isSelected: (loser == null && winners.contains(i)) || loser == i,
                    activeColor: winners.contains(i) ? Colors.greenAccent : Colors.redAccent,
                    isWinner: winners.contains(i),
                    onTap: () {
                      setDialogState(() {
                        if (winners.contains(i)) {
                          if (winners.length == 1) loser = null; // 쯔모
                        } else {
                          loser = i; // 방총
                        }
                      });
                    },
                  ),
              ],
            ),
          );
        } else {
          int currentWinIdx = sortedWinners[scoreStep];
          btnText = (scoreStep == sortedWinners.length - 1) ? '완료' : '다음';
          content = SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(winds[currentWinIdx], style: const TextStyle(color: Colors.orangeAccent, fontSize: 32, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),
                Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                  _picker('판', tempHan, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13], (v) => setDialogState(() => tempHan = v)),
                  _picker('부', tempFu, [20, 25, 30, 40, 50, 60, 70, 80, 90, 100, 110], (v) => setDialogState(() => tempFu = v)),
                ]),
              ],
            ),
          );
        }

        return AlertDialog(
          backgroundColor: Colors.grey[900],
          contentPadding: const EdgeInsets.fromLTRB(20, 30, 20, 10),
          content: content,
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.white54, fontSize: 18))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: () {
                setDialogState(() {
                  if (step == 0 && winners.isNotEmpty) {
                    List<String> order = ['동', '남', '서', '북'];
                    sortedWinners = List.from(winners);
                    sortedWinners.sort((a, b) => order.indexOf(winds[a]).compareTo(order.indexOf(winds[b])));
                    step = 1;
                  } else if (step == 1 && loser != -1) {
                    step = 2;
                  } else if (step == 2) {
                    winnerInputs.add({'han': tempHan, 'fu': tempFu});
                    if (scoreStep < sortedWinners.length - 1) {
                      scoreStep++; tempHan = 1; tempFu = 30;
                    } else {
                      _applyMultipleRon(sortedWinners, winnerInputs, loser);
                      Navigator.pop(context);
                    }
                  }
                });
              }, 
              child: Text(btnText, style: const TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold))
            )
          ],
        );
      });
    });
  }

  void _applyMultipleRon(List<int> winners, List<Map<String, int>> inputs, int? loser) {
    setState(() {
      int headBumpWinner = winners[0];
      if (loser != null) {
         int minDistance = 999;
         for (int w in winners) {
            int dist = (w - loser + 4) % 4;
            if (dist > 0 && dist < minDistance) { minDistance = dist; headBumpWinner = w; }
         }
      }
      for (int i = 0; i < winners.length; i++) {
        int winner = winners[i];
        bool isDealer = winds[winner] == '동', isTsumo = loser == null;
        int score = _calculateMahjongScore(inputs[i]['han']!, inputs[i]['fu']!, isDealer, isTsumo, isChildToDealer: false);
        if (isTsumo) {
          for (int j = 0; j < 4; j++) {
            if (j == winner) continue;
            int loss = _calculateMahjongScore(inputs[i]['han']!, inputs[i]['fu']!, isDealer, true, isChildToDealer: winds[j] == '동');
            int lossWithHonba = loss + (honba * 100);
            scores[j] -= lossWithHonba; scores[winner] += lossWithHonba;
          }
        } else {
          int sWithHonba = score + (honba * 300);
          scores[loser] -= sWithHonba; scores[winner] += sWithHonba;
        }
        if (winner == headBumpWinner) scores[winner] += (kyotaku * 1000);
      }
      kyotaku = 0;
      if (winners.any((w) => winds[w] == '동')) { 
        honba++; 
        isRiichi = [false, false, false, false]; 
      } else { 
        _nextRound(); 
      }
    });
  }

  Widget _picker(String label, int val, List<int> list, Function(int) onChg) {
    return Column(children: [
      Text(label, style: const TextStyle(color: Colors.white54, fontSize: 16, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Container(
        width: 100, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.grey[800], borderRadius: BorderRadius.circular(12)),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int>(
            isExpanded: true, value: val, dropdownColor: Colors.black, iconSize: 32,
            style: const TextStyle(color: Colors.white, fontSize: 26, fontWeight: FontWeight.bold),
            items: list.map((e) => DropdownMenuItem(value: e, child: Center(child: Text('$e')))).toList(),
            onChanged: (v) => onChg(v!)
          ),
        ),
      ),
    ]);
  }

  void _showRyukyokuDialog() {
    List<bool> tenpaiStatus = [false, false, false, false];
    showDialog(context: context, builder: (context) {
      return StatefulBuilder(builder: (context, setDialogState) {
        return AlertDialog(
          backgroundColor: Colors.grey[900],
          contentPadding: const EdgeInsets.all(32.0),
          content: SizedBox(
            width: 250, height: 250,
            child: Stack(
              children: [
                _buildDirectionButton(index: 2, alignment: Alignment.topCenter, iconData: Icons.arrow_drop_up, isSelected: tenpaiStatus[2], onTap: () => setDialogState(() => tenpaiStatus[2] = !tenpaiStatus[2])),
                _buildDirectionButton(index: 3, alignment: Alignment.centerLeft, iconData: Icons.arrow_left, isSelected: tenpaiStatus[3], onTap: () => setDialogState(() => tenpaiStatus[3] = !tenpaiStatus[3])),
                _buildDirectionButton(index: 1, alignment: Alignment.centerRight, iconData: Icons.arrow_right, isSelected: tenpaiStatus[1], onTap: () => setDialogState(() => tenpaiStatus[1] = !tenpaiStatus[1])),
                _buildDirectionButton(index: 0, alignment: Alignment.bottomCenter, iconData: Icons.arrow_drop_down, isSelected: tenpaiStatus[0], onTap: () => setDialogState(() => tenpaiStatus[0] = !tenpaiStatus[0])),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('취소', style: TextStyle(color: Colors.white54, fontSize: 18))),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orangeAccent, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12)),
              onPressed: () {
                setState(() {
                  int tenpaiCount = tenpaiStatus.where((e) => e).length;
                  if (tenpaiCount > 0 && tenpaiCount < 4) {
                    int receive = 3000 ~/ tenpaiCount, pay = 3000 ~/ (4 - tenpaiCount);
                    for (int i = 0; i < 4; i++) { if (tenpaiStatus[i]) {scores[i] += receive;} else {scores[i] -= pay;} }
                  }
                  
                  // 🔥 유국 시 오야 텐파이 여부와 무관하게 무조건 본장 1 증가
                  honba++; 
                  
                  if (tenpaiStatus[winds.indexOf('동')]) { 
                    isRiichi = [false, false, false, false]; 
                  } else { 
                    _nextRound(keepHonba: true); // 🔥 오야가 넘어가도 본장 유지
                  }
                });
                Navigator.pop(context);
              },
              child: const Text('완료', style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
            )
          ],
        );
      });
    });
  }

  Widget _buildPlayerArea(int index, int quarterTurns) {
    bool isTarget = diffTargetIndex != null && diffTargetIndex != index;
    String scoreDisp = scores[index].toString(); Color color = Colors.white;
    if (diffTargetIndex != null) {
      if (index == diffTargetIndex) { scoreDisp = "기준"; color = Colors.yellowAccent; } 
      else { 
        int d = scores[index] - scores[diffTargetIndex!]; scoreDisp = d > 0 ? "+$d" : "$d"; color = d > 0 ? Colors.greenAccent : Colors.redAccent;
      }
    }
    return RotatedBox(
      quarterTurns: quarterTurns,
      child: Container(
        width: 210, height: 75,
        decoration: BoxDecoration(
          color: isTarget ? Colors.blueGrey.withValues(alpha: 0.3) : Colors.white10, borderRadius: BorderRadius.circular(12), 
          border: Border.all(color: isRiichi[index] ? Colors.redAccent : (winds[index] == '동' ? Colors.orangeAccent : Colors.white24), width: winds[index] == '동' ? 2 : 1)
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          GestureDetector(
            onTap: () => setState(() => diffTargetIndex = (diffTargetIndex == index ? null : index)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: Colors.black38, borderRadius: BorderRadius.circular(8)),
              child: Text(winds[index], style: TextStyle(color: winds[index] == '동' ? Colors.orangeAccent : Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(width: 20), 
          GestureDetector(onTap: () => _toggleRiichi(index), child: Text(scoreDisp, style: TextStyle(color: color, fontSize: 24, fontWeight: FontWeight.w900))),
        ]),
      ),
    );
  }

  @override Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(children: [
          Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
            ElevatedButton(onPressed: _showWinProcessDialog, style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('화료', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold))),
            const SizedBox(width: 20),
            GestureDetector(onTap: _rollDice, child: Container(width: 140, height: 140, decoration: BoxDecoration(color: Colors.grey[900], shape: BoxShape.circle, border: Border.all(color: Colors.white24, width: 2)), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('${roundNames[roundIndex]} $handIndex국', style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text(diceSum == null ? 'DICE' : '🎲 $diceSum', style: const TextStyle(color: Colors.yellowAccent, fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 5), Text('$honba본장 / 공탁: ${kyotaku*1000}', style: const TextStyle(color: Colors.white54, fontSize: 12))]))),
            const SizedBox(width: 20),
            OutlinedButton(onPressed: _showRyukyokuDialog, style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.orangeAccent), padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('유국', style: TextStyle(color: Colors.orangeAccent, fontSize: 18, fontWeight: FontWeight.bold)))
          ])),
          Align(alignment: Alignment.bottomCenter, child: Padding(padding: const EdgeInsets.all(20), child: _buildPlayerArea(0, 0))),
          Align(alignment: Alignment.centerRight, child: Padding(padding: const EdgeInsets.all(20), child: _buildPlayerArea(1, 3))),
          Align(alignment: Alignment.topCenter, child: Padding(padding: const EdgeInsets.all(20), child: _buildPlayerArea(2, 2))),
          Align(alignment: Alignment.centerLeft, child: Padding(padding: const EdgeInsets.all(20), child: _buildPlayerArea(3, 1))),
          Positioned(top: 10, left: 10, child: IconButton(icon: const Icon(Icons.close, color: Colors.white54, size: 30), onPressed: () => Navigator.pop(context)))
        ])),
    );
  }
}