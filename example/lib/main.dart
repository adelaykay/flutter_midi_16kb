import 'dart:io';

import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_midi_16kb/flutter_midi_16kb.dart';
import 'package:path_provider/path_provider.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: TinySound(),
    );
  }
}

class TinySound extends StatefulWidget {
  const TinySound({super.key});

  @override
  State<TinySound> createState() => _TinySoundState();
}

class _TinySoundState extends State<TinySound> {
  bool _initialized = false;
  bool _loaded = false;
  String? _currentSoundfontPath;

  @override
  void initState() {
    super.initState();
    initialize();
  }

  Future<void> initialize() async {
    try {
      final result = await FlutterMidi16kb.initialize();
      setState(() {
        _initialized = result;
      });
    } catch (e) {
      print('Error initializing: $e');
    }
  }

  Future<void> loadSoundfont() async {
    try {
      String assetPath = 'assets/example.sf2';
      final ByteData data = await rootBundle.load(assetPath);
      final List<int> bytes = data.buffer.asUint8List();

      final Directory tempDir = await getTemporaryDirectory();
      final String fileName = assetPath.split('/').last;
      final File tempFile = File('${tempDir.path}/$fileName');

      await tempFile.writeAsBytes(bytes);
      _currentSoundfontPath = tempFile.path;
      final result = await FlutterMidi16kb.loadSoundfont(tempFile.path);
      setState(() {
        _loaded = result;
      });
    } catch (e) {
      print('Error loading soundfont: $e');
    }
  }

  Future<void> playNote() async {
    try {
      await FlutterMidi16kb.playNote(key: 60);
    } catch (e) {
      print('Error playing note: $e');
    }
  }

  Future<void> stopNote() async {
    try {
      await FlutterMidi16kb.stopNote(key: 60);
    } catch (e) {
      print('Error stopping note: $e');
    }
  }

  Future<void> stopAllNotes() async {
    try {
      await FlutterMidi16kb.stopAllNotes();
    } catch (e) {
      print('Error stopping all notes: $e');
    }
  }

  Future<void> changeProgram() async {
    try {
      await FlutterMidi16kb.changeProgram(program: 1);
    } catch (e) {
      print('Error changing program: $e');
    }
  }

  @override
  void dispose() {
    super.dispose();
    FlutterMidi16kb.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tiny Sound'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text('Initialized: $_initialized'),
            Text('Loaded: $_loaded'),
            ElevatedButton(
              onPressed: loadSoundfont,
              child: const Text('Load Soundfont'),
            ),
            ElevatedButton(
              onPressed: playNote,
              child: const Text('Play Note'),
            ),
            ElevatedButton(
              onPressed: stopNote,
              child: const Text('Stop Note'),
            ),
            ElevatedButton(
              onPressed: stopAllNotes,
              child: const Text('Stop All Notes'),
            ),
            ElevatedButton(
              onPressed: changeProgram,
              child: const Text('Change Program'),
            ),
          ],
        ),
      ),
    );
  }
}
