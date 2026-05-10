import 'package:flutter/material.dart';

class EditHandScreen extends StatefulWidget {
  final String initialDora;
  final String initialHand;
  final bool isWaitMode;

  const EditHandScreen({super.key, required this.initialDora, required this.initialHand, required this.isWaitMode});

  @override
  State<EditHandScreen> createState() => _EditHandScreenState();
}

class _EditHandScreenState extends State<EditHandScreen> {
  late TextEditingController doraCtrl;
  late TextEditingController handCtrl;

  @override
  void initState() {
    super.initState();
    doraCtrl = TextEditingController(text: widget.initialDora);
    handCtrl = TextEditingController(text: widget.initialHand);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('손패 수동 편집', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.black, iconTheme: const IconThemeData(color: Colors.white),
        actions: [ IconButton(icon: const Icon(Icons.check, color: Colors.greenAccent, size: 32), onPressed: () { Navigator.pop(context, {'dora': doraCtrl.text, 'hand': handCtrl.text}); }), const SizedBox(width: 16) ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text("마작 표기법(예: 123m456p)을 사용하여 입력하세요.\n후로는 (), 안깡은 []입니다.", style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 24),
              if (!widget.isWaitMode) ...[
                const Text("도라표시패", style: TextStyle(color: Colors.lightBlueAccent, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
                TextField(controller: doraCtrl, style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0), decoration: InputDecoration(hintText: '도라표시패 입력', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 18), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
                const SizedBox(height: 24),
              ],
              const Text("손패", style: TextStyle(color: Colors.greenAccent, fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 8),
              TextField(controller: handCtrl, autofocus: true, style: const TextStyle(color: Colors.black, fontSize: 24, fontWeight: FontWeight.bold, letterSpacing: 2.0), decoration: InputDecoration(hintText: '손패 입력', hintStyle: TextStyle(color: Colors.grey[400], fontSize: 18), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16))),
            ],
          ),
        ),
      ),
    );
  }
}