import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../../../data/local/database/app_database.dart';
import '../../../data/repositories/auto_categorize_repository.dart';
import '../../../data/repositories/category_repository.dart';

/// Seeds default auto-categorization rules for well-known merchants.
///
/// Runs once after category seeding. Looks up category IDs by name since
/// they are random UUIDs generated at runtime.
class RuleSeeder {
  RuleSeeder(this._categoryRepo, this._autoCatRepo);

  final CategoryRepository _categoryRepo;
  final AutoCategorizeRepository _autoCatRepo;

  static const _uuid = Uuid();

  /// Seed default rules if none exist yet.
  ///
  /// Returns true if rules were seeded, false if skipped.
  Future<bool> seedIfEmpty() async {
    if (await _autoCatRepo.hasRules()) return false;

    final categories = await _categoryRepo.getAllCategories();

    // Build name → ID lookup. Parents are added first so they win on
    // duplicate names (e.g. "Insurance" exists as both a parent category
    // and a subcategory under Housing/Healthcare). Unique subcategory names
    // like "Utilities", "Gas", "Pharmacy" are unaffected.
    final catByName = <String, String>{};
    final parents = categories.where((c) => c.parentId == null);
    final children = categories.where((c) => c.parentId != null);
    for (final c in parents) {
      catByName.putIfAbsent(c.name, () => c.id);
    }
    for (final c in children) {
      catByName.putIfAbsent(c.name, () => c.id);
    }

    final now = DateTime.now().millisecondsSinceEpoch;
    final rules = <AutoCategorizeRulesCompanion>[];
    var priority = 0;

    for (final (payeeContains, categoryName) in _merchantMappings) {
      final categoryId = catByName[categoryName];
      if (categoryId == null) continue;

      rules.add(AutoCategorizeRulesCompanion.insert(
        id: _uuid.v4(),
        name: '$payeeContains → $categoryName',
        priority: priority++,
        categoryId: categoryId,
        payeeContains: Value(payeeContains),
        isEnabled: const Value(true),
        createdAt: now,
        updatedAt: now,
      ));
    }

    if (rules.isNotEmpty) {
      await _autoCatRepo.insertRules(rules);
    }

    return true;
  }

