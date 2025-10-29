class ChatMsg {
  final int reportId;     // IDReporte
  final String from;      // 'tech' | 'client' | 'system'
  final int? senderId;    // tecId o null
  final String text;
  final int ts;           // epoch ms

  const ChatMsg({
    required this.reportId,
    required this.from,
    required this.text,
    required this.ts,
    this.senderId,
  });

  factory ChatMsg.fromMap(Map<String, dynamic> m) => ChatMsg(
        reportId: int.tryParse('${m['reportId']}') ?? 0,
        from: (m['from'] ?? 'system').toString(),
        senderId: m['senderId'] == null ? null : int.tryParse('${m['senderId']}'),
        text: (m['text'] ?? '').toString(),
        ts: int.tryParse('${m['ts']}') ?? DateTime.now().millisecondsSinceEpoch,
      );

  Map<String, dynamic> toMap() => {
        'reportId': reportId,
        'from': from,
        'senderId': senderId,
        'text': text,
        'ts': ts,
      };
}
