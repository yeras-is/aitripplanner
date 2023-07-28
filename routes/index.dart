// ignore_for_file: lines_longer_than_80_chars, non_constant_identifier_names, missing_whitespace_between_adjacent_strings, unnecessary_statements, use_string_buffers

import 'dart:async';
import 'dart:convert';

import 'package:dart_frog/dart_frog.dart';
import 'package:http/http.dart' as http;

FutureOr<Response> onRequest(RequestContext context) async {
  final request = context.request;

  // Access the query parameters as a `Map<String, String>`.
  final params = request.uri.queryParameters;

  // Get the value for the key `name`.
  // Default to `there` if there is no query parameter.
  final city = params['city'] ?? 'Almaty';
  final startDate = params['startDate'] ?? '2023-07-22';
  final endDate = params['endDate'] ?? '2023-07-26';
  final adults = int.tryParse(params['adults'] ?? '') ?? 1;
  final children = int.tryParse(params['children'] ?? '') ?? 0;
  final duration = DateTime.parse(endDate).difference(DateTime.parse(startDate)).inDays;

  final header = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer OPEN_AI_API_KEY',
  };
  final body = {
    'model': 'gpt-3.5-turbo-16k',
    'messages': [
      {
        'role': 'system',
        'content': getSystemPromptData(
          city,
          DateTime.parse(startDate),
          DateTime.parse(endDate),
          adults,
          children,
        ),
      },
      {
        'role': 'user',
        'content': PROMPT
            .replaceAll('{{city}}', city)
            .replaceAll('{{startDate}}', startDate)
            .replaceAll('{{endDate}}', endDate)
            .replaceAll('{{adults}}', adults.toString())
            .replaceAll('{{children}}', children.toString())
            .replaceAll('{{duration}}', duration.toString()),
      },
    ],
    'temperature': 1.07,
    'max_tokens': 960,
    'top_p': 1,
    'frequency_penalty': 0,
    'presence_penalty': 0
  };

  var repeat = true;
  var index = 0;
  var content = '';
  while (repeat) {
    final response = await http.post(
      Uri.parse('https://api.openai.com/v1/chat/completions'),
      headers: header,
      body: jsonEncode(body),
    );
    final gptResponse = GptResponse.fromRawJson(response.body);
    final message = gptResponse.choices.firstWhere((element) => element.index == index).message;
    try {
      content = content + message.content;
      final answerMap = TripPlan.fromRawJson(content);
      index++;
      return Response(
        body: jsonEncode(answerMap),
        headers: {
          'Content-Type': 'application/json',
        },
      );
    } on FormatException catch (e) {
      print(e.message);
      repeat = true;
      body['messages'] = (body['messages']! as Iterable<Map<String, String>>).toList()..add(message.toJson());
    } catch (e) {
      print(e.toString());
      repeat = true;
      body['messages'] = (body['messages']! as Iterable<Map<String, String>>).toList()..add(message.toJson());
    }
  }

  return Response(
    body: '',
  );
}

String PROMPT =
    'напиши мне план путешествия в местоположение {{city}} на {{duration}} дня от {{startDate}} до {{endDate}} на {{adults}} взрослых и {{children}} детей,'
    'ответ дай в формате json с планом отдыха по дням, в каждом дне должен быть включен список активностей.'
    'Активность может быть из списка объявлений. Учитывай длительность событий из объявления чтобы активности не пересекались друг с другом.'
    'Исключи повторения в активностях\nформат json: \n[\n{\n    "date": "дата",\n    "adtivities":[\n     //// активность из списка объявлений\n        {\n            "time":"время",\n            "id": число,\n            "name":"название",\n  "description":"описание",\n        }\n    ]\n}\n]';

class GptResponse {
  GptResponse({
    required this.id,
    required this.object,
    required this.created,
    required this.model,
    required this.choices,
    required this.usage,
  });

  factory GptResponse.fromRawJson(String str) => GptResponse.fromJson(json.decode(str) as Map<String, dynamic>);

  factory GptResponse.fromJson(Map<String, dynamic> json) => GptResponse(
        id: json['id'] as String,
        object: json['object'] as String,
        created: json['created'] as int,
        model: json['model'] as String,
        choices: List<Choice>.from((json['choices'] as Iterable<dynamic>).map((x) => Choice.fromJson(x as Map<String, dynamic>))),
        usage: Usage.fromJson(json['usage'] as Map<String, dynamic>),
      );
  final String id;
  final String object;
  final int created;
  final String model;
  final List<Choice> choices;
  final Usage usage;

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJson() => {
        'id': id,
        'object': object,
        'created': created,
        'model': model,
        'choices': List<dynamic>.from(choices.map((x) => x.toJson())),
        'usage': usage.toJson(),
      };
}

class Choice {
  Choice({
    required this.index,
    required this.message,
    required this.finishReason,
  });

