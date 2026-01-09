// ignore_for_file: use_super_parameters, prefer_const_constructors_in_immutables, sort_child_properties_last
import 'package:flutter/material.dart';

import 'storage/token_store.dart';
import 'api/http_client.dart';
import 'api/slots_api.dart';
import 'api/orders_api.dart';
import 'api/sales_api.dart';
import 'api/goals_api.dart';
import 'api/timeline_api.dart';
import 'api/orders_flow_api.dart';
import 'api/users_api.dart';
import 'api/vehicles_api.dart';
import 'providers/auth_provider.dart';

class TickinAppScope extends InheritedWidget {
  final TokenStore tokenStore;
  final HttpClient httpClient;

  final OrdersApi ordersApi;
  final SalesApi salesApi;
  final GoalsApi goalsApi;
  final TimelineApi timelineApi;
  final OrdersFlowApi flowApi;
  final UsersApi userApi;
  final VehiclesApi vehiclesApi;
  final SlotsApi slotsApi;

  final AuthProvider authProvider;

  TickinAppScope._({
    required super.child,
    required this.tokenStore,
    required this.httpClient,
    required this.ordersApi,
    required this.salesApi,
    required this.goalsApi,
    required this.timelineApi,
    required this.flowApi,
    required this.userApi,
    required this.vehiclesApi,
    required this.slotsApi,
    required this.authProvider,
    super.key,
  });

  factory TickinAppScope({
    Key? key,
    required Widget child,
    TokenStore? tokenStore,
  }) {
    final ts = tokenStore ?? TokenStore();
    final client = HttpClient(ts);

    return TickinAppScope._(
      key: key,
      child: child,
      tokenStore: ts,
      httpClient: client,
      ordersApi: OrdersApi(client),
      salesApi: SalesApi(client),
      goalsApi: GoalsApi(client),
      timelineApi: TimelineApi(client),
      flowApi: OrdersFlowApi(client),
      userApi: UsersApi(client),
      vehiclesApi: VehiclesApi(client),
      slotsApi: SlotsApi(client),
      authProvider: AuthProvider(ts),
    );
  }

  static TickinAppScope of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<TickinAppScope>();
    assert(scope != null, "TickinAppScope not found above this context");
    return scope!;
  }

  @override
  bool updateShouldNotify(TickinAppScope oldWidget) => false;
}
