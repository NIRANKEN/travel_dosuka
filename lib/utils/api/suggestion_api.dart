import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../log.dart';

/// travel-suggestion-apiバックエンドへの旅行提案API呼び出しユーティリティ
class SuggestionApi {
  /// デフォルトのAPIベースURL。
  /// 環境変数や設定ファイルで上書きする想定。
  static const String _defaultBaseUrl = 'http://localhost:3000';

  final String baseUrl;
  final http.Client _client;

  SuggestionApi({
    String? baseUrl,
    http.Client? client,
  })  : baseUrl = baseUrl ?? _defaultBaseUrl,
        _client = client ?? http.Client();

  /// RAG検索で旅行提案を取得する（認証あり）
  Future<SuggestionResult> search({
    required String question,
    required String idToken,
  }) async {
    final Uri uri = Uri.parse('$baseUrl/api/v1/search');
    try {
      final http.Response response = await _client.post(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'question': question}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return SuggestionResult.fromJson(data);
      } else {
        logger.w('Search API error: ${response.statusCode} ${response.body}');
        throw SuggestionApiException(
          statusCode: response.statusCode,
          message: 'APIエラーが発生しました',
        );
      }
    } catch (e) {
      if (e is SuggestionApiException) rethrow;
      logger.e('Search API request failed', error: e);
      throw SuggestionApiException(
        statusCode: 0,
        message: 'ネットワークエラーが発生しました',
      );
    }
  }

  /// シンプルなチャット（認証なし）
  Future<String> chat({required String question}) async {
    final Uri uri = Uri.parse('$baseUrl/chat');
    try {
      final http.Response response = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'question': question}),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data =
            jsonDecode(response.body) as Map<String, dynamic>;
        return data['answer'] as String? ?? '';
      } else {
        logger.w('Chat API error: ${response.statusCode}');
        throw SuggestionApiException(
          statusCode: response.statusCode,
          message: 'APIエラーが発生しました',
        );
      }
    } catch (e) {
      if (e is SuggestionApiException) rethrow;
      logger.e('Chat API request failed', error: e);
      throw SuggestionApiException(
        statusCode: 0,
        message: 'ネットワークエラーが発生しました',
      );
    }
  }
}

class SuggestionResult {
  final String question;
  final String answer;
  final List<String> sources;

  const SuggestionResult({
    required this.question,
    required this.answer,
    required this.sources,
  });

  factory SuggestionResult.fromJson(Map<String, dynamic> json) {
    return SuggestionResult(
      question: json['question'] as String? ?? '',
      answer: json['answer'] as String? ?? '',
      sources: (json['sources'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          [],
    );
  }
}

class SuggestionApiException implements Exception {
  final int statusCode;
  final String message;

  const SuggestionApiException({
    required this.statusCode,
    required this.message,
  });

  @override
  String toString() => 'SuggestionApiException($statusCode): $message';
}
