// lib/pages/chat_page.dart
import 'package:flutter/material.dart';
import '../state/destination_state.dart';
import '../services/live_socket.dart';
import '../models/chat_msg.dart';
import '../services/session.dart';

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _focus = FocusNode();

  late final LiveSocket live;
  Stream<ChatMsg>? _sub;
  final List<ChatMsg> _messages = <ChatMsg>[];

  String? _contrato;
  String? _cliente;
  int? _reportId;
  int? _tecId;

  @override
  void initState() {
    super.initState();

    _contrato = DestinationState.instance.contract.value;
    _cliente  = DestinationState.instance.client.value;
    _reportId = DestinationState.instance.reportId.value;
    _tecId    = Session.instance.idTec.value;

    // Guard si no hay En Camino
    if (_reportId == null || (_contrato == null || _contrato!.isEmpty)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No hay ruta En Camino para iniciar chat.')),
        );
        Navigator.of(context).maybePop();
      });
      return;
    }

    // Reutiliza tu instancia global si la tienes; si no, crea una nueva.
    live = LiveSocket();
    // Conéctate si no lo está (puedes mover serverUrl a tu config)
    live.connect(
      serverUrl: 'http://167.99.163.209:3001',
      reportId: _reportId!,
      tecId: _tecId,
    );

    // Carga historial al entrar
    live.requestHistory(limit: 50);

    // Suscríbete a mensajes
    _sub = live.chatStream;
    _sub!.listen((msg) {
      if (!mounted) return;
      // Asegura que corresponda a este reportId
      if (msg.reportId != _reportId) return;
      setState(() {
        _messages.add(msg);
      });
      _scrollToBottom();
    });

    // Si ya había buffer previo (por reconexiones), hidrata
    for (final m in live.chatBuffer.where((m) => m.reportId == _reportId)) {
      _messages.add(m);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollCtrl.dispose();
    _focus.dispose();
    // No cierres el socket aquí si lo usas globalmente para live tracking
    super.dispose();
  }

  void _send() {
    final txt = _controller.text.trim();
    if (txt.isEmpty || _reportId == null) return;
    live.sendChat(reportId: _reportId!, tecId: _tecId, text: txt);
    _controller.clear();
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      _scrollCtrl.animateTo(
        _scrollCtrl.position.maxScrollExtent + 80,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final hasDest = DestinationState.instance.selected.value != null;
    if (!hasDest || _contrato == null) {
      return Scaffold(appBar: AppBar(title: const Text('Chat')), body: const SizedBox.shrink());
    }

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final myColor = const Color.fromARGB(255, 8, 95, 176);

    return Scaffold(
      appBar: AppBar(
        title: Text(_cliente?.isNotEmpty == true ? _cliente! : 'Contrato $_contrato'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(22),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              'Contrato: $_contrato${_reportId != null ? "  •  Rep: $_reportId" : ""}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.white70),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (_, i) {
                final m = _messages[i];
                final isMe = m.from == 'tech';
                final align = isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start;
                final bubbleColor = isMe ? myColor : const Color(0xFFE9F1FB);
                final textColor = isMe ? Colors.white : const Color(0xFF0F172A);

                return Column(
                  crossAxisAlignment: align,
                  children: [
                    Container(
                      margin: EdgeInsets.only(
                        top: 6, bottom: 6,
                        left: isMe ? 60 : 0,
                        right: isMe ? 0 : 60,
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: bubbleColor,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(14),
                          topRight: const Radius.circular(14),
                          bottomLeft: Radius.circular(isMe ? 14 : 4),
                          bottomRight: Radius.circular(isMe ? 4 : 14),
                        ),
                        boxShadow: const [BoxShadow(blurRadius: 2, offset: Offset(0,1), color: Color(0x14000000))],
                      ),
                      child: Text(m.text, style: TextStyle(color: textColor)),
                    ),
                  ],
                );
              },
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: EdgeInsets.fromLTRB(12, 8, 12, 8 + (bottomInset > 0 ? 8 : 12)),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focus,
                    minLines: 1, maxLines: 4,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: InputDecoration(
                      hintText: 'Escribe un mensaje…',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 44, width: 44,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      backgroundColor: myColor, foregroundColor: Colors.white,
                    ),
                    onPressed: _send,
                    child: const Icon(Icons.send),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
