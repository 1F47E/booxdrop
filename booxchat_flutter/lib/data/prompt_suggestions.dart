import 'dart:math';

const _generic = <String>[
  'Summarize this for me',
  'Help me brainstorm ideas',
  'Explain like I\'m five',
  'Write a short story',
  'Help me draft an email',
  'What are the pros and cons?',
  'Give me a fun fact',
  'Help me with a recipe',
  'Translate something for me',
  'Explain how this works',
  'Write a poem about anything',
  'Help me plan my day',
  'Tell me something surprising',
  'Help me solve a problem',
  'What should I read next?',
  'Give me a creative writing prompt',
  'Help me learn a new word',
  'Explain a scientific concept',
  'What happened on this day in history?',
  'Help me practice a language',
  'Describe a place I should visit',
  'Help me with a math problem',
  'Write a haiku',
  'Give me a trivia question',
  'Help me think through a decision',
  'Suggest a movie or show',
  'Explain an idiom or saying',
  'Help me write a list',
  'Tell me about a famous person',
  'Draw me something cool',
];

const _young = <String>[
  // Stories & imagination
  'Tell me a bedtime story',
  'Make up a story about a dragon',
  'Tell me a fairy tale',
  'What if animals could talk?',
  'Tell me a story about a brave cat',
  'Make up a silly story',
  'Tell me about a magic forest',
  'What if I could fly?',
  'Tell me a pirate adventure',
  'Story about a friendly monster',

  // Drawing & images
  'Draw me a unicorn',
  'Draw a funny robot',
  'Draw a castle in the clouds',
  'Draw my favorite animal',
  'Draw a spaceship',
  'Draw a rainbow fish',
  'Draw a dinosaur family',
  'Draw a superhero pet',

  // Fun facts & learning
  'What\'s the biggest animal ever?',
  'Why is the sky blue?',
  'How do rainbows happen?',
  'Tell me about baby animals',
  'What do astronauts eat?',
  'How big is the sun?',
  'Why do cats purr?',
  'Tell me about butterflies',
  'What lives in the ocean?',
  'How do birds fly?',

  // Games & fun
  'Tell me a joke',
  'Tell me a riddle',
  'Let\'s play a guessing game',
  'Tell me a tongue twister',
  'Let\'s count in another language',
  'What rhymes with cat?',
  'Tell me a knock-knock joke',
  'Let\'s play 20 questions',

  // Simple learning
  'Help me spell a tricky word',
  'What\'s 7 plus 8?',
  'Teach me a fun word',
  'How do you say hello in French?',
  'What colors make green?',
  'How many planets are there?',
  'What\'s the tallest mountain?',
  'Where do penguins live?',
  'What do bees make?',
  'How does a rainbow form?',
  'Tell me about the moon',
  'What\'s the fastest animal?',
];

const _older = <String>[
  // Science & discovery
  'How do volcanoes work?',
  'Explain how the internet works',
  'What happens inside a black hole?',
  'How does electricity work?',
  'Tell me about the solar system',
  'How do computers think?',
  'What causes earthquakes?',
  'How does DNA work?',
  'Explain gravity to me',
  'What\'s inside an atom?',

  // Homework & learning
  'Help me with math homework',
  'Explain fractions step by step',
  'Help me understand percentages',
  'What are the parts of a cell?',
  'Explain the water cycle',
  'Help me with geography',
  'What causes the seasons?',
  'Explain how magnets work',
  'Help me learn about history',
  'What is photosynthesis?',

  // Creative
  'Help me write a poem',
  'Write me a mystery story',
  'Help me create a comic idea',
  'Write a story where I\'m the hero',
  'Help me write a song',
  'Create a fantasy world for me',
  'Write a sci-fi adventure',
  'Help me write a letter',

  // Drawing
  'Draw an alien planet',
  'Draw a futuristic city',
  'Draw a mythical creature',
  'Draw a treasure map',
  'Draw a robot of the future',

  // Curiosity
  'What\'s happening in space right now?',
  'Tell me about ancient civilizations',
  'How do animals survive winter?',
  'What are the deepest ocean creatures?',
  'How do planes stay in the air?',
  'Tell me about famous inventors',
  'What\'s the hardest language to learn?',
  'How do movies get made?',
  'Tell me about the tallest buildings',
  'What are the wonders of the world?',

  // Games & challenges
  'Give me a brain teaser',
  'Write me a tricky riddle',
  'Quiz me on science',
  'Let\'s play a word game',
  'Challenge me with a math puzzle',
  'Tell me an amazing world record',
  'Quiz me on world capitals',
  'Give me a logic puzzle',
];

final _random = Random();

List<String> getRandomSuggestions({
  required int count,
  required bool kidsMode,
  required int kidsAge,
}) {
  final List<String> pool;
  if (!kidsMode) {
    pool = _generic;
  } else if (kidsAge <= 8) {
    pool = _young;
  } else {
    pool = _older;
  }

  final shuffled = List<String>.from(pool)..shuffle(_random);
  return shuffled.take(count.clamp(1, pool.length)).toList();
}