  factory Choice.fromRawJson(String str) => Choice.fromJson(json.decode(str) as Map<String, dynamic>);

  factory Choice.fromJson(Map<String, dynamic> json) => Choice(
        index: json['index'] as int,
        message: Message.fromJson(json['message'] as Map<String, dynamic>),
        finishReason: json['finish_reason'] as String,
      );
  final int index;
  final Message message;
  final String finishReason;

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJson() => {
        'index': index,
        'message': message.toJson(),
        'finish_reason': finishReason,
      };
}

class Message {
  Message({
    required this.role,
    required this.content,
  });

  factory Message.fromRawJson(String str) => Message.fromJson(json.decode(str) as Map<String, dynamic>);

  factory Message.fromJson(Map<String, dynamic> json) => Message(
        role: json['role'] as String,
        content: json['content'] as String,
      );
  final String role;
  final String content;

  String toRawJson() => json.encode(toJson());

  Map<String, String> toJson() => {
        'role': role,
        'content': content,
      };
}

class Usage {
  Usage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });

  factory Usage.fromRawJson(String str) => Usage.fromJson(json.decode(str) as Map<String, dynamic>);

  factory Usage.fromJson(Map<String, dynamic> json) => Usage(
        promptTokens: json['prompt_tokens'] as int,
        completionTokens: json['completion_tokens'] as int,
        totalTokens: json['total_tokens'] as int,
      );
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJson() => {
        'prompt_tokens': promptTokens,
        'completion_tokens': completionTokens,
        'total_tokens': totalTokens,
      };
}

class TripPlan {
  TripPlan({
    required this.plan,
  });

  factory TripPlan.fromRawJson(String str) => TripPlan.fromJson(json.decode(str) as Map<String, dynamic>);

  factory TripPlan.fromJson(Map<String, dynamic> json) => TripPlan(
        plan: List<Plan>.from((json['plan'] as Iterable<dynamic>).map((x) => Plan.fromJson(x as Map<String, dynamic>))),
      );
  final List<Plan> plan;

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJson() => {
        'plan': List<dynamic>.from(plan.map((x) => x.toJson())),
      };
}

class Plan {
  Plan({
    required this.date,
    required this.activities,
  });

  factory Plan.fromRawJson(String str) => Plan.fromJson(json.decode(str) as Map<String, dynamic>);

  factory Plan.fromJson(Map<String, dynamic> json) => Plan(
        date: json['date'] as String,
        activities: List<Activity>.from(
          (json['activities'] as Iterable<dynamic>).map(
            (x) => Activity.fromJson(x as Map<String, dynamic>),
          ),
        ),
      );
  final String date;
  final List<Activity> activities;

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJson() => {
        'date': date,
        'activities': List<dynamic>.from(activities.map((x) => x.toJson())),
      };
}

class Activity {
  Activity({
    required this.time,
    required this.id,
    required this.name,
  });

  factory Activity.fromRawJson(String str) => Activity.fromJson(json.decode(str) as Map<String, dynamic>);

  factory Activity.fromJson(Map<String, dynamic> json) => Activity(
        time: json['time'] as String,
        id: json['id'] as int,
        name: utf8.decode(json['name'].toString().codeUnits),
      );
  final String time;
  final int id;
  final String name;

  String toRawJson() => json.encode(toJson());

  Map<String, dynamic> toJson() => {
        'time': time,
        'id': id,
        'name': name,
      };
}

