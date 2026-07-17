import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../l10n/l10n.dart';
import '../services/assistant_service.dart';
import '../services/exceptions.dart';

class _ChatMessage {
  final String text;
  final bool isUser;
  final List<String> sources;
  final List<String> toolsUsed;
  final String? audioBase64;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.sources = const [],
    this.toolsUsed = const [],
    this.audioBase64,
  });
}

/// Pantalla de chat del asistente (texto + micrófono + TTS). RF-46 / RF-47.
class AssistantChatScreen extends StatefulWidget {
  final AssistantService? service;
  final String locale;

  const AssistantChatScreen({
    super.key,
    this.service,
    this.locale = 'es',
  });

  @override
  State<AssistantChatScreen> createState() => _AssistantChatScreenState();
}

class _AssistantChatScreenState extends State<AssistantChatScreen> {
  late final AssistantService _service;
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <_ChatMessage>[];
  final _recorder = AudioRecorder();
  final _player = AudioPlayer();
  final _tts = FlutterTts();

  bool _sending = false;
  bool _recording = false;
  bool _speakReplies = true;
  String? _conversationId;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? AssistantService();
    unawaited(_initTts());
  }

  Future<void> _initTts() async {
    final lang = widget.locale.startsWith('en') ? 'en-US' : 'es-ES';
    await _tts.setLanguage(lang);
    await _tts.setSpeechRate(0.48);
    await _tts.setPitch(1.0);
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    unawaited(_tts.stop());
    super.dispose();
  }

  Future<void> _sendText(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _sending = true;
      _controller.clear();
    });
    _scrollToEnd();

    try {
      final resp = await _service.chat(
        message: text,
        conversationId: _conversationId,
        locale: widget.locale,
        tts: true,
      );
      _conversationId = resp.conversationId ?? _conversationId;
      final bot = _ChatMessage(
        text: resp.reply,
        isUser: false,
        sources: resp.sources,
        toolsUsed: resp.toolsUsed,
        audioBase64: resp.audioBase64,
      );
      setState(() => _messages.add(bot));
      if (_speakReplies) {
        unawaited(_speakReply(resp.reply, resp.audioBase64));
      }
    } on ApiException catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: e.message, isUser: false));
      });
    } catch (e) {
      setState(() {
        _messages.add(_ChatMessage(text: e.toString(), isUser: false));
      });
    } finally {
      if (mounted) setState(() => _sending = false);
      _scrollToEnd();
    }
  }

  Future<void> _toggleMic() async {
    final l10n = context.l10n;
    if (_recording) {
      final path = await _recorder.stop();
      setState(() => _recording = false);
      if (path == null) return;
      setState(() => _sending = true);
      try {
        final bytes = await File(path).readAsBytes();
        if (bytes.length < 512) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.assistantEmptyTranscript)),
          );
          return;
        }
        // WAV 16 kHz mono — formato que Groq Whisper procesa de forma fiable.
        final text = await _service.transcribe(bytes, filename: 'voice.wav');
        if (text.isEmpty) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.assistantEmptyTranscript)),
          );
          return;
        }
        await _sendText(text);
      } on ApiException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.assistantEmptyTranscript}: $e')),
        );
      } finally {
        if (mounted) setState(() => _sending = false);
      }
      return;
    }

    final hasPerm = await _recorder.hasPermission();
    if (!hasPerm) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.assistantMicDenied)),
      );
      return;
    }
    final dir = await getTemporaryDirectory();
    final file = '${dir.path}/assistant_${DateTime.now().millisecondsSinceEpoch}.wav';
    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        numChannels: 1,
        sampleRate: 16000,
      ),
      path: file,
    );
    setState(() => _recording = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.assistantStopRecording),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _speakReply(String text, String? audioBase64) async {
    if (audioBase64 != null && audioBase64.isNotEmpty) {
      final ok = await _playBase64(audioBase64);
      if (ok) return;
    }
    try {
      await _tts.stop();
      await _tts.speak(text);
    } catch (_) {
      // Local TTS is best-effort.
    }
  }

  Future<bool> _playBase64(String b64) async {
    try {
      final bytes = base64Decode(b64);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/assistant_tts.mp3');
      await file.writeAsBytes(Uint8List.fromList(bytes), flush: true);
      await _player.stop();
      await _player.play(DeviceFileSource(file.path));
      return true;
    } catch (_) {
      return false;
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.assistantTitle),
        actions: [
          IconButton(
            tooltip: _speakReplies ? 'Voz ON' : 'Voz OFF',
            onPressed: () => setState(() => _speakReplies = !_speakReplies),
            icon: Icon(_speakReplies ? Icons.volume_up : Icons.volume_off),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: _messages.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        l10n.assistantWelcome,
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                    itemCount: _messages.length,
                    itemBuilder: (context, i) {
                      final m = _messages[i];
                      return _Bubble(message: m);
                    },
                  ),
          ),
          if (_sending) const LinearProgressIndicator(minHeight: 2),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: Row(
                children: [
                  IconButton.filledTonal(
                    onPressed: _sending ? null : _toggleMic,
                    icon: Icon(_recording ? Icons.stop : Icons.mic),
                    tooltip: _recording
                        ? l10n.assistantStopRecording
                        : l10n.assistantStartRecording,
                    style: IconButton.styleFrom(
                      backgroundColor: _recording
                          ? theme.colorScheme.errorContainer
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: _sending ? null : _sendText,
                      decoration: InputDecoration(
                        hintText: l10n.assistantHint,
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _sending
                        ? null
                        : () => _sendText(_controller.text),
                    icon: const Icon(Icons.send),
                    tooltip: l10n.assistantSend,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _ChatMessage message;

  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final align =
        message.isUser ? Alignment.centerRight : Alignment.centerLeft;
    final bg = message.isUser
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.surfaceContainerHighest;
    final fg = message.isUser
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurface;

    return Align(
      alignment: align,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.85,
        ),
        child: Card(
          color: bg,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(message.text, style: TextStyle(color: fg)),
                if (message.toolsUsed.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'tools: ${message.toolsUsed.join(', ')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
                if (message.sources.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    message.sources.join('\n'),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: fg.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
