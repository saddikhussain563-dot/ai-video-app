import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

void main() {
  runApp(const AIVideoApp());
}

class AIVideoApp extends StatelessWidget {
  const AIVideoApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AI Video Gen',
      theme: ThemeData.dark(),
      home: const InitializerWidget(),
    );
  }
}

// 1. BYOK Routing Logic
class InitializerWidget extends StatefulWidget {
  const InitializerWidget({Key? key}) : super(key: key);

  @override
  _InitializerWidgetState createState() => _InitializerWidgetState();
}

class _InitializerWidgetState extends State<InitializerWidget> {
  final storage = const FlutterSecureStorage();
  
  @override
  void initState() {
    super.initState();
    _checkToken();
  }

  Future<void> _checkToken() async {
    String? token = await storage.read(key: 'hf_token');
    if (token != null && token.isNotEmpty) {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    } else {
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const OnboardingScreen()));
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// 2. BYOK Onboarding Screen
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({Key? key}) : super(key: key);

  @override
  _OnboardingScreenState createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final TextEditingController _tokenController = TextEditingController();
  final storage = const FlutterSecureStorage();

  void _saveToken() async {
    if (_tokenController.text.isNotEmpty) {
      await storage.write(key: 'hf_token', value: _tokenController.text.trim());
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const MainScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Setup Free API")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Get your FREE Hugging Face Token in 1 minute from huggingface.co/settings/tokens", textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextField(
              controller: _tokenController,
              decoration: const InputDecoration(labelText: "Paste HF Token Here", border: OutlineInputBorder()),
              obscureText: true,
            ),
            const SizedBox(height: 20),
            ElevatedButton(onPressed: _saveToken, child: const Text("Save & Continue"))
          ],
        ),
      ),
    );
  }
}

// 3, 4, 5. Main UI, State Management & Video Player
class MainScreen extends StatefulWidget {
  const MainScreen({Key? key}) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  final TextEditingController _promptController = TextEditingController();
  final storage = const FlutterSecureStorage();
  
  String _aspectRatio = "16:9";
  String _style = "Cinematic";
  bool _isGenerating = false;
  String _statusText = "";
  VideoPlayerController? _videoController;

  Future<void> _generateVideo() async {
    if (_promptController.text.isEmpty) return;
    
    setState(() {
      _isGenerating = true;
      _statusText = "Enhancing Prompt & Generating...";
      _videoController?.dispose();
      _videoController = null;
    });

    String? token = await storage.read(key: 'hf_token');
    
    try {
      // Render Live Backend URL integrated here safely
      final response = await http.post(
        Uri.parse('https://ai-video-backend-ne0b.onrender.com/generate'),
        headers: {
          'Content-Type': 'application/json',
          'x-hf-token': token ?? '',
        },
        body: jsonEncode({
          'prompt': _promptController.text,
          'aspect_ratio': _aspectRatio,
          'style': _style
        }),
      );

      if (response.statusCode == 200) {
        setState(() => _statusText = "Video Ready!");
      } else {
        setState(() => _statusText = "Error: ${response.body}");
      }
    } catch (e) {
      setState(() => _statusText = "Network Error");
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("AI Video Generator")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _promptController,
              maxLines: 3,
              decoration: const InputDecoration(labelText: "Enter Video Script/Prompt", border: OutlineInputBorder()),
              enabled: !_isGenerating,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                DropdownButton<String>(
                  value: _aspectRatio,
                  items: ["16:9", "9:16"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: _isGenerating ? null : (v) => setState(() => _aspectRatio = v!),
                ),
                DropdownButton<String>(
                  value: _style,
                  items: ["Cinematic", "Anime", "3D Render"].map((e) => DropdownMenuItem(value: e, child: Text(e))).toList(),
                  onChanged: _isGenerating ? null : (v) => setState(() => _style = v!),
                ),
              ],
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isGenerating ? null : _generateVideo,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: _isGenerating 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text("Generate Video"),
            ),
            const SizedBox(height: 20),
            if (_statusText.isNotEmpty) Text(_statusText, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
            const SizedBox(height: 20),
            if (_videoController != null && _videoController!.value.isInitialized)
              AspectRatio(
                aspectRatio: _videoController!.value.aspectRatio,
                child: VideoPlayer(_videoController!),
              ),
          ],
        ),
      ),
    );
  }
}
