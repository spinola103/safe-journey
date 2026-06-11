import '../models/leg.dart';
import '../models/journey_plan.dart';

/// Pre-built Chennai demo routes.
/// These allow the app to be fully functional before the Maps API
/// integration is complete — critical for Day 1 GitHub commit.

class DemoRoutes {
  // ── Tambaram → T.Nagar (the pitch demo route) ─────────────────────
  static JourneyPlan tambToTNagarFastest = JourneyPlan(
    id: 'demo_001',
    userId: 'demo_user',
    guardianUid: 'demo_guardian',
    origin: 'Tambaram',
    destination: 'T.Nagar',
    legs: [
      Leg(
        mode: 'walk',
        startStop: 'Tambaram',
        endStop: 'Tambaram Bus Stop',
        durationMinutes: 5,
        fare: 0,
        safetyScore: 80,
        routeLabel: '400m',
      ),
      Leg(
        mode: 'bus',
        startStop: 'Tambaram Bus Stop',
        endStop: 'Guindy',
        durationMinutes: 38,
        fare: 15,
        safetyScore: 72,
        gtfsRouteId: '21C',
        routeLabel: '21C',
      ),
      Leg(
        mode: 'metro',
        startStop: 'Guindy Metro',
        endStop: 'T.Nagar',
        durationMinutes: 12,
        fare: 30,
        safetyScore: 91,
        gtfsRouteId: 'CMRL_GREEN',
        routeLabel: 'Green Line',
      ),
    ],
  );

  static JourneyPlan tambToTNagarCheapest = JourneyPlan(
    id: 'demo_002',
    userId: 'demo_user',
    guardianUid: 'demo_guardian',
    origin: 'Tambaram',
    destination: 'T.Nagar',
    legs: [
      Leg(
        mode: 'rail',
        startStop: 'Tambaram',
        endStop: 'Guindy',
        durationMinutes: 30,
        fare: 10,
        safetyScore: 85,
        gtfsRouteId: 'MRTS_MAIN',
        routeLabel: 'Suburban Rail',
      ),
      Leg(
        mode: 'metro',
        startStop: 'Guindy Metro',
        endStop: 'T.Nagar',
        durationMinutes: 12,
        fare: 30,
        safetyScore: 91,
        gtfsRouteId: 'CMRL_GREEN',
        routeLabel: 'Green Line',
      ),
    ],
  );

  static JourneyPlan tambToTNagarSafest = JourneyPlan(
    id: 'demo_003',
    userId: 'demo_user',
    guardianUid: 'demo_guardian',
    origin: 'Tambaram',
    destination: 'T.Nagar',
    legs: [
      Leg(
        mode: 'rail',
        startStop: 'Tambaram',
        endStop: 'Chennai Beach',
        durationMinutes: 55,
        fare: 15,
        safetyScore: 88,
        gtfsRouteId: 'MRTS_MAIN',
        routeLabel: 'Suburban Rail',
      ),
      Leg(
        mode: 'metro',
        startStop: 'Chennai Beach Metro',
        endStop: 'T.Nagar',
        durationMinutes: 22,
        fare: 40,
        safetyScore: 93,
        gtfsRouteId: 'CMRL_BLUE',
        routeLabel: 'Blue Line',
      ),
    ],
  );

  // ── Swap alternatives for Bus 21C leg ───────────────────────────────
  static List<Leg> alternativesForBus21C = [
    Leg(
      mode: 'rail',
      startStop: 'Tambaram',
      endStop: 'Guindy',
      durationMinutes: 30,
      fare: 10,
      safetyScore: 85,
      gtfsRouteId: 'MRTS_MAIN',
      routeLabel: 'Suburban Rail ★ Recommended in Women\'s Mode',
    ),
    Leg(
      mode: 'bus',
      startStop: 'Tambaram Bus Stop',
      endStop: 'Guindy',
      durationMinutes: 48,
      fare: 15,
      safetyScore: 72,
      gtfsRouteId: '21G',
      routeLabel: '21G (alternate)',
    ),
    Leg(
      mode: 'auto',
      startStop: 'Tambaram',
      endStop: 'Guindy',
      durationMinutes: 35,
      fare: 120,
      safetyScore: 65,
      routeLabel: 'Auto (estimated)',
    ),
  ];

  // ── Adyar → Egmore ───────────────────────────────────────────────────
  static JourneyPlan adyarToEgmore = JourneyPlan(
    id: 'demo_004',
    userId: 'demo_user',
    guardianUid: 'demo_guardian',
    origin: 'Adyar',
    destination: 'Egmore',
    legs: [
      Leg(
        mode: 'bus',
        startStop: 'Adyar Bus Stop',
        endStop: 'Saidapet',
        durationMinutes: 20,
        fare: 12,
        safetyScore: 74,
        gtfsRouteId: '5C',
        routeLabel: '5C',
      ),
      Leg(
        mode: 'metro',
        startStop: 'Saidapet Metro',
        endStop: 'Egmore',
        durationMinutes: 18,
        fare: 40,
        safetyScore: 90,
        gtfsRouteId: 'CMRL_BLUE',
        routeLabel: 'Blue Line',
      ),
    ],
  );

