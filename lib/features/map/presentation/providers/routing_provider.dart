import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/route_request.dart';
import '../../domain/route_result.dart';
import '../../domain/travel_mode.dart';
import '../../services/osrm_routing_service.dart';
import '../../services/routing_service.dart';

final routingServiceProvider = Provider<RoutingService>((ref) {
  return OsrmRoutingService();
});

class TravelModeNotifier extends Notifier<TravelMode> {
  @override
  TravelMode build() {
    return TravelMode.walking;
  }

  void setMode(TravelMode mode) {
    state = mode;
  }
}

final travelModeProvider = NotifierProvider<TravelModeNotifier, TravelMode>(
  TravelModeNotifier.new,
);

class ActiveRouteState {
  final RouteResult? result;
  final bool isLoading;
  final String? errorMessage;

  const ActiveRouteState({
    this.result,
    this.isLoading = false,
    this.errorMessage,
  });

  ActiveRouteState copyWith({
    RouteResult? result,
    bool? isLoading,
    String? errorMessage,
    bool clearResult = false,
  }) {
    return ActiveRouteState(
      result: clearResult ? null : (result ?? this.result),
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

class ActiveRouteNotifier extends Notifier<ActiveRouteState> {
  @override
  ActiveRouteState build() {
    return const ActiveRouteState();
  }

  Future<RouteResult?> fetchRoute(RouteRequest request) async {
    state = state.copyWith(isLoading: true, errorMessage: null);

    final service = ref.read(routingServiceProvider);
    try {
      final result = await service.calculateRoute(request);
      state = state.copyWith(
        result: result,
        isLoading: false,
        errorMessage: result.errorMessage,
      );
      return result;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: 'Failed to calculate route: $e',
      );
      return null;
    }
  }

  void clearRoute() {
    state = const ActiveRouteState();
  }
}

final activeRouteProvider =
    NotifierProvider<ActiveRouteNotifier, ActiveRouteState>(
      ActiveRouteNotifier.new,
    );