final data = [
  {
    'id': 1,
    'name': 'Great Bear',
    'description': 'Glamping of high comfort in Almaty. Vacation for the whole family. Saksky baths.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 1,
    'children': 1,
    'category': 'glamping',
    'price': 15000,
    'duration': '24h'
  },
  {
    'id': 2,
    'name': 'Menin house',
    'description':
        'Glamping with a panoramic view of the city. 4 comfortable cabins, Holding of events, 15 minutes from the center.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 2,
    'children': 0,
    'category': 'glamping',
    'price': 20000,
    'duration': '24h'
  },
  {
    'id': 3,
    'name': 'Gora glamping',
    'description':
        'Family vacation with a view of Zailiysky Alatau, 10 tent houses with barbecue area, Bathhouse, Terrace for events.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 3,
    'children': 1,
    'category': 'glamping',
    'price': 25000,
    'duration': '24h'
  },
  {
    'id': 4,
    'name': 'Dala river',
    'description':
        "We are located just an hour's drive from Almaty. We have 2 unique Kazakh-Sak baths, 3 eco-houses, oriental cuisine restaurant, horseback riding, large territory.",
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 4,
    'children': 0,
    'category': 'baza',
    'price': 30000,
    'duration': '24h'
  },
  {
    'id': 5,
    'name': 'Onvatutina',
    'description':
        'Studio apartments in a guest house near Almaty. We have Jacuzzi, BBQ, Fireplace, Bathhouse, Landscaped area, Quiet, secluded vacation. Just Paradise for a couple',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 5,
    'children': 1,
    'category': 'baza',
    'price': 50000,
    'duration': '24h'
  },
  {
    'id': 6,
    'name': 'The center of Almaty',
    'description':
        "Embark on a captivating journey through the heart of Almaty, Kazakhstan's largest city and cultural hub. \"The Center of Almaty\" excursion is a delightful exploration of the city's rich history, vibrant culture, and modern urban charm. Whether you are a history enthusiast, a cultural aficionado, or simply eager to discover the essence of this bustling metropolis, this tour promises an unforgettable experience.\nHighlights:\nPanfilov Park: The adventure begins at the iconic Panfilov Park, a green oasis in the middle of the city. Here, you'll find the magnificent Zenkov Cathedral, a true architectural marvel and one of the few surviving wooden buildings in the world. The cathedral's colorful exterior and stunning design will leave you awe-inspired.\nRepublic Square: Next, we'll head to the bustling Republic Square, the heart of Almaty's political and social life. The square is adorned with impressive Soviet-era buildings, including the Kazakh State Academic Theatre of Opera and Ballet and the Central State Museum of Kazakhstan. It's an excellent opportunity to delve into the city's past and present.\nAbay Opera House: Prepare to be enchanted by the grandeur of the Abay Opera House. As a symbol of Almaty's cultural heritage, this architectural gem hosts world-class performances and stands as a testament to the city's deep appreciation for the arts.\nGreen Bazaar: No visit to Almaty is complete without experiencing the vibrant atmosphere of the Green Bazaar. Immerse yourself in the lively market, filled with a colorful array of fresh produce, traditional crafts, and local delicacies. Feel free to engage with friendly vendors and sample some traditional Kazakh snacks.\nKok-Tobe Hill: For a breathtaking panoramic view of Almaty, we'll ascend to Kok-Tobe Hill. This vantage point offers a sweeping vista of the city's skyline against the backdrop of the majestic Tien Shan mountains. Enjoy a leisurely stroll and indulge in local street food as you savor the picturesque scenery.\nMedeu Skating Rink (Optional): As an optional extension to the tour, we can visit the world-famous Medeu Skating Rink, an engineering marvel set amidst the mountains. During winter, the rink transforms into a winter wonderland, while in summer, it becomes a recreational paradise offering various activities.\nThroughout the excursion, our knowledgeable guide will provide captivating stories, fascinating facts, and insights into the local culture, history, and traditions of Almaty. Whether you're a solo traveler, a family, or a group of friends, \"The Center of Almaty\" excursion guarantees an enriching and captivating experience that will leave you with cherished memories of this enchanting city. Come and join us as we unravel the hidden gems and iconic landmarks that make Almaty a must-visit destination in Central Asia.",
    'location': 'Almaty',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 1,
    'children': 0,
    'category': 'excursion',
    'price': 15000,
    'duration': '5h'
  },
  {
    'id': 7,
    'name': 'Kolsay tour',
    'description':
        'We organize TOURS to KOLSAI and KAYYNDY lakes from ALMATY, as well as Jeep tour - KOLSAI-KAYYNDY-Charyn. There are also Bus tours of 1 and 2 days',
    'location': 'Almaty',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 1,
    'children': 0,
    'category': 'tour',
    'price': 20000,
    'duration': '48h'
  },
  {
    'id': 8,
    'name': 'Aglamp',
    'description':
        'GLAMPING, VACATION IN THE MOUNTAINS OF ALMATY. Available for booking chalet, sauna, bath tub, Scandi, tent tent tent.',
    'location': 'Almaty',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 3,
    'children': 0,
    'category': 'glamping',
    'price': 25000,
    'duration': '24h'
  },
  {
    'id': 9,
    'name': 'Sakskaya Banya Zdravnitsa',
    'description':
        'Full Relaxation in Exclusive Saksky Bath. We have herbal balms from Valentine, jadeite stone, birch frame and comfortable eco hotel.',
    'location': 'Almaty',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 4,
    'children': 0,
    'category': 'glamping',
    'price': 30000,
    'duration': '24h'
  },
  {
    'id': 10,
    'name': 'Discover tour',
    'description': 'Winter and Summer vacations, Horseback riding, City tours.',
    'location': 'Almaty',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 5,
    'children': 0,
    'category': 'tour',
    'price': 60000,
    'duration': '12h'
  },
  {
    'id': 11,
    'name': 'Shymbulak horse riding',
    'description':
        'Horseback riding in the picturesque slopes of SHYMBULAK. We have Friendly horses, Experienced instructors, Highest mountain rides, Unforgettable emotions.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-08', '2023-08-09', '2023-08-10'],
    'adults': 1,
    'children': 0,
    'category': 'tour',
    'price': 15000,
    'duration': '24h'
  },
  {
    'id': 12,
    'name': 'The art museum of Almaty',
    'description':
        "Embark on a captivating journey into the realm of artistic expression and cultural heritage with \"The Art Museum of Almaty\" excursion. This immersive tour takes you on a delightful exploration of Almaty's artistic treasures, showcasing a diverse collection of local and international masterpieces that reflect the city's creative spirit and rich history.\nHighlights:\nCentral State Museum of Kazakhstan: The adventure commences at the esteemed Central State Museum, home to an extensive collection of artifacts and artworks that trace Kazakhstan's history from ancient times to the modern era. As we navigate through the exhibits, you'll gain a deep appreciation for the country's cultural evolution and artistic achievements.\nNational Museum of Fine Arts: Prepare to be mesmerized as we enter the prestigious National Museum of Fine Arts. This haven for art enthusiasts boasts an impressive collection of paintings, sculptures, and decorative arts from various periods and styles. Marvel at the works of prominent Kazakhstani artists and be inspired by international masterpieces.\nContemporary Art Galleries: The excursion takes a modern turn as we visit some of Almaty's finest contemporary art galleries. Here, you'll encounter cutting-edge creations and thought-provoking installations by emerging local talents and internationally acclaimed artists. Gain insights into the evolving art scene and the cultural trends shaping Kazakhstan's contemporary art world.\nArt Workshops (Optional): For those seeking a more hands-on experience, we offer optional art workshops conducted by skilled artists. Engage in painting, pottery, or other art forms, and unleash your creativity in a supportive and inspiring environment.\nMuseum Cafes: Amidst the exploration, we'll make time to relax and recharge at museum cafes. Savor a delightful selection of local delicacies and beverages while discussing the art you've encountered and the impressions it left on you.\nThroughout the excursion, our knowledgeable guide will provide in-depth information about the exhibited artworks, the artists behind them, and their significance in the context of Kazakhstan's cultural heritage. You'll gain a deeper understanding of the city's artistic soul and its place in the wider world of art.\n\"The Art Museum of Almaty\" excursion is designed for art enthusiasts, curious travelers, and anyone seeking to immerse themselves in the creative expressions of a vibrant city. Whether you have a profound appreciation for art or simply wish to explore the cultural side of Almaty, this tour promises to be a delightful and enriching experience. Come and join us on this artistic journey that celebrates the beauty, diversity, and ingenuity of Almaty's art scene.",
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-08', '2023-08-09', '2023-08-10'],
    'adults': 2,
    'children': 0,
    'category': 'excursion',
    'price': 20000,
    'duration': '4h'
  },
  {
    'id': 13,
    'name': 'TBRN glamping',
    'description': 'Exclusive premium tent camping. GLAMPING TOUR in Almaty region every weekend.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-08', '2023-08-09', '2023-08-10'],
    'adults': 3,
    'children': 1,
    'category': 'glamping',
    'price': 25000,
    'duration': '24h'
  },
  {
    'id': 14,
    'name': 'Sayahat Tike',
    'description':
        'TURES in ALMATY, tours to Kolsai, Kayindy, Black, tours to Tashkent, 5 locations in Almaty region, as well as Turkestan.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-08', '2023-08-09', '2023-08-10'],
    'adults': 4,
    'children': 0,
    'category': 'tour',
    'price': 30000,
    'duration': '72h'
  },
  {
    'id': 15,
    'name': 'Join Me Asia',
    'description':
        'Tours Almaty and around Kazakhstan. Travel with us, because we have Certified tour guides. We have been conducting tours for more than 7 years.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-08', '2023-08-09', '2023-08-10'],
    'adults': 5,
    'children': 0,
    'category': 'tour',
    'price': 70000,
    'duration': '48h'
  },
  {
    'id': 16,
    'name': 'Monte Almaty',
    'description':
        'MONTE is Hiking in the mountains of Almaty. We have one-day treks in Almaty, multi-day trekking from 4 to 10 days, trekking in the mountains: Altai Likiyka, Sairamugam.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 1,
    'children': 0,
    'category': 'tour',
    'price': 15000,
    'duration': '48h'
  },
  {
    'id': 17,
    'name': 'Heaven glamping Almaty',
    'description': 'Glamping in Almaty. Place for rest. Comfortable rest in the mountains 20 minutes from the city center.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 2,
    'children': 1,
    'category': 'glamping',
    'price': 20000,
    'duration': '24h'
  },
  {
    'id': 18,
    'name': 'Orbita glamping',
    'description':
        'The most Instagrammable glamping in Kazakhstan. Our soul, body and mind rest at our place. There are 7 spheres-planets with panoramic view. We are located 25 min. from Shchuchinsk.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 3,
    'children': 0,
    'category': 'glamping',
    'price': 25000,
    'duration': '24h'
  },
  {
    'id': 19,
    'name': 'Talgar glamping',
    'description':
        'Mountain houses and Glamping in Talgar. We have a place to rest, cozy panoramic gazebo, glamping, barnhouse, bathhouse, swimming pool, tapchan, evening by the fire',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 3,
    'children': 1,
    'category': 'glamping',
    'price': 30000,
    'duration': '24h'
  },
  {
    'id': 20,
    'name': 'Travel Almaty',
    'description':
        'TOURS IN KAZAKHSTAN. Almaly-Travel is a tour operator since 2001. We organize your tour in KAZAKHSTAN in small groups with an experienced guide.',
    'location': 'Almaty',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 5,
    'children': 0,
    'category': 'tour',
    'price': 35000,
    'duration': '24h'
  },
  {
    'id': 21,
    'name': 'TOURCLUBPIK',
    'description': 'HIKES IN THE MOUNTAINS by TURCLUB PIK. We do fire treks all over the world. Choose your dream trip.',
    'location': 'Almaty',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 1,
    'children': 0,
    'category': 'tour',
    'price': 10000,
    'duration': '24h'
  },
  {
    'id': 22,
    'name': 'The gold square of Almaty',
    'description':
        "Prepare to be enchanted by the glimmering allure of Almaty's most prestigious district with \"The Gold Square of Almaty\" excursion. This exclusive tour offers a captivating glimpse into the opulence and grandeur of the city's upscale neighborhood, known for its luxury shopping, elegant architecture, and cosmopolitan ambiance.\nHighlights:\nDostyk Avenue: The journey begins on the renowned Dostyk Avenue, often referred to as the \"Champs-Élysées of Almaty.\" As we stroll along this tree-lined boulevard, you'll be surrounded by an array of high-end boutiques, upscale restaurants, and chic cafes. Feel the sophistication and energy of the area as you indulge in the window-shopping experience.\nLuxury Shopping: For the discerning shopper, the Gold Square is a dream come true. We'll visit some of the most prestigious shopping centers and boutiques, offering an exquisite selection of international designer brands and luxurious goods. Whether you're looking for fashion, jewelry, or exquisite souvenirs, this district promises a shopping experience like no other.\nPresidential Palace: As we explore the Gold Square, we'll catch a glimpse of the impressive Presidential Palace, a symbol of authority and power in Kazakhstan. Admire the grand architecture and lush surroundings as you learn about the country's political landscape and historical significance.\nAbay Opera House (Optional): For those interested in the arts, an optional visit to the Abay Opera House can be arranged. This majestic venue hosts world-class performances and stands as an architectural gem in the heart of the city.\nPark of 28 Panfilov Guardsmen: After immersing ourselves in the glitz and glamour, we'll take a moment of serenity at the Park of 28 Panfilov Guardsmen. This historic park houses the Memorial of Glory and the eternal flame, paying tribute to the heroes of the Second World War. It's a poignant reminder of Almaty's rich history and resilience.\nVIP Dining Experience: The excursion concludes with a VIP dining experience at one of the Gold Square's upscale restaurants. Savor gourmet cuisine and impeccable service in a refined setting, making it the perfect way to cap off the tour in style.\nThroughout the excursion, our knowledgeable guide will share captivating anecdotes about the district's history, its rise to prominence, and the prominent personalities that have graced its streets. You'll witness the modern face of Almaty, where sophistication and luxury converge in an inviting embrace.\n\"The Gold Square of Almaty\" excursion is a perfect choice for travelers with a taste for the finer things in life, offering a glimpse into the city's affluent side and its world-class offerings. Join us for an exclusive journey that celebrates the elegance and prestige of Almaty's Gold Square.",
    'location': 'Almaty',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 2,
    'children': 0,
    'category': 'excursion',
    'price': 20000,
    'duration': '5h'
  },
  {
    'id': 23,
    'name': 'Cartour kz',
    'description':
        'Customized tours to Almaty, Kolsai, Kaindy, Charyn. We are engaged in tourism since 1998. We organize Tours in Almaty and Almaty region, Trips for several days, Individual tours.',
    'location': 'Almaty',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 2,
    'children': 0,
    'category': 'tour',
    'price': 25000,
    'duration': '72h'
  },
  {
    'id': 24,
    'name': 'Feel the Sky',
    'description': 'Comfortable glamping near Almaty with sauna and view for mountains.',
    'location': 'Almaty',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 4,
    'children': 0,
    'category': 'glamping',
    'price': 30000,
    'duration': '24h'
  },
  {
    'id': 25,
    'name': 'Go s nami',
    'description':
        'More than 10.000 satisfied tourists. Tours to the most beautiful places of Almaty. Tour to Uzbekistan: August 4-9, August 25-30.',
    'location': 'Almaty',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 5,
    'children': 0,
    'category': 'tour',
    'price': 50000,
    'duration': '24h'
  },
  {
    'id': 26,
    'name': 'Blast tour',
    'description':
        'We are a licensed tour operator in Kazakhstan. We have been organizing the best tours since 2001.  We do group and individual tours.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 1,
    'children': 0,
    'category': 'tour',
    'price': 15000,
    'duration': '15h'
  },
  {
    'id': 27,
    'name': 'Les i zvezdy glamping',
    'description':
        'Have a rest in nature without sacrificing comfort. We are located 23km away from Shchuchinsk towards Stepnyak town.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 2,
    'children': 2,
    'category': 'glamping',
    'price': 20000,
    'duration': '24h'
  },
  {
    'id': 28,
    'name': 'Ivy village jasybay',
    'description': 'Glamping, cottages near Astana. Vacation for the whole family.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 3,
    'children': 0,
    'category': 'glamping',
    'price': 25000,
    'duration': '24h'
  },
  {
    'id': 29,
    'name': 'Satty travel',
    'description':
        'Tours in Kazakhstan, Georgia, Uzbekistan. We organize individual, group tours to Kazakhstan, to Issyk-Kul July 28-30, to Georgia August 9-16, to Uzbekistan August 25-27.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-05', '2023-08-06', '2023-08-07'],
    'adults': 4,
    'children': 1,
    'category': 'tour',
    'price': 30000,
    'duration': '24h'
  },
  {
    'id': 30,
    'name': 'Tour in KZ',
    'description':
        'Discover Kazakhstan with us. Travel to the most beautiful places in Almaty and Astana region, individual tours.',
    'location': 'Astana',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 5,
    'children': 0,
    'category': 'tour',
    'price': 50000,
    'duration': '24h'
  },
  {
    'id': 31,
    'name': 'The right bank of Astana',
    'description':
        "Unveil the modern marvels and architectural wonders of Astana, Kazakhstan's futuristic capital, with \"The Right Bank of Astana\" excursion. This captivating tour takes you on a journey through the city's vibrant right bank, where innovative design, futuristic skyscrapers, and cultural landmarks come together to create a truly unique urban landscape.\nHighlights:\nNurzhol Boulevard: The adventure commences at the iconic Nurzhol Boulevard, the beating heart of Astana's right bank. Lined with futuristic buildings, this avenue offers a breathtaking view of the city's skyline. Marvel at the distinctive architecture, including the Bayterek Tower, a symbol of modern Kazakhstan, and the futuristic Khan Shatyr Entertainment Center, resembling a transparent tent.\nPresidential Palace: Get a glimpse of Kazakhstan's political center as we pass by the Presidential Palace. Admire the elegant design and learn about its significance as the seat of power in the country.\nAstana Opera House: A testament to Astana's commitment to the arts, the Astana Opera House is a striking masterpiece. Marvel at its classical and graceful architecture, and learn about the world-class performances that take place within its walls.\nKhan Shatyr Entertainment Center: Step inside the Khan Shatyr Entertainment Center to experience an urban oasis like no other. This vast transparent structure houses a shopping mall, restaurants, and even a tropical water park, providing a unique and memorable experience.\nNur-Astana Mosque: Discover the spiritual side of Astana at the Nur-Astana Mosque, an elegant and impressive Islamic place of worship. Admire the stunning blue dome and intricate ornamentation as you learn about the mosque's cultural significance.\nMega Silk Way Mall: Enjoy a shopping and leisure stop at the Mega Silk Way Mall, one of the largest shopping centers in Central Asia. Browse through an extensive selection of international brands, sample local cuisine, and perhaps find a few souvenirs to take home.\nAstana Baiterek Tower (Optional): As an optional extension to the tour, we can visit the Astana Baiterek Tower, an iconic observation tower offering panoramic views of the city. Climb to the top for an unforgettable vista of Astana's evolving skyline and the Ishim River.\nThroughout the excursion, our knowledgeable guide will provide fascinating insights into Astana's transformation from a small provincial town to a futuristic metropolis. Learn about the city's urban planning, cultural aspirations, and its role as a hub for political, economic, and cultural activities in Kazakhstan.\n\"The Right Bank of Astana\" excursion is perfect for travelers seeking to witness the cutting-edge architecture and dynamic spirit of this modern city. Join us for an unforgettable exploration of Astana's right bank, where innovation and tradition blend harmoniously to create a city like no other.",
    'location': 'Astana',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 1,
    'children': 1,
    'category': 'excursion',
    'price': 15000,
    'duration': '5h'
  },
  {
    'id': 32,
    'name': 'Borovoe Country Club',
    'description':
        'Hotel complex "Country Club". We have Chalets and gazebos, Pool, playground, barbecue area and private parking.',
    'location': 'Astana',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 2,
    'children': 0,
    'category': 'baza',
    'price': 20000,
    'duration': '24h'
  },
  {
    'id': 33,
    'name': 'Eco glamping Burabay',
    'description':
        'Glamping and Recreation in Borovoye. The territory of your vacation is a Georgian restaurant, wood-fired sauna, winter fishing.',
    'location': 'Astana',
    'available_dates': ['2023-08-08', '2023-08-09', '2023-08-10', '2023-08-11', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 3,
    'children': 1,
    'category': 'glamping',
    'price': 25000,
    'duration': '24h'
  },
  {
    'id': 34,
    'name': 'Uyut house in forest',
    'description':
        'Guest House "UYUT" is a pleasant Vacation in Borovoye. We have Hotel, House, Comfortable rooms, Picturesque views, lake and forest. Rest away from the bustle of the city.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 4,
    'children': 0,
    'category': 'baza',
    'price': 30000,
    'duration': '24h'
  },
  {
    'id': 35,
    'name': 'Kompas Asia',
    'description':
        'KOMPAS ASIA organizes tours in KAZAKHSTAN. We fall in love with traveling around the world. We have a FORMAT "ALL INCLUDED". We already have more than 250.000 satisfied tourists.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 3,
    'children': 0,
    'category': 'tour',
    'price': 50000,
    'duration': '48h'
  },
  {
    'id': 36,
    'name': 'Scout glamp',
    'description':
        'Scout Glamping in Accol. We have a place to rest, Vacation in nature with modern comfort. We are located 120 km from Astana.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 2,
    'children': 0,
    'category': 'glamping',
    'price': 15000,
    'duration': '24h'
  },
  {
    'id': 37,
    'name': 'Katar house',
    'description': 'Rest area "KATAR" (BOROVOE) is a bright, cozy house for your rest, as well as a Russian bathhouse.',
    'location': 'Astana',
    'available_dates': ['2023-08-01', '2023-08-02', '2023-08-03', '2023-08-04', '2023-08-12', '2023-08-13', '2023-08-14'],
    'adults': 2,
    'children': 2,
    'category': 'baza',
    'price': 20000,
    'duration': '24h'
  },
  {
    'id': 38,
    'name': 'The center of Astana',
    'description':
        "Embark on an enchanting journey through the vibrant heart of Astana, the awe-inspiring capital of Kazakhstan, with \"The Center of Astana\" excursion. This captivating tour offers a delightful exploration of the city's architectural marvels, cultural landmarks, and historical sites that showcase the harmonious blend of tradition and modernity in this dynamic metropolis.\nHighlights:\nIndependence Square: The adventure begins at Independence Square, a grand open space adorned with impressive fountains and sculptures. Marvel at the elegant Kazakh Eli Monument, symbolizing the country's independence and sovereignty. As we explore the square, you'll also catch sight of the majestic Kazakh Parliament building.\nHazret Sultan Mosque: Prepare to be mesmerized by the magnificence of Hazret Sultan Mosque, one of the largest mosques in Central Asia. Its stunning turquoise dome and intricate ornamentation pay tribute to Kazakhstan's rich Islamic heritage.\nAstana Opera House: Delight in a visit to the world-class Astana Opera House, a beacon of culture and art in the city. Admire its neoclassical design and learn about the impressive performances that grace its stages.\nKhan Shatyr Entertainment Center: Step inside the futuristic Khan Shatyr Entertainment Center, a massive transparent tent-like structure that houses an array of shopping, dining, and entertainment options. Enjoy the unique experience of being in a tropical paradise within a bustling city.\nNurzhol Boulevard: Experience the modern skyline of Astana as we stroll along the iconic Nurzhol Boulevard. Gaze at the distinctive architecture of the city's futuristic buildings, including the Bayterek Tower, a symbol of Kazakhstan's aspirations and dreams.\nNational Museum of Kazakhstan: Immerse yourself in the rich history and culture of Kazakhstan at the National Museum. Its diverse exhibits offer a comprehensive journey through the nation's past, from ancient civilizations to the present day.\nWater-Green Boulevard: Conclude the tour with a leisurely walk along the Water-Green Boulevard, a picturesque promenade dotted with parks, fountains, and recreational areas. Take in the scenic beauty and relish the serene ambiance of this lovely urban oasis.\nThroughout the excursion, our knowledgeable guide will share captivating stories about Astana's evolution from a small provincial town to a dynamic capital city. Learn about the city's ambitious urban planning projects, its transformation into a futuristic metropolis, and the preservation of its cultural heritage.\n\"The Center of Astana\" excursion is perfect for travelers of all interests, whether you're fascinated by architecture, history, culture, or simply eager to experience the vibrant energy of Kazakhstan's capital city. Join us for an unforgettable journey through the center of Astana, where the past and future converge to create a city that celebrates the essence of Kazakhstan's spirit.",
    'location': 'Astana',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 3,
    'children': 0,
    'category': 'excursion',
    'price': 25000,
    'duration': '5h'
  },
  {
    'id': 39,
    'name': 'Sunrise Borovoe',
    'description':
        'Hotel and Guest House Sunrise in Borovoye. We have Comfortable rooms, Swimming pool, Wood-fired bathhouse, Cozy atmosphere.',
    'location': 'Astana',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 4,
    'children': 1,
    'category': 'baza',
    'price': 30000,
    'duration': '24h'
  },
  {
    'id': 40,
    'name': 'KAIYRZHAN expert',
    'description':
        'I am an EXPERT in mountain tourism in KAZAKHSTAN and KYRGYZSTAN. I fall in love with the mountains from the first hike. I take on the organization of turnkey recreation. With me you will easily climb your first 5,000-meter peak.',
    'location': 'Astana',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 2,
    'children': 0,
    'category': 'tour',
    'price': 20000,
    'duration': '24h'
  },
  {
    'id': 41,
    'name': 'The old Astana',
    'description':
        "Take a step back in time and immerse yourself in the rich history and charming nostalgia of \"The Old Astana\" excursion. This captivating tour invites you to explore the roots of Kazakhstan's capital city, delving into its historic neighborhoods, ancient landmarks, and cultural heritage that harken back to a bygone era.\nHighlights:\nIshim River Embankment: Begin your journey along the picturesque Ishim River Embankment. This serene area offers a glimpse of old Astana's natural beauty and serves as a perfect introduction to the city's historical narrative.\nAscension Cathedral: Admire the grandeur of the Ascension Cathedral, an architectural gem that stands as a reminder of Astana's spiritual past. The cathedral's classic design and ornate details provide a captivating contrast to the city's modern skyline.\nKenesary Khan Monument: Learn about the heroic figure of Kenesary Khan, a prominent leader of the Kazakh resistance against Russian expansion in the 19th century. The monument dedicated to his memory is a symbol of courage and the nation's struggle for independence.\nOld City Hall: Marvel at the elegant facade of the Old City Hall, an iconic building that once served as the seat of governance in Astana. Its historical significance and classic design make it a noteworthy stop on our excursion.\nAzret Sultan Mosque: Explore the serene ambiance of Azret Sultan Mosque, one of the oldest and most revered religious sites in Astana. Its distinctive blue domes and traditional Islamic architecture make it a visual delight and a place of spiritual tranquility.\nTraditional Bazaar: Immerse yourself in the vibrant atmosphere of a traditional bazaar. Engage with friendly locals, savor the aromas of freshly prepared Kazakh delicacies, and browse through stalls offering unique crafts and souvenirs.\nAstana History Museum: Delve deeper into Astana's past at the Astana History Museum. Discover artifacts, photographs, and exhibits that narrate the city's transformation over the years, shedding light on its historical, cultural, and social aspects.\nOld Neighborhoods: Wander through the quaint old neighborhoods of Astana, where charming houses and narrow streets preserve the essence of the city's past. Feel the authentic spirit of the local community as you interact with residents and hear their stories.\nThroughout the excursion, our knowledgeable guide will regale you with fascinating anecdotes and historical insights, transporting you to a time when Astana was a thriving center of Kazakh culture and tradition.\n\"The Old Astana\" excursion is an ideal choice for history enthusiasts, cultural explorers, and anyone seeking a deeper understanding of the city's roots. Join us on this nostalgic journey, where ancient heritage and contemporary spirit intertwine to create a captivating tapestry of old-world charm in the heart of Kazakhstan's modern capital.",
    'location': 'Astana',
    'available_dates': [
      '2023-08-01',
      '2023-08-02',
      '2023-08-03',
      '2023-08-04',
      '2023-08-05',
      '2023-08-06',
      '2023-08-07',
      '2023-08-08',
      '2023-08-09',
      '2023-08-10',
      '2023-08-11',
      '2023-08-12',
      '2023-08-13',
      '2023-08-14'
    ],
    'adults': 1,
    'children': 1,
    'category': 'excursion',
    'price': 40000,
    'duration': '5h'
  }
];