  static List<JourneyPlan> allDemoRoutes = [
    tambToTNagarFastest,
    tambToTNagarCheapest,
    tambToTNagarSafest,
    adyarToEgmore,
  ];
  static JourneyPlan adyarToEgmoreFastest = JourneyPlan(
  id: 'demo_004',
  userId: 'demo_user',
  guardianUid: 'demo_guardian',
  origin: 'Adyar',
  destination: 'Egmore',
  legs: [
    Leg(
      mode: 'bus',
      startStop: 'Adyar Bus Stop',
      endStop: 'Saidapet',
      durationMinutes: 20,
      fare: 12,
      safetyScore: 74,
      gtfsRouteId: '5C',
      routeLabel: '5C',
    ),
    Leg(
      mode: 'metro',
      startStop: 'Saidapet Metro',
      endStop: 'Egmore',
      durationMinutes: 18,
      fare: 40,
      safetyScore: 90,
      gtfsRouteId: 'CMRL_BLUE',
      routeLabel: 'Blue Line',
    ),
  ],
);

static JourneyPlan adyarToEgmoreCheapest = JourneyPlan(
  id: 'demo_005',
  userId: 'demo_user',
  guardianUid: 'demo_guardian',
  origin: 'Adyar',
  destination: 'Egmore',
  legs: [
    Leg(
      mode: 'bus',
      startStop: 'Adyar Depot',
      endStop: 'Egmore',
      durationMinutes: 42,
      fare: 10,
      safetyScore: 70,
      gtfsRouteId: '27D',
      routeLabel: '27D',
    ),
  ],
);

static JourneyPlan adyarToEgmoreSafest = JourneyPlan(
  id: 'demo_006',
  userId: 'demo_user',
  guardianUid: 'demo_guardian',
  origin: 'Adyar',
  destination: 'Egmore',
  legs: [
    Leg(
      mode: 'metro',
      startStop: 'Little Mount',
      endStop: 'Egmore',
      durationMinutes: 24,
      fare: 45,
      safetyScore: 94,
      gtfsRouteId: 'CMRL_BLUE',
      routeLabel: 'Blue Line',
    ),
  ],
);

static JourneyPlan annaNagarToGuindyFastest = JourneyPlan(
  id: 'demo_007',
  userId: 'demo_user',
  guardianUid: 'demo_guardian',
  origin: 'Anna Nagar',
  destination: 'Guindy',
  legs: [
    Leg(
      mode: 'metro',
      startStop: 'Anna Nagar Tower',
      endStop: 'Guindy',
      durationMinutes: 22,
      fare: 40,
      safetyScore: 89,
      gtfsRouteId: 'CMRL_GREEN',
      routeLabel: 'Green Line',
    ),
  ],
);

static JourneyPlan annaNagarToGuindyCheapest = JourneyPlan(
  id: 'demo_008',
  userId: 'demo_user',
  guardianUid: 'demo_guardian',
  origin: 'Anna Nagar',
  destination: 'Guindy',
  legs: [
    Leg(
      mode: 'bus',
      startStop: 'Anna Nagar',
      endStop: 'Guindy',
      durationMinutes: 50,
      fare: 12,
      safetyScore: 71,
      gtfsRouteId: 'M70',
      routeLabel: 'M70',
    ),
  ],
);

static JourneyPlan annaNagarToGuindySafest = JourneyPlan(
  id: 'demo_009',
  userId: 'demo_user',
  guardianUid: 'demo_guardian',
  origin: 'Anna Nagar',
  destination: 'Guindy',
  legs: [
    Leg(
      mode: 'metro',
      startStop: 'Anna Nagar East',
      endStop: 'Guindy',
      durationMinutes: 25,
      fare: 42,
      safetyScore: 95,
      gtfsRouteId: 'CMRL_GREEN',
      routeLabel: 'Green Line',
    ),
  ],
);

static final Map<String, List<JourneyPlan>> routeDatabase = {
  'Tambaram|T.Nagar': [
    tambToTNagarFastest,
    tambToTNagarCheapest,
    tambToTNagarSafest,
  ],
  'Adyar|Egmore': [
    adyarToEgmoreFastest,
    adyarToEgmoreCheapest,
    adyarToEgmoreSafest,
  ],
  'Anna Nagar|Guindy': [
    annaNagarToGuindyFastest,
    annaNagarToGuindyCheapest,
    annaNagarToGuindySafest,
  ],
};
  
  
}

