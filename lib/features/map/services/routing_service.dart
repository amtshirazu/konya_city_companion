import '../domain/route_request.dart';
import '../domain/route_result.dart';

abstract class RoutingService {
  Future<RouteResult> calculateRoute(RouteRequest request);
}
