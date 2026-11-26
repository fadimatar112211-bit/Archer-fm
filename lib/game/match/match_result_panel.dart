import 'package:flutter/material.dart';

/// Renders only the authoritative result payload supplied by the match host.
class MatchResultPanel extends StatelessWidget {
  const MatchResultPanel({
    super.key,
    required this.result,
    required this.localPlayerId,
  });

  final Map<String, dynamic> result;
  final String localPlayerId;

  @override
  Widget build(BuildContext context) {
    final winner = result['winnerId'];
    final tied = result['tiedPlayerIds'] is List
        ? (result['tiedPlayerIds'] as List).whereType<String>().toList()
        : const <String>[];
    final reason = result['reason'];
    final standings = result['standings'] is List
        ? result['standings'] as List
        : const <dynamic>[];
    final winnerLabel = winner is String && winner.isNotEmpty
        ? 'الفائز: اللاعب $winner'
        : tied.isNotEmpty
            ? 'تعادل بين: ${tied.map((id) => 'اللاعب $id').join('، ')}'
            : 'انتهت المباراة دون فائز معلن';
    final reasonLabel = switch (reason) {
      'lastCrystalHolder' => 'حُسمت المباراة ببقاء بلورات لاعب واحد',
      'timeExpired' => 'انتهى وقت المباراة وحُسم الترتيب بالنقاط والبلورات',
      _ => 'النتيجة النهائية',
    };

    return Card(
      color: const Color(0xFF263B32),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              winnerLabel,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(reasonLabel, style: const TextStyle(color: Colors.white70)),
            const Divider(),
            for (final entry in standings)
              if (entry is Map)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 34,
                        child: Text('#${entry['rank'] ?? '—'}'),
                      ),
                      Expanded(
                        child: Text(
                          'اللاعب ${entry['playerId'] ?? '—'}'
                          '${entry['playerId'] == localPlayerId ? ' (أنت)' : ''}'
                          '${entry['hasForfeited'] == true ? ' · انسحب' : ''}',
                          style: TextStyle(
                            fontWeight: entry['playerId'] == localPlayerId
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                      Text('النقاط ${entry['score'] ?? 0}'),
                      const SizedBox(width: 10),
                      Text('البلورات ${entry['livingCrystals'] ?? 0}/7'),
                    ],
                  ),
                ),
          ],
        ),
      ),
    );
  }
}
