import 'package:flutter/material.dart';

import '../services/ai_service.dart';
import '../services/sos_service.dart';

class AiAssistantScreen extends StatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  State<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends State<AiAssistantScreen> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [
    const _ChatMessage(
      role: 'assistant',
      text: 'I’m GuardianX AI. Tell me what is happening and I’ll help you '
          'choose the safest next step.',
    ),
  ];
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    final history = _messages
        .map((item) => {'role': item.role, 'content': item.text})
        .toList(growable: false);

    _controller.clear();
    setState(() {
      _sending = true;
      _messages.add(_ChatMessage(role: 'user', text: text));
    });
    _scrollToEnd();

    try {
      final reply = await AiService.ask(message: text, history: history);
      if (!mounted) return;
      setState(() => _messages.add(_ChatMessage(role: 'assistant', text: reply)));
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _messages.add(
          _ChatMessage(role: 'assistant', text: 'Unable to connect: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _sending = false);
        _scrollToEnd();
      }
    }
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('GuardianX AI')),
      body: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF171717),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  const Icon(Icons.emergency_outlined),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'Immediate danger? Use emergency services instead of waiting for AI.',
                      style: TextStyle(fontSize: 12, color: Colors.white70),
                    ),
                  ),
                  TextButton(
                    onPressed: () async {
                      try {
                        await SosService.callEmergency();
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(e.toString())),
                        );
                      }
                    },
                    child: const Text('112'),
                  ),
                ],
              ),
            ),
            if (!AiService.configured)
              const Padding(
                padding: EdgeInsets.fromLTRB(18, 8, 18, 4),
                child: Text(
                  'AI is in setup mode. Configure GUARDIANX_AI_PROXY or a development GROQ_API_KEY.',
                  style: TextStyle(color: Colors.amberAccent, fontSize: 12),
                ),
              ),
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final item = _messages[index];
                  final user = item.role == 'user';
                  return Align(
                    alignment:
                        user ? Alignment.centerRight : Alignment.centerLeft,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 520),
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: user ? Colors.white : const Color(0xFF1B1B1B),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Text(
                        item.text,
                        style: TextStyle(
                          color: user ? Colors.black : Colors.white,
                          height: 1.35,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                14,
                8,
                14,
                12 + MediaQuery.viewInsetsOf(context).bottom,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about a safety situation…',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  IconButton.filled(
                    onPressed: _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.role, required this.text});

  final String role;
  final String text;
}
