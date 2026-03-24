import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import 'image_service.dart';
import 'search_service.dart';
import 'storage_service.dart';

class ChatResponse {
  final String content;
  final String? imagePath;
  ChatResponse({required this.content, this.imagePath});
}

class OpenAIService {
  static const _apiUrl = 'https://api.openai.com/v1/chat/completions';
  static const _model = 'gpt-4o';
  static const _maxToolIterations = 5;

  static const _tools = [
    {
      'type': 'function',
      'function': {
        'name': 'web_search',
        'description':
            'Search the web for current information. Use when asked about recent events, facts you are unsure about, or when the user explicitly asks to search.',
        'parameters': {
          'type': 'object',
          'properties': {
            'query': {
              'type': 'string',
              'description': 'The search query',
            },
          },
          'required': ['query'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'fetch_page',
        'description':
            'Fetch and read the content of a specific URL. Use when the user provides a URL or when you need detailed information from a search result.',
        'parameters': {
          'type': 'object',
          'properties': {
            'url': {
              'type': 'string',
              'description': 'The URL to fetch',
            },
          },
          'required': ['url'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'generate_image',
        'description':
            'Generate an image based on a text prompt. Use when the user asks you to create, draw, generate, or make an image, picture, or illustration.',
        'parameters': {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description': 'Detailed description of the image to generate',
            },
            'size': {
              'type': 'string',
              'enum': ['1024x1024', '1024x1536', '1536x1024'],
              'description': 'Image dimensions. Default 1024x1024.',
            },
          },
          'required': ['prompt'],
        },
      },
    },
  ];

  /// Checks if the OpenAI API key is valid.
  /// Returns null if valid, or a warning message if not.
  static Future<String?> validateApiKey() async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';
    if (apiKey.isEmpty || apiKey == 'sk-placeholder') {
      return 'OpenAI API key not configured';
    }

    try {
      final response = await http.get(
        Uri.parse('https://api.openai.com/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 401) {
        return 'OpenAI API key is invalid';
      }
      if (response.statusCode != 200) {
        return 'OpenAI API check failed (HTTP ${response.statusCode})';
      }
      return null;
    } catch (_) {
      // Network error — don't warn about key, offline banner handles connectivity
      return null;
    }
  }

  /// Legacy simple method — no tools.
  static Future<String> sendMessages(List<Message> messages) async {
    final resp = await sendWithTools(messages);
    return resp.content;
  }

  static const _toolLabels = {
    'web_search': '\ud83d\udd0d Searching the web...',
    'fetch_page': '\ud83d\udcc4 Reading a page...',
    'generate_image': '\ud83c\udfa8 Drawing an image...',
  };

  static const _kidsSearchLabels = [
    'Asking the wise owl...',
    'Checking with the brainy robot...',
    'Peeking into the magic book...',
    'Sending a carrier pigeon...',
    'Asking the space hamster...',
    'Consulting the cookie oracle...',
    'Phoning a friendly dinosaur...',
    'Searching the treasure map...',
    'Asking Professor Penguin...',
    'Looking through the magic telescope...',
  ];

  static const _kidsFetchLabels = [
    'Reading the secret scroll...',
    'Unfolding the treasure map...',
    'Opening the magic envelope...',
    'Decoding the alien message...',
    'Reading the wizard\'s notes...',
    'Flipping through the adventure book...',
    'Checking the pirate\'s logbook...',
    'Peeking at the dragon\'s diary...',
    'Unrolling the ancient papyrus...',
    'Scanning the robot\'s memory...',
  ];

  static const _kidsImageLabels = [
    'Painting with rainbow brushes...',
    'The art hamster is drawing...',
    'Mixing magical colors...',
    'Waving the crayon wand...',
    'The pixel fairy is creating...',
    'Doodling something awesome...',
    'The robot artist is busy...',
    'Sprinkling creative dust...',
    'Drawing with invisible ink...',
    'The magic pencil is working...',
  ];

  static String _getToolLabel(String name, {bool kidsMode = false}) {
    if (!kidsMode) return _toolLabels[name] ?? 'Using $name...';

    final list = switch (name) {
      'web_search' => _kidsSearchLabels,
      'fetch_page' => _kidsFetchLabels,
      'generate_image' => _kidsImageLabels,
      _ => null,
    };
    if (list == null) return 'Doing something magical...';
    return list[DateTime.now().microsecond % list.length];
  }

  /// Sends messages with tool support. Loops until the model produces a
  /// final text response or the iteration limit is reached.
  static Future<ChatResponse> sendWithTools(
    List<Message> messages, {
    void Function(String status)? onToolCall,
    bool kidsMode = false,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

    // Build the conversation payload (mutable, grows with tool results)
    final conversation = messages
        .map((m) => <String, dynamic>{'role': m.role, 'content': m.content})
        .toList();

    String? imagePath;

    for (var i = 0; i < _maxToolIterations; i++) {
      final body = <String, dynamic>{
        'model': _model,
        'messages': conversation,
        'temperature': 0.7,
        'tools': _tools,
      };
      // NOTE: no 'response_format' — incompatible with tools (Bug 2)

      final response = await http
          .post(
            Uri.parse(_apiUrl),
            headers: {
              'Authorization': 'Bearer $apiKey',
              'Content-Type': 'application/json',
            },
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 60));

      if (response.statusCode != 200) {
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choice = (data['choices'] as List).first as Map<String, dynamic>;
      final finishReason = choice['finish_reason'] as String;
      final msg = choice['message'] as Map<String, dynamic>;

      if (finishReason == 'tool_calls') {
        // Append the assistant message (with tool_calls) to conversation
        conversation.add(msg);

        final toolCalls = msg['tool_calls'] as List;
        for (final tc in toolCalls) {
          final fn = tc['function'] as Map<String, dynamic>;
          final name = fn['name'] as String;
          final args =
              jsonDecode(fn['arguments'] as String) as Map<String, dynamic>;
          final callId = tc['id'] as String;

          String result;
          onToolCall?.call(_getToolLabel(name, kidsMode: kidsMode));

          switch (name) {
            case 'web_search':
              result = await SearchService.search(args['query'] as String);
              break;
            case 'fetch_page':
              result = await SearchService.fetchPage(args['url'] as String);
              break;
            case 'generate_image':
              try {
                final b64 = await ImageService.generateImage(
                  prompt: args['prompt'] as String,
                  size: (args['size'] as String?) ?? '1024x1024',
                );
                final msgId = 'img_${DateTime.now().microsecondsSinceEpoch}';
                imagePath = await StorageService.saveImage(b64, msgId);
                result = 'Image generated successfully.';
              } catch (e) {
                result = 'Image generation failed: $e';
              }
              break;
            default:
              result = 'Unknown tool: $name';
          }

          conversation.add({
            'role': 'tool',
            'tool_call_id': callId,
            'content': result,
          });
        }
        // Loop to send tool results back to the model
        continue;
      }

      // finish_reason == 'stop' (or 'length') — return text
      final content = (msg['content'] as String?) ?? '';
      return ChatResponse(content: content.trim(), imagePath: imagePath);
    }

    // Safety: max iterations reached
    return ChatResponse(
      content: 'I ran into a problem processing tool calls. Please try again.',
      imagePath: imagePath,
    );
  }
}