  /// (payeeContains, targetCategoryName) pairs.
  ///
  /// payeeContains is matched against the NORMALIZED (uppercase) payee name.
  /// Category names must match exactly what CategorySeeder creates.
  static const _merchantMappings = <(String, String)>[
    // -------------------------------------------------------------------------
    // Groceries (parent category — no subcategories)
    // -------------------------------------------------------------------------
    ('KROGER', 'Groceries'),
    ('SAFEWAY', 'Groceries'),
    ('PUBLIX', 'Groceries'),
    ('HEB', 'Groceries'),
    ('H-E-B', 'Groceries'),
    ('ALDI', 'Groceries'),
    ('TRADER JOE', 'Groceries'),
    ('WHOLE FOODS', 'Groceries'),
    ('SPROUTS', 'Groceries'),
    ('WEGMANS', 'Groceries'),
    ('GIANT', 'Groceries'),
    ('FOOD LION', 'Groceries'),
    ('HARRIS TEETER', 'Groceries'),
    ('MEIJER', 'Groceries'),
    ('LIDL', 'Groceries'),
    ('WINCO', 'Groceries'),
    ('PIGGLY WIGGLY', 'Groceries'),
    ('STOP & SHOP', 'Groceries'),
    ('HANNAFORD', 'Groceries'),
    ('FOOD4LESS', 'Groceries'),
    ('GROCERY OUTLET', 'Groceries'),
    ('MARKET BASKET', 'Groceries'),
    ('SAVE A LOT', 'Groceries'),
    ('WINN DIXIE', 'Groceries'),
    ('INGLES', 'Groceries'),
    ('FRESH MARKET', 'Groceries'),
    ('NATURAL GROCERS', 'Groceries'),

    // -------------------------------------------------------------------------
    // Dining → Coffee Shops
    // -------------------------------------------------------------------------
    ('STARBUCKS', 'Coffee Shops'),
    ('DUNKIN', 'Coffee Shops'),
    ('PEET', 'Coffee Shops'),
    ('DUTCH BROS', 'Coffee Shops'),
    ('CARIBOU COFFEE', 'Coffee Shops'),
    ('TIM HORTON', 'Coffee Shops'),
    ('PHILZ', 'Coffee Shops'),
    ('BLUE BOTTLE', 'Coffee Shops'),

    // -------------------------------------------------------------------------
    // Dining → Fast Food
    // -------------------------------------------------------------------------
    ('MCDONALD', 'Fast Food'),
    ('CHICK-FIL-A', 'Fast Food'),
    ('TACO BELL', 'Fast Food'),
    ('BURGER KING', 'Fast Food'),
    ('WENDY', 'Fast Food'),
    ('SUBWAY', 'Fast Food'),
    ('CHIPOTLE', 'Fast Food'),
    ('POPEYE', 'Fast Food'),
    ('FIVE GUYS', 'Fast Food'),
    ('JACK IN THE BOX', 'Fast Food'),
    ('SONIC DRIVE', 'Fast Food'),
    ('ARBY', 'Fast Food'),
    ('PANDA EXPRESS', 'Fast Food'),
    ('WHATABURGER', 'Fast Food'),
    ('IN-N-OUT', 'Fast Food'),
    ('RAISING CANE', 'Fast Food'),
    ('JERSEY MIKE', 'Fast Food'),
    ('JIMMY JOHN', 'Fast Food'),
    ('FIREHOUSE SUBS', 'Fast Food'),
    ('CULVER', 'Fast Food'),
    ('ZAXBY', 'Fast Food'),
    ('WINGSTOP', 'Fast Food'),
    ('LITTLE CAESARS', 'Fast Food'),
    ('KFC', 'Fast Food'),

    // -------------------------------------------------------------------------
    // Dining → Restaurants
    // -------------------------------------------------------------------------
    ('PANERA', 'Restaurants'),
    ('DOMINO', 'Restaurants'),
    ('PIZZA HUT', 'Restaurants'),
    ('OLIVE GARDEN', 'Restaurants'),
    ('APPLEBEE', 'Restaurants'),
    ('CHILI', 'Restaurants'),
    ('OUTBACK', 'Restaurants'),
    ('CRACKER BARREL', 'Restaurants'),
    ('RED LOBSTER', 'Restaurants'),
    ('TEXAS ROADHOUSE', 'Restaurants'),
    ('IHOP', 'Restaurants'),
    ('DENNY', 'Restaurants'),
    ('WAFFLE HOUSE', 'Restaurants'),
    ('CHEESECAKE FACTORY', 'Restaurants'),
    ('BUFFALO WILD WINGS', 'Restaurants'),
    ('GOLDEN CORRAL', 'Restaurants'),
    ('BOB EVANS', 'Restaurants'),
    ('RED ROBIN', 'Restaurants'),
    ('LONGHORN STEAK', 'Restaurants'),
    ('RUTH CHRIS', 'Restaurants'),
    ('BENIHANA', 'Restaurants'),
    ('CHEDDAR', 'Restaurants'),
    ('NOODLES & COMPANY', 'Restaurants'),

    // -------------------------------------------------------------------------
    // Dining → Delivery
    // -------------------------------------------------------------------------
    ('DOORDASH', 'Delivery'),
    ('GRUBHUB', 'Delivery'),
    ('UBER EATS', 'Delivery'),
    ('POSTMATES', 'Delivery'),
    ('INSTACART', 'Delivery'),
    ('SEAMLESS', 'Delivery'),

    // -------------------------------------------------------------------------
    // Transportation → Gas
    // -------------------------------------------------------------------------
    ('SHELL', 'Gas'),
    ('EXXON', 'Gas'),
    ('CHEVRON', 'Gas'),
    ('SUNOCO', 'Gas'),
    ('WAWA', 'Gas'),
    ('SHEETZ', 'Gas'),
    ('RACETRAC', 'Gas'),
    ('MARATHON', 'Gas'),
    ('CIRCLE K', 'Gas'),
    ('CASEY', 'Gas'),
    ('QUIKTRIP', 'Gas'),
    ('PILOT', 'Gas'),
    ('FLYING J', 'Gas'),
    ('LOVE', 'Gas'),
    ('VALERO', 'Gas'),
    ('CITGO', 'Gas'),
    ('PHILLIPS 66', 'Gas'),
    ('CONOCO', 'Gas'),
    ('MURPHY', 'Gas'),
    ('SPEEDWAY', 'Gas'),
    ('KWIK TRIP', 'Gas'),
    ('BUCCEE', 'Gas'),
    ('THORNTON', 'Gas'),

    // -------------------------------------------------------------------------
    // Transportation → Public Transit
    // -------------------------------------------------------------------------
    ('WMATA', 'Public Transit'),
    ('MTA', 'Public Transit'),
    ('CTA', 'Public Transit'),
    ('BART', 'Public Transit'),
    ('LYFT', 'Public Transit'),

    // -------------------------------------------------------------------------
    // Transportation → Parking
    // -------------------------------------------------------------------------
    ('PARKWHIZ', 'Parking'),
    ('SPOTHERO', 'Parking'),
    ('LAZ PARKING', 'Parking'),
    ('PARK MOBILE', 'Parking'),

    // -------------------------------------------------------------------------
    // Transportation → Auto Maintenance (under "Maintenance" subcategory of Housing?
    // No — check: Housing has "Maintenance" but Transportation doesn't.
    // Use parent "Transportation" for auto maintenance.)
    // Actually the plan says "Auto maintenance" → "Maintenance" subcategory.
    // But "Maintenance" is under Housing. Let's use "Transportation" parent.
    // -------------------------------------------------------------------------
    ('JIFFY LUBE', 'Transportation'),
    ('VALVOLINE', 'Transportation'),
    ('FIRESTONE', 'Transportation'),
    ('AUTOZONE', 'Transportation'),
    ('PEP BOYS', 'Transportation'),
    ('O\'REILLY', 'Transportation'),
    ('ADVANCE AUTO', 'Transportation'),
    ('NAPA AUTO', 'Transportation'),
    ('MIDAS', 'Transportation'),
    ('GOODYEAR', 'Transportation'),
    ('DISCOUNT TIRE', 'Transportation'),
    ('MAACO', 'Transportation'),
    ('MEINEKE', 'Transportation'),
    ('SAFELITE', 'Transportation'),

    // -------------------------------------------------------------------------
    // Entertainment → Subscriptions
    // -------------------------------------------------------------------------
    ('NETFLIX', 'Subscriptions'),
    ('HULU', 'Subscriptions'),
    ('DISNEY+', 'Subscriptions'),
    ('DISNEY PLUS', 'Subscriptions'),
    ('SPOTIFY', 'Subscriptions'),
    ('HBO', 'Subscriptions'),
    ('PARAMOUNT+', 'Subscriptions'),
    ('PARAMOUNT PLUS', 'Subscriptions'),
    ('PEACOCK', 'Subscriptions'),
    ('YOUTUBE PREM', 'Subscriptions'),
    ('APPLE MUSIC', 'Subscriptions'),
    ('APPLE TV', 'Subscriptions'),
    ('ADOBE', 'Subscriptions'),
    ('MICROSOFT 365', 'Subscriptions'),
    ('DROPBOX', 'Subscriptions'),
    ('ICLOUD', 'Subscriptions'),
    ('NOTION', 'Subscriptions'),
    ('CRUNCHYROLL', 'Subscriptions'),
    ('AUDIBLE', 'Subscriptions'),
    ('KINDLE UNLIMITED', 'Subscriptions'),
    ('SIRIUS', 'Subscriptions'),
    ('PANDORA', 'Subscriptions'),
    ('TIDAL', 'Subscriptions'),
    ('AMAZON PRIME', 'Subscriptions'),

    // -------------------------------------------------------------------------
    // Entertainment → Games
    // -------------------------------------------------------------------------
    ('STEAM', 'Games'),
    ('PLAYSTATION', 'Games'),
    ('XBOX', 'Games'),
    ('NINTENDO', 'Games'),
    ('EPIC GAMES', 'Games'),

    // -------------------------------------------------------------------------
    // Entertainment → Events
    // -------------------------------------------------------------------------
    ('TICKETMASTER', 'Events'),
    ('STUBHUB', 'Events'),
    ('VIVID SEATS', 'Events'),
    ('SEATGEEK', 'Events'),
    ('EVENTBRITE', 'Events'),
    ('FANDANGO', 'Events'),
    ('AMC THEATRES', 'Events'),
    ('REGAL CINEMA', 'Events'),
    ('CINEMARK', 'Events'),

    // -------------------------------------------------------------------------
    // Healthcare → Pharmacy
    // -------------------------------------------------------------------------
    ('CVS', 'Pharmacy'),
    ('WALGREENS', 'Pharmacy'),
    ('RITE AID', 'Pharmacy'),

    // -------------------------------------------------------------------------
    // Personal Care → Gym
    // -------------------------------------------------------------------------
    ('PLANET FITNESS', 'Gym'),
    ('LA FITNESS', 'Gym'),
    ('ORANGETHEORY', 'Gym'),
    ('ANYTIME FITNESS', 'Gym'),
    ('EQUINOX', 'Gym'),
    ('YMCA', 'Gym'),
    ('GOLD GYM', 'Gym'),
    ('CRUNCH FITNESS', 'Gym'),
    ('LIFETIME FITNESS', 'Gym'),
    ('CROSSFIT', 'Gym'),

    // -------------------------------------------------------------------------
    // Personal Care → Haircuts
    // -------------------------------------------------------------------------
    ('GREAT CLIPS', 'Haircuts'),
    ('SUPERCUTS', 'Haircuts'),
    ('SPORTS CLIPS', 'Haircuts'),

    // -------------------------------------------------------------------------
    // Personal Care → Cosmetics
    // -------------------------------------------------------------------------
    ('ULTA', 'Cosmetics'),
    ('SEPHORA', 'Cosmetics'),
    ('BATH & BODY', 'Cosmetics'),
    ('SALLY BEAUTY', 'Cosmetics'),

    // -------------------------------------------------------------------------
    // Pets → Supplies
    // -------------------------------------------------------------------------
    ('PETCO', 'Supplies'),
    ('PETSMART', 'Supplies'),
    ('CHEWY', 'Supplies'),

    // -------------------------------------------------------------------------
    // Pets → Vet
    // -------------------------------------------------------------------------
    ('BANFIELD', 'Vet'),
    ('VCA ANIMAL', 'Vet'),

    // -------------------------------------------------------------------------
    // Housing → Utilities
    // -------------------------------------------------------------------------
    ('COMCAST', 'Utilities'),
    ('XFINITY', 'Utilities'),
    ('SPECTRUM', 'Utilities'),
    ('VERIZON', 'Utilities'),
    ('T-MOBILE', 'Utilities'),
    ('XCEL ENERGY', 'Utilities'),
    ('DUKE ENERGY', 'Utilities'),
    ('WASTE MGMT', 'Utilities'),
    ('WASTE MANAGEMENT', 'Utilities'),
    ('REPUBLIC SERVICE', 'Utilities'),
    ('WATER UTILITY', 'Utilities'),
    ('ELECTRIC CO', 'Utilities'),
    ('DOMINION ENERGY', 'Utilities'),
    ('SOUTHERN COMPANY', 'Utilities'),
    ('CONSUMERS ENERGY', 'Utilities'),
    ('ENTERGY', 'Utilities'),
    ('FIRSTENERGY', 'Utilities'),
    ('CENTERPOINT', 'Utilities'),
    ('COX COMM', 'Utilities'),
    ('FRONTIER COMM', 'Utilities'),
    ('CRICKET WIRELESS', 'Utilities'),
    ('BOOST MOBILE', 'Utilities'),
    ('MINT MOBILE', 'Utilities'),

    // -------------------------------------------------------------------------
    // Shopping → Clothing
    // -------------------------------------------------------------------------
    ('NIKE', 'Clothing'),
    ('OLD NAVY', 'Clothing'),
    ('GAP', 'Clothing'),
    ('ZARA', 'Clothing'),
    ('NORDSTROM', 'Clothing'),
    ('MACYS', 'Clothing'),
    ('MACY\'S', 'Clothing'),
    ('KOHLS', 'Clothing'),
    ('KOHL\'S', 'Clothing'),
    ('TJ MAXX', 'Clothing'),
    ('TJMAXX', 'Clothing'),
    ('MARSHALLS', 'Clothing'),
    ('ROSS', 'Clothing'),
    ('BURLINGTON', 'Clothing'),
    ('FOREVER 21', 'Clothing'),
    ('H&M', 'Clothing'),
    ('UNIQLO', 'Clothing'),
    ('AMERICAN EAGLE', 'Clothing'),
    ('BANANA REPUBLIC', 'Clothing'),
    ('EXPRESS', 'Clothing'),
    ('LULULEMON', 'Clothing'),
    ('ADIDAS', 'Clothing'),
    ('UNDER ARMOUR', 'Clothing'),
    ('FOOT LOCKER', 'Clothing'),
    ('FINISH LINE', 'Clothing'),

    // -------------------------------------------------------------------------
    // Shopping → Electronics
    // -------------------------------------------------------------------------
    ('BEST BUY', 'Electronics'),
    ('APPLE STORE', 'Electronics'),
    ('MICRO CENTER', 'Electronics'),
    ('B&H PHOTO', 'Electronics'),
    ('NEWEGG', 'Electronics'),

    // -------------------------------------------------------------------------
    // Shopping → Home Goods
    // -------------------------------------------------------------------------
    ('HOME DEPOT', 'Home Goods'),
    ('LOWES', 'Home Goods'),
    ('LOWE\'S', 'Home Goods'),
    ('BED BATH', 'Home Goods'),
    ('POTTERY BARN', 'Home Goods'),
    ('CRATE & BARREL', 'Home Goods'),
    ('PIER 1', 'Home Goods'),
    ('IKEA', 'Home Goods'),
    ('WAYFAIR', 'Home Goods'),
    ('WORLD MARKET', 'Home Goods'),
    ('WILLIAMS SONOMA', 'Home Goods'),
    ('RESTORATION HARDWARE', 'Home Goods'),
    ('ACE HARDWARE', 'Home Goods'),
    ('MENARDS', 'Home Goods'),
    ('HARBOR FREIGHT', 'Home Goods'),
    ('TRUE VALUE', 'Home Goods'),

    // -------------------------------------------------------------------------
    // Education → Books
    // -------------------------------------------------------------------------
    ('BARNES & NOBLE', 'Books'),
    ('HALF PRICE BOOKS', 'Books'),

    // -------------------------------------------------------------------------
    // Education → Courses
    // -------------------------------------------------------------------------
    ('UDEMY', 'Courses'),
    ('COURSERA', 'Courses'),
    ('SKILLSHARE', 'Courses'),
    ('MASTERCLASS', 'Courses'),
    ('LINKEDIN LEARNING', 'Courses'),

    // -------------------------------------------------------------------------
    // Travel → Flights
    // -------------------------------------------------------------------------
    ('SOUTHWEST', 'Flights'),
    ('DELTA AIR', 'Flights'),
    ('UNITED AIR', 'Flights'),
    ('AMERICAN AIR', 'Flights'),
    ('JETBLUE', 'Flights'),
    ('SPIRIT AIR', 'Flights'),
    ('FRONTIER AIR', 'Flights'),
    ('ALASKA AIR', 'Flights'),

    // -------------------------------------------------------------------------
    // Travel → Hotels
    // -------------------------------------------------------------------------
    ('MARRIOTT', 'Hotels'),
    ('HILTON', 'Hotels'),
    ('HYATT', 'Hotels'),
    ('IHG', 'Hotels'),
    ('BEST WESTERN', 'Hotels'),
    ('AIRBNB', 'Hotels'),
    ('VRBO', 'Hotels'),

    // -------------------------------------------------------------------------
    // Gifts & Donations → Charity
    // -------------------------------------------------------------------------
    ('RED CROSS', 'Charity'),
    ('UNITED WAY', 'Charity'),
    ('SALVATION ARMY', 'Charity'),
    ('GOODWILL', 'Charity'),

    // -------------------------------------------------------------------------
    // Housing → Insurance (home/renters)
    // -------------------------------------------------------------------------
    ('STATE FARM', 'Insurance'),
    ('ALLSTATE', 'Insurance'),
    ('GEICO', 'Insurance'),
    ('PROGRESSIVE', 'Insurance'),
    ('USAA', 'Insurance'),
    ('LIBERTY MUTUAL', 'Insurance'),
    ('NATIONWIDE', 'Insurance'),
    ('FARMERS INS', 'Insurance'),
  ];
}
