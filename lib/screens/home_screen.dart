import 'package:flutter/material.dart';
import 'score_scanner_screen.dart';
import 'wait_scanner_screen.dart';
import 'center_panel_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Mahjong Utility', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.black,
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row( // 🔥 가로 화면에 맞게 Row(가로 배열)로 변경
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSquareButton(
                context, 
                title: '점수 계산', 
                icon: Icons.calculate_outlined, 
                color: Colors.blueAccent, 
                targetScreen: const ScoreScannerScreen(), 
              ),
              _buildSquareButton(
                context, 
                title: '대기패 분석', 
                icon: Icons.search_outlined, 
                color: Colors.greenAccent, 
                targetScreen: const WaitScannerScreen(), 
              ),
              _buildSquareButton(
                context, 
                title: '디지털 전탁', 
                icon: Icons.table_restaurant_outlined, 
                color: Colors.orangeAccent, 
                targetScreen: const CenterPanelScreen(), 
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSquareButton(BuildContext context, {required String title, required IconData icon, required Color color, required Widget targetScreen}) {
    return Expanded( 
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0), // 🔥 버튼 간 가로 여백 설정
        child: AspectRatio( 
          aspectRatio: 1.0, // 완벽한 정사각형 비율 유지
          child: InkWell(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => targetScreen)),
            borderRadius: BorderRadius.circular(20), 
            child: Container(
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1), // withOpacity 대체
                border: Border.all(color: color, width: 3), 
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 60, color: color), // 가로 3등분에 맞게 아이콘 크기 조정
                  const SizedBox(height: 16),
                  Text(title, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)), 
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}