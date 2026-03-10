import 'dart:convert';

import '../../../data/remote/llm/llm_client.dart';
import '../../../data/repositories/conversation_repository.dart';
import 'retirement_prompts.dart';

/// Conversation purpose constants.
class ConversationPurpose {
  ConversationPurpose._();
  static const general = 'general';
  static const retirement = 'retirement';
}

/// Structured retirement parameters extracted from an interview conversation.
class RetirementParams {
  final String goalName;
  final int monthlyContributionCents;
  final int annualReturnBps;
  final int annualVolatilityBps;
  final int retirementYear;
  final int desiredMonthlyIncomeCents;

  const RetirementParams({
    required this.goalName,
    required this.monthlyContributionCents,
    required this.annualReturnBps,
    required this.annualVolatilityBps,
    required this.retirementYear,
    required this.desiredMonthlyIncomeCents,
  });

  /// Target nest egg computed via the 4% withdrawal (25x annual) rule.
  int get targetAmountCents => computeTargetAmount(desiredMonthlyIncomeCents);

  /// Compute target nest egg from desired monthly income via 4% withdrawal (25x annual) rule.
  static int computeTargetAmount(int desiredMonthlyIncomeCents) =>
      desiredMonthlyIncomeCents * 12 * 25;
}

/// One-shot LLM extraction of retirement parameters from a conversation.
///
/// Follows the [BudgetSuggestionService] pattern: reads conversation history,
/// makes a single `client.complete()` call with strict JSON-only prompt,
/// parses and validates the result.
class RetirementParamsExtractor {
  RetirementParamsExtractor({required ConversationRepository conversationRepo})
      : _conversationRepo = conversationRepo;

  final ConversationRepository _conversationRepo;

  /// Extract retirement parameters from a completed interview conversation.
  ///
  /// Returns null if the LLM response is malformed or fails validation.
  Future<RetirementParams?> extract(
    LlmClient client,
    String conversationId,
  ) async {
    final messages = await _conversationRepo.getMessages(conversationId);
    if (messages.isEmpty) return null;

    // Build transcript for the extraction prompt
    final transcript = StringBuffer();
    for (final m in messages) {
      final role = m.role == 'user' ? 'User' : 'Assistant';
      transcript.writeln('$role: ${m.content}');
    }

    final response = await client.complete(
      retirementExtractionPrompt,
      [
        ChatMessage(
          role: 'user',
          content: 'Here is the conversation:\n\n$transcript',
        ),
      ],
    );

    return _parse(response);
  }

  RetirementParams? _parse(String response) {
    var jsonStr = response.trim();

    // Strip markdown code blocks if present
    if (jsonStr.contains('```')) {
      final match =
          RegExp(r'```(?:json)?\s*\n?([\s\S]*?)\n?```').firstMatch(jsonStr);
      if (match != null) jsonStr = match.group(1)!.trim();
    }

    // Find JSON object boundaries
    final objStart = jsonStr.indexOf('{');
    final objEnd = jsonStr.lastIndexOf('}');
    if (objStart == -1 || objEnd == -1 || objEnd <= objStart) return null;
    jsonStr = jsonStr.substring(objStart, objEnd + 1);

    try {
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;

      final goalName = map['goalName'] as String? ?? 'Retirement Plan';
      final contribution = (map['monthlyContributionCents'] as num?)?.toInt();
      final returnBps = (map['annualReturnBps'] as num?)?.toInt();
      final volBps = (map['annualVolatilityBps'] as num?)?.toInt();
      final year = (map['retirementYear'] as num?)?.toInt();
      final income = (map['desiredMonthlyIncomeCents'] as num?)?.toInt();

      if (contribution == null ||
          returnBps == null ||
          volBps == null ||
          year == null ||
          income == null) {
        return null;
      }

      // Bounds validation
      final currentYear = DateTime.now().year;
      if (contribution <= 0) return null;
      if (year <= currentYear || year > currentYear + 60) return null;
      if (returnBps < 100 || returnBps > 1200) return null;
      if (volBps < 300 || volBps > 3000) return null;
      if (income <= 0) return null;

      return RetirementParams(
        goalName: goalName,
        monthlyContributionCents: contribution,
        annualReturnBps: returnBps,
        annualVolatilityBps: volBps,
        retirementYear: year,
        desiredMonthlyIncomeCents: income,
      );
    } catch (_) {
      return null;
    }
  }
}
