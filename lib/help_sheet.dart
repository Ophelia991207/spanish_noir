import 'package:flutter/material.dart';

class HelpSheet extends StatelessWidget {
  const HelpSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 25),
            const Text("Grammar & Guide", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900)),
            const SizedBox(height: 25),
            const Text("【 西語基礎語法 】", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Text(
              "• Yo (我) / Tú (你) / Él (他)\n• El (陽性名詞) / La (陰性名詞)",
              style: TextStyle(fontSize: 16, height: 1.8),

            ),
          ],
        ),
      ),
    );
  }
}