import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/route_request.dart';
import '../../domain/transit_models.dart';
import '../../services/konya_multimodal_planner_service.dart';

class ActiveTransitState {
  final TransitJourneyResult? result;
  final bool isLoading;

  const ActiveTransitState({this.result, this.isLoading = false});

  ActiveTransitState copyWith({
    TransitJourneyResult? result,
    bool? isLoading,
    bool clearResult = false,
  }) {
    return ActiveTransitState(
      result: clearResult ? null : (result ?? this.result),
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

final multimodalPlannerServiceProvider =
    Provider<KonyaMultimodalPlannerService>((ref) {
      return KonyaMultimodalPlannerService();
    });

class ActiveTransitNotifier extends Notifier<ActiveTransitState> {
  @override
  ActiveTransitState build() {
    return const ActiveTransitState();
  }

  Future<void> calculateTransitJourney(RouteRequest request) async {
    state = state.copyWith(isLoading: true);
    final service = ref.read(multimodalPlannerServiceProvider);
    try {
      final result = await service.calculateMultimodalJourney(request);
      state = ActiveTransitState(result: result, isLoading: false);
    } catch (_) {
      state = const ActiveTransitState(isLoading: false);
    }
  }

  void clearTransitJourney() {
    state = const ActiveTransitState();
  }
}

final activeTransitProvider =
    NotifierProvider<ActiveTransitNotifier, ActiveTransitState>(
      ActiveTransitNotifier.new,
    );
