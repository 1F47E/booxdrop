import 'dart:convert';
import 'dart:io';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import '../models/message.dart';
import '../providers/settings_provider.dart';
import 'image_service.dart';
import 'log_service.dart';
import 'search_service.dart';
import 'storage_service.dart';
import 'tts_service.dart';

final _log = LogService.instance;

class ChatResponse {
  final String content;
  final String? imagePath;
  final String? audioPath;
  ChatResponse({required this.content, this.imagePath, this.audioPath});
}

class OpenAIService {
  static const _apiUrl = 'https://api.openai.com/v1/chat/completions';
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
            'Generate a new image from a text description. Use when the user asks to create, draw, or make an image and there is no previous image to edit.',
        'parameters': {
          'type': 'object',
          'properties': {
            'prompt': {
              'type': 'string',
              'description': 'Detailed description of the image to generate',
            },
          },
          'required': ['prompt'],
        },
      },
    },
    {
      'type': 'function',
      'function': {
        'name': 'edit_image',
        'description':
            'Edit or modify a previously generated image. Use when the user wants to change, adjust, add to, or modify an existing image in the conversation.',
        'parameters': {
          'type': 'object',
          'properties': {
            'instruction': {
              'type': 'string',
              'description': 'What to change about the image',
            },
          },
          'required': ['instruction'],
        },
      },
    },
  ];

  static const _ttsTool = {
    'type': 'function',
    'function': {
      'name': 'text_to_speech',
      'description':
          'Convert text to speech audio. Use when the user asks to hear, read aloud, narrate, tell a story out loud, or wants audio/voice output. Keep text under 500 characters (~1 minute of speech) to control costs. For longer content, summarize or break into parts.',
      'parameters': {
        'type': 'object',
        'properties': {
          'text': {
            'type': 'string',
            'description':
                'The text to convert to speech. Write naturally as spoken prose — no bullet points, markdown, or formatting. Max ~500 characters.',
          },
        },
        'required': ['text'],
      },
    },
  };

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

  static const _toolLabels = {
    'web_search': '\ud83d\udd0d Searching the web...',
    'fetch_page': '\ud83d\udcc4 Reading a page...',
    'generate_image': '\ud83c\udfa8 Drawing an image...',
    'edit_image': '\u270f\ufe0f Editing the image...',
    'text_to_speech': '\ud83d\udd0a Generating audio...',
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

  static const _kidsTtsLabels = [
    'The robot is learning to speak...',
    'Warming up the voice box...',
    'The parrot is rehearsing...',
    'Tuning the magic microphone...',
    'The storyteller is getting ready...',
    'Clearing the dragon\'s throat...',
    'Charging the voice crystals...',
    'The wizard is composing...',
    'Polishing the words...',
    'Practicing in the mirror...',
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
      'generate_image' || 'edit_image' => _kidsImageLabels,
      'text_to_speech' => _kidsTtsLabels,
      _ => null,
    };
    if (list == null) return 'Doing something magical...';
    return list[DateTime.now().microsecond % list.length];
  }

  /// Sends messages with tool support. Loops until the model produces a
  /// final text response or the iteration limit is reached.
  static Future<ChatResponse> sendWithTools(
    List<Message> messages, {
    required SettingsProvider settings,
    void Function(String status)? onToolCall,
    bool kidsMode = false,
  }) async {
    final apiKey = dotenv.env['OPENAI_API_KEY'] ?? '';

    // Build the conversation payload (mutable, grows with tool results).
    final conversation = <Map<String, dynamic>>[];
    for (final m in messages) {
      if (m.role == 'user' && m.imagePath != null) {
        // Multimodal user message: text + image for GPT-4o vision
        try {
          final imgFile = File(m.imagePath!);
          final bytes = await imgFile.readAsBytes();
          final b64 = base64Encode(bytes);
          final lower = m.imagePath!.toLowerCase();
          final mime = lower.endsWith('.jpg') || lower.endsWith('.jpeg')
              ? 'image/jpeg'
              : 'image/png';
          conversation.add({
            'role': 'user',
            'content': [
              {'type': 'text', 'text': m.content},
              {
                'type': 'image_url',
                'image_url': {
                  'url': 'data:$mime;base64,$b64',
                  'detail': 'auto',
                },
              },
            ],
          });
        } catch (_) {
          // File missing — send text only
          conversation.add({'role': m.role, 'content': m.content});
        }
      } else if (m.role == 'assistant' && m.imagePath != null) {
        final tag = '[An image was generated and displayed to the user]';
        final content = m.content.isEmpty ? tag : '${m.content}\n$tag';
        conversation.add({'role': m.role, 'content': content});
      } else {
        conversation.add({'role': m.role, 'content': m.content});
      }
    }

    String? imagePath;
    String? audioPath;
    // Track the latest image path across tool iterations so edit_image
    // can reference an image generated earlier in the same turn.
    String? latestImagePath = messages.reversed
        .where((m) => m.imagePath != null)
        .map((m) => m.imagePath!)
        .firstOrNull;

    for (var i = 0; i < _maxToolIterations; i++) {
      final tools = [
        ..._tools,
        if (settings.availableTtsProviders.isNotEmpty) _ttsTool,
      ];
      final model = settings.chatModel;
      final isReasoning = model.startsWith('gpt-5');
      final body = <String, dynamic>{
        'model': model,
        'messages': conversation,
        'tools': tools,
        if (isReasoning) 'reasoning_effort': 'medium',
        if (!isReasoning) 'temperature': 0.7,
      };

      _log.info('chat', 'Sending ${conversation.length} msgs to $model');
      final sw = Stopwatch()..start();
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
      sw.stop();

      if (response.statusCode != 200) {
        _log.error('chat', '$model HTTP ${response.statusCode}');
        throw Exception(
            'OpenAI error ${response.statusCode}: ${response.body}');
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final choice = (data['choices'] as List).first as Map<String, dynamic>;
      final finishReason = choice['finish_reason'] as String;
      final msg = choice['message'] as Map<String, dynamic>;
      _log.debug('chat', '$model ${sw.elapsedMilliseconds}ms, reason: $finishReason');

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
          _log.info('chat', 'Tool: $name');
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
                final imgPrompt = args['prompt'] as String;
                final provider = ImageService.getProvider(settings);
                final b64 = await provider.generate(prompt: imgPrompt);
                final msgId = 'img_${DateTime.now().microsecondsSinceEpoch}';
                imagePath = await StorageService.saveImage(b64, msgId);
                latestImagePath = imagePath;
                _log.info('image', 'Generated via ${provider.name}');
                result =
                    'Image generated and displayed to the user. Prompt used: "$imgPrompt"';
              } catch (e) {
                _log.error('image', 'Generation failed: $e');
                result = 'Image generation failed: $e';
              }
              break;
            case 'edit_image':
              try {
                final provider = ImageService.getProvider(settings);
                if (!provider.supportsEdit) {
                  result =
                      'Image editing is not supported with ${provider.name}. Use generate_image to create a new image instead.';
                  break;
                }
                if (latestImagePath == null) {
                  result =
                      'No previous image found to edit. Use generate_image to create a new one.';
                  break;
                }
                final instruction = args['instruction'] as String;
                final b64 = await provider.edit(
                  imagePath: latestImagePath,
                  instruction: instruction,
                );
                final msgId = 'img_${DateTime.now().microsecondsSinceEpoch}';
                imagePath = await StorageService.saveImage(b64, msgId);
                latestImagePath = imagePath;
                _log.info('image', 'Edited via ${provider.name}');
                result =
                    'Image edited and displayed to the user. Instruction: "$instruction"';
              } catch (e) {
                _log.error('image', 'Edit failed: $e');
                result = 'Image editing failed: $e';
              }
              break;
            case 'text_to_speech':
              try {
                if (audioPath != null) {
                  result = 'Audio already generated this turn.';
                  break;
                }
                var ttsText = (args['text'] as String).trim();
                if (ttsText.isEmpty) {
                  result = 'Text-to-speech skipped: text was empty.';
                  break;
                }
                // Hard limit to ~500 chars (~1 min speech) to control costs
                if (ttsText.length > 500) {
                  ttsText = ttsText.substring(0, 500);
                }
                final ttsProvider = TtsService.getProvider(settings);
                final bytes = await ttsProvider.speak(
                  text: ttsText,
                  voice: settings.ttsVoice,
                );
                final msgId = 'tts_${DateTime.now().microsecondsSinceEpoch}';
                audioPath ??= await StorageService.saveAudio(bytes, msgId);
                _log.info('tts', 'Generated via ${ttsProvider.name}');
                result =
                    'Audio generated and will play for the user. Do NOT repeat the spoken text in your response — just acknowledge briefly or continue the conversation.';
              } catch (e) {
                _log.error('tts', 'Generation failed: $e');
                result = 'Text-to-speech failed: $e';
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
      return ChatResponse(
          content: content.trim(), imagePath: imagePath, audioPath: audioPath);
    }

    // Safety: max iterations reached
    return ChatResponse(
      content: 'I ran into a problem processing tool calls. Please try again.',
      imagePath: imagePath,
      audioPath: audioPath,
    );
  }
}
