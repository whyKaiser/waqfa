import 'dart:convert';

import 'package:http/http.dart' as http;

class AiProviderResponse {
  final bool ok;
  final int statusCode;
  final String content;
  final String errorCode;

  const AiProviderResponse({
    required this.ok,
    required this.statusCode,
    required this.content,
    this.errorCode = '',
  });

  factory AiProviderResponse.failure(String code, {int statusCode = 0}) =>
      AiProviderResponse(
        ok: false,
        statusCode: statusCode,
        content: '',
        errorCode: code,
      );
}

class AiTextRequest {
  final String systemPrompt;
  final String userPrompt;
  final double temperature;
  final int maxTokens;
  final bool requireJson;

  const AiTextRequest({
    required this.systemPrompt,
    required this.userPrompt,
    this.temperature = .4,
    this.maxTokens = 500,
    this.requireJson = false,
  });
}

class AiImageRequest {
  final String prompt;
  final String base64Jpeg;
  final double temperature;
  final int maxTokens;
  final bool requireJson;

  const AiImageRequest({
    required this.prompt,
    required this.base64Jpeg,
    this.temperature = .2,
    this.maxTokens = 500,
    this.requireJson = true,
  });
}

/// Provider-neutral boundary. Financial calculations never cross this API;
/// providers only receive already-calculated facts or an explicitly approved
/// receipt image.
abstract interface class GenerativeAiProvider {
  String get name;
  bool get isConfigured;

  Future<AiProviderResponse> generateText(AiTextRequest request);

  Future<AiProviderResponse> analyzeImage(AiImageRequest request);
}

class GroqGenerativeAiProvider implements GenerativeAiProvider {
  final String apiKey;
  final String model;
  final Uri endpoint;
  final http.Client _client;

  GroqGenerativeAiProvider({
    required this.apiKey,
    required this.model,
    http.Client? client,
    Uri? endpoint,
  })  : _client = client ?? http.Client(),
        endpoint = endpoint ??
            Uri.parse('https://api.groq.com/openai/v1/chat/completions');

  @override
  String get name => 'Groq';

  @override
  bool get isConfigured => apiKey.trim().isNotEmpty;

  @override
  Future<AiProviderResponse> generateText(AiTextRequest request) async {
    if (!isConfigured) return AiProviderResponse.failure('not_configured');
    try {
      final body = <String, Object>{
        'model': model,
        'reasoning_effort': 'none',
        'reasoning_format': 'hidden',
        'temperature': request.temperature,
        'messages': [
          {'role': 'system', 'content': request.systemPrompt},
          {'role': 'user', 'content': request.userPrompt},
        ],
        'max_tokens': request.maxTokens,
      };
      if (request.requireJson) {
        body['response_format'] = {'type': 'json_object'};
      }
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 12));
      return _decode(response);
    } catch (_) {
      return AiProviderResponse.failure('network_error');
    }
  }

  @override
  Future<AiProviderResponse> analyzeImage(AiImageRequest request) async {
    if (!isConfigured) return AiProviderResponse.failure('not_configured');
    try {
      final body = <String, Object>{
        'model': model,
        'reasoning_effort': 'none',
        'reasoning_format': 'hidden',
        'temperature': request.temperature,
        'max_tokens': request.maxTokens,
        'messages': [
          {
            'role': 'user',
            'content': [
              {'type': 'text', 'text': request.prompt},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:image/jpeg;base64,${request.base64Jpeg}',
                },
              },
            ],
          },
        ],
      };
      if (request.requireJson) {
        body['response_format'] = {'type': 'json_object'};
      }
      final response = await _client
          .post(
            endpoint,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $apiKey',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 25));
      return _decode(response);
    } catch (_) {
      return AiProviderResponse.failure('network_error');
    }
  }

  AiProviderResponse _decode(http.Response response) {
    if (response.statusCode != 200) {
      return AiProviderResponse.failure(
        'http_${response.statusCode}',
        statusCode: response.statusCode,
      );
    }
    try {
      final data = jsonDecode(response.body);
      final content = data['choices']?[0]?['message']?['content'];
      if (content is! String || content.trim().isEmpty) {
        return AiProviderResponse.failure('empty_response', statusCode: 200);
      }
      return AiProviderResponse(
        ok: true,
        statusCode: 200,
        content: content,
      );
    } catch (_) {
      return AiProviderResponse.failure('invalid_response', statusCode: 200);
    }
  }
}