String getSystemPromptData(String city, DateTime startDate, DateTime endDate, int adults, int children) {
  final dataByCity = data.where((element) => element['location'] == city).toList();
  final dataByDate = dataByCity.where((element) {
    final datesList = (element['available_dates']! as List<String>).map(DateTime.parse).toList();
    final filteredDates = datesList.where((date) {
      return date.isAfter(startDate) && date.isBefore(endDate) ||
          date.isAtSameMomentAs(startDate) ||
          date.isAtSameMomentAs(endDate);
    }).toList();

    return filteredDates.isNotEmpty;
  }).toList();

  final dataByAdults = dataByDate.where((element) => (element['adults']! as int) >= adults).toList();
  final finalData = dataByAdults.where((element) => (element['children']! as int) >= children).toList();

  var system = '';

  for (final element in finalData) {
    system += '\n'
        'ID объявления:${element['id']}'
        'Название:${element['name']}'
        'Описание:${element['description']}'
        'Доступные даты:${(element['available_dates']! as List<String>).fold('', (previousValue, element) => '$previousValue$element, ')}'
        'Взрослые:${element['adults']}'
        'Дети:${element['children']}'
        'Категория:${element['category']}'
        'Длительность:${element['price']}'
        'Цена:${element['duration']}';
  }

  return system;
}
