import 'package:flutter/material.dart';
import '../../core/models/route_result.dart';
import '../../core/models/routing_options.dart';

/// Widget for displaying multiple route options and allowing user selection
class RouteSelectionWidget extends StatefulWidget {
  final List<RouteResult> routes;
  final Function(RouteResult) onRouteSelected;
  final VoidCallback? onCancel;
  final String? title;

  const RouteSelectionWidget({
    super.key,
    required this.routes,
    required this.onRouteSelected,
    this.onCancel,
    this.title,
  });

  @override
  State<RouteSelectionWidget> createState() => _RouteSelectionWidgetState();
}

class _RouteSelectionWidgetState extends State<RouteSelectionWidget> {
  int? _selectedIndex;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title ?? 'Choose your route',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onCancel != null)
                  IconButton(
                    onPressed: widget.onCancel,
                    icon: const Icon(Icons.close),
                  ),
              ],
            ),
          ),
          
          // Route options
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.routes.length,
              itemBuilder: (context, index) {
                final routeResult = widget.routes[index];
                final route = routeResult.route;
                final isSelected = _selectedIndex == index;
                final isFastest = index == 0; // Assuming first route is fastest
                
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: isSelected ? Colors.blue : Colors.grey[300]!,
                      width: isSelected ? 2 : 1,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: isSelected ? Colors.blue.withValues(alpha: 0.05) : null,
                  ),
                  child: ListTile(
                    onTap: () {
                      setState(() {
                        _selectedIndex = index;
                      });
                    },
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: _getRouteTypeColor(routeResult.routeType),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(
                        _getRouteTypeIcon(routeResult.routeType),
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Row(
                      children: [
                        Text(
                          _getRouteTypeName(routeResult.routeType),
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.blue : null,
                          ),
                        ),
                        if (isFastest) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'FASTEST',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDuration(route.duration),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Icon(
                              Icons.straighten,
                              size: 16,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 4),
                            Text(
                              _formatDistance(route.distance),
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        if (routeResult.metadata.additionalData.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            _getRouteDescription(routeResult.routeType),
                            style: TextStyle(
                              color: Colors.grey[500],
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                    trailing: isSelected
                        ? const Icon(Icons.check_circle, color: Colors.blue)
                        : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
          
          // Action buttons
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (widget.onCancel != null) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: widget.onCancel,
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _selectedIndex != null
                        ? () => widget.onRouteSelected(widget.routes[_selectedIndex!])
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text(
                      'Start Navigation',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _getRouteTypeColor(RouteType routeType) {
    switch (routeType) {
      case RouteType.timeOptimized:
        return Colors.blue;
      case RouteType.distanceOptimized:
        return Colors.green;
      case RouteType.noTraffic:
        return Colors.orange;
      case RouteType.ecoFriendly:
        return Colors.teal;
      case RouteType.tollFree:
        return Colors.purple;
      case RouteType.scenicRoute:
        return Colors.indigo;
      case RouteType.balanced:
        return Colors.grey;
    }
  }

  IconData _getRouteTypeIcon(RouteType routeType) {
    switch (routeType) {
      case RouteType.timeOptimized:
        return Icons.speed;
      case RouteType.distanceOptimized:
        return Icons.straighten;
      case RouteType.noTraffic:
        return Icons.traffic;
      case RouteType.ecoFriendly:
        return Icons.eco;
      case RouteType.tollFree:
        return Icons.money_off;
      case RouteType.scenicRoute:
        return Icons.landscape;
      case RouteType.balanced:
        return Icons.balance;
    }
  }

  String _getRouteTypeName(RouteType routeType) {
    switch (routeType) {
      case RouteType.timeOptimized:
        return 'Fastest Route';
      case RouteType.distanceOptimized:
        return 'Shortest Route';
      case RouteType.noTraffic:
        return 'Avoid Traffic';
      case RouteType.ecoFriendly:
        return 'Eco-Friendly';
      case RouteType.tollFree:
        return 'Toll-Free';
      case RouteType.scenicRoute:
        return 'Scenic Route';
      case RouteType.balanced:
        return 'Balanced Route';
    }
  }

  String _getRouteDescription(RouteType routeType) {
    switch (routeType) {
      case RouteType.timeOptimized:
        return 'Uses current traffic data for fastest arrival';
      case RouteType.distanceOptimized:
        return 'Minimizes total distance traveled';
      case RouteType.noTraffic:
        return 'Avoids heavy traffic areas';
      case RouteType.ecoFriendly:
        return 'Optimized for fuel efficiency';
      case RouteType.tollFree:
        return 'Avoids toll roads and bridges';
      case RouteType.scenicRoute:
        return 'Takes more scenic roads when possible';
      case RouteType.balanced:
        return 'Balances time, distance, and traffic';
    }
  }

  String _formatDuration(double durationInSeconds) {
    final duration = Duration(seconds: durationInSeconds.round());
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else {
      return '${minutes}m';
    }
  }

  String _formatDistance(double distanceInMeters) {
    if (distanceInMeters >= 1000) {
      final km = distanceInMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    } else {
      return '${distanceInMeters.round()} m';
    }
  }
}