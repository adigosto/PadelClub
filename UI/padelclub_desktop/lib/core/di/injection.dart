import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/features/product/data/datasources/product_remote_data_source.dart';
import 'package:padelclub_desktop/features/product/data/repositories/product_repository_impl.dart';
import 'package:padelclub_desktop/features/product/domain/repositories/product_repository.dart';
import 'package:padelclub_desktop/features/product/domain/usecases/get_products.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/logged_product_provider.dart';
import 'package:padelclub_desktop/features/tournament/data/datasources/tournament_remote_data_source.dart';
import 'package:padelclub_desktop/features/tournament/data/repositories/tournament_repository_impl.dart';
import 'package:padelclub_desktop/features/tournament/domain/repositories/tournament_repository.dart';
import 'package:padelclub_desktop/features/tournament/domain/usecases/get_tournaments.dart';
import 'package:padelclub_desktop/features/tournament/presentation/providers/tournament_provider.dart';

import 'package:padelclub_desktop/features/tournament_participants/data/datasources/tournament_participant_remote_data_source.dart';
import 'package:padelclub_desktop/features/tournament_participants/data/repositories/tournament_participant_repository_impl.dart';
import 'package:padelclub_desktop/features/tournament_participants/domain/repositories/tournament_participant_repository.dart';
import 'package:padelclub_desktop/features/tournament_participants/domain/usecases/get_tournament_participants.dart';
import 'package:padelclub_desktop/features/tournament_participants/presentation/providers/tournament_participant_provider.dart';

import 'package:padelclub_desktop/features/roles/data/datasources/role_remote_data_source.dart';
import 'package:padelclub_desktop/features/roles/data/repositories/role_repository_impl.dart';
import 'package:padelclub_desktop/features/roles/domain/repositories/role_repository.dart';
import 'package:padelclub_desktop/features/roles/domain/usecases/get_roles.dart';
import 'package:padelclub_desktop/features/roles/presentation/providers/role_provider.dart';

import 'package:padelclub_desktop/features/reservations/data/datasources/reservation_remote_data_source.dart';
import 'package:padelclub_desktop/features/reservations/data/repositories/reservation_repository_impl.dart';
import 'package:padelclub_desktop/features/reservations/domain/repositories/reservation_repository.dart';
import 'package:padelclub_desktop/features/reservations/domain/usecases/get_reservations.dart';
import 'package:padelclub_desktop/features/reservations/presentation/providers/reservation_provider.dart';

import 'package:padelclub_desktop/features/product_types/data/datasources/product_type_remote_data_source.dart';
import 'package:padelclub_desktop/features/product_types/data/repositories/product_type_repository_impl.dart';
import 'package:padelclub_desktop/features/product_types/domain/repositories/product_type_repository.dart';
import 'package:padelclub_desktop/features/product_types/domain/usecases/get_product_types.dart';
import 'package:padelclub_desktop/features/product_types/presentation/providers/product_type_provider.dart';

import 'package:padelclub_desktop/features/product_categories/data/datasources/product_category_remote_data_source.dart';
import 'package:padelclub_desktop/features/product_categories/data/repositories/product_category_repository_impl.dart';
import 'package:padelclub_desktop/features/product_categories/domain/repositories/product_category_repository.dart';
import 'package:padelclub_desktop/features/product_categories/domain/usecases/get_product_categories.dart';
import 'package:padelclub_desktop/features/product_categories/presentation/providers/product_category_provider.dart';

import 'package:padelclub_desktop/features/payments/data/datasources/payment_remote_data_source.dart';
import 'package:padelclub_desktop/features/payments/data/repositories/payment_repository_impl.dart';
import 'package:padelclub_desktop/features/payments/domain/repositories/payment_repository.dart';
import 'package:padelclub_desktop/features/payments/domain/usecases/get_payments.dart';
import 'package:padelclub_desktop/features/payments/presentation/providers/payment_provider.dart';

import 'package:padelclub_desktop/features/orders/data/datasources/order_remote_data_source.dart';
import 'package:padelclub_desktop/features/orders/data/repositories/order_repository_impl.dart';
import 'package:padelclub_desktop/features/orders/domain/repositories/order_repository.dart';
import 'package:padelclub_desktop/features/orders/domain/usecases/get_orders.dart';
import 'package:padelclub_desktop/features/orders/presentation/providers/order_provider.dart';
import 'package:padelclub_desktop/features/order_items/data/datasources/order_item_remote_data_source.dart';
import 'package:padelclub_desktop/features/order_items/data/repositories/order_item_repository_impl.dart';
import 'package:padelclub_desktop/features/order_items/domain/repositories/order_item_repository.dart';
import 'package:padelclub_desktop/features/order_items/domain/usecases/get_order_items.dart';
import 'package:padelclub_desktop/features/order_items/presentation/providers/order_item_provider.dart';

import 'package:padelclub_desktop/features/memberships/data/datasources/membership_remote_data_source.dart';
import 'package:padelclub_desktop/features/memberships/data/repositories/membership_repository_impl.dart';
import 'package:padelclub_desktop/features/memberships/domain/repositories/membership_repository.dart';
import 'package:padelclub_desktop/features/memberships/domain/usecases/get_memberships.dart';
import 'package:padelclub_desktop/features/memberships/presentation/providers/membership_provider.dart';

import 'package:padelclub_desktop/features/match_participants/data/datasources/match_participant_remote_data_source.dart';
import 'package:padelclub_desktop/features/match_participants/data/repositories/match_participant_repository_impl.dart';
import 'package:padelclub_desktop/features/match_participants/domain/repositories/match_participant_repository.dart';
import 'package:padelclub_desktop/features/match_participants/domain/usecases/get_match_participants.dart';
import 'package:padelclub_desktop/features/match_participants/presentation/providers/match_participant_provider.dart';

class InjectionContainer {
  static final InjectionContainer _instance = InjectionContainer._internal();
  factory InjectionContainer() => _instance;
  InjectionContainer._internal();

  late final http.Client httpClient;
  late final ProductRemoteDataSource productRemoteDataSource;
  late final ProductRepository productRepository;
  late final GetProducts getProductsUseCase;
  late final LoggedProductProvider loggedProductProvider;
  late final TournamentRemoteDataSource tournamentRemoteDataSource;
  late final TournamentRepository tournamentRepository;
  late final GetTournaments getTournamentsUseCase;
  late final TournamentProvider tournamentProvider;

  late final TournamentParticipantRemoteDataSource tournamentParticipantRemoteDataSource;
  late final TournamentParticipantRepository tournamentParticipantRepository;
  late final GetTournamentParticipants getTournamentParticipantsUseCase;
  late final TournamentParticipantProvider tournamentParticipantProvider;

  late final RoleRemoteDataSource roleRemoteDataSource;
  late final RoleRepository roleRepository;
  late final GetRoles getRolesUseCase;
  late final RoleProvider roleProvider;

  late final ReservationRemoteDataSource reservationRemoteDataSource;
  late final ReservationRepository reservationRepository;
  late final GetReservations getReservationsUseCase;
  late final ReservationProvider reservationProvider;
  late final ProductTypeRemoteDataSource productTypeRemoteDataSource;
  late final ProductTypeRepository productTypeRepository;
  late final GetProductTypes getProductTypesUseCase;
  late final ProductTypeProvider productTypeProvider;

  late final ProductCategoryRemoteDataSource productCategoryRemoteDataSource;
  late final ProductCategoryRepository productCategoryRepository;
  late final GetProductCategories getProductCategoriesUseCase;
  late final ProductCategoryProvider productCategoryProvider;

  late final PaymentRemoteDataSource paymentRemoteDataSource;
  late final PaymentRepository paymentRepository;
  late final GetPayments getPaymentsUseCase;
  late final PaymentProvider paymentProvider;

  late final OrderRemoteDataSource orderRemoteDataSource;
  late final OrderRepository orderRepository;
  late final GetOrders getOrdersUseCase;
  late final OrderProvider orderProvider;
  late final OrderItemRemoteDataSource orderItemRemoteDataSource;
  late final OrderItemRepository orderItemRepository;
  late final GetOrderItems getOrderItemsUseCase;
  late final OrderItemProvider orderItemProvider;

  late final MembershipRemoteDataSource membershipRemoteDataSource;
  late final MembershipRepository membershipRepository;
  late final GetMemberships getMembershipsUseCase;
  late final MembershipProvider membershipProvider;

  late final MatchParticipantRemoteDataSource matchParticipantRemoteDataSource;
  late final MatchParticipantRepository matchParticipantRepository;
  late final GetMatchParticipants getMatchParticipantsUseCase;
  late final MatchParticipantProvider matchParticipantProvider;

  void init() {
    httpClient = http.Client();
    productRemoteDataSource = ProductRemoteDataSourceImpl(client: httpClient);
    productRepository = ProductRepositoryImpl(remoteDataSource: productRemoteDataSource);
    getProductsUseCase = GetProducts(productRepository);
    loggedProductProvider = LoggedProductProvider();
    tournamentRemoteDataSource = TournamentRemoteDataSourceImpl(client: httpClient);
    tournamentRepository = TournamentRepositoryImpl(remoteDataSource: tournamentRemoteDataSource);
    getTournamentsUseCase = GetTournaments(tournamentRepository);
    tournamentProvider = TournamentProvider();

    tournamentParticipantRemoteDataSource = TournamentParticipantRemoteDataSourceImpl(client: httpClient);
    tournamentParticipantRepository = TournamentParticipantRepositoryImpl(remoteDataSource: tournamentParticipantRemoteDataSource);
    getTournamentParticipantsUseCase = GetTournamentParticipants(tournamentParticipantRepository);
    tournamentParticipantProvider = TournamentParticipantProvider();

    roleRemoteDataSource = RoleRemoteDataSourceImpl(client: httpClient);
    roleRepository = RoleRepositoryImpl(remoteDataSource: roleRemoteDataSource);
    getRolesUseCase = GetRoles(roleRepository);
    roleProvider = RoleProvider();

    reservationRemoteDataSource = ReservationRemoteDataSourceImpl(client: httpClient);
    reservationRepository = ReservationRepositoryImpl(remoteDataSource: reservationRemoteDataSource);
    getReservationsUseCase = GetReservations(reservationRepository);
    reservationProvider = ReservationProvider();
    productTypeRemoteDataSource = ProductTypeRemoteDataSourceImpl(client: httpClient);
    productTypeRepository = ProductTypeRepositoryImpl(remoteDataSource: productTypeRemoteDataSource);
    getProductTypesUseCase = GetProductTypes(productTypeRepository);
    productTypeProvider = ProductTypeProvider();

    productCategoryRemoteDataSource = ProductCategoryRemoteDataSourceImpl(client: httpClient);
    productCategoryRepository = ProductCategoryRepositoryImpl(remoteDataSource: productCategoryRemoteDataSource);
    getProductCategoriesUseCase = GetProductCategories(productCategoryRepository);
    productCategoryProvider = ProductCategoryProvider();

    paymentRemoteDataSource = PaymentRemoteDataSourceImpl(client: httpClient);
    paymentRepository = PaymentRepositoryImpl(remoteDataSource: paymentRemoteDataSource);
    getPaymentsUseCase = GetPayments(paymentRepository);
    paymentProvider = PaymentProvider();

    orderRemoteDataSource = OrderRemoteDataSourceImpl(client: httpClient);
    orderRepository = OrderRepositoryImpl(remoteDataSource: orderRemoteDataSource);
    getOrdersUseCase = GetOrders(orderRepository);
    orderProvider = OrderProvider();

    orderItemRemoteDataSource = OrderItemRemoteDataSourceImpl(client: httpClient);
    orderItemRepository = OrderItemRepositoryImpl(remoteDataSource: orderItemRemoteDataSource);
    getOrderItemsUseCase = GetOrderItems(orderItemRepository);
    orderItemProvider = OrderItemProvider();

    membershipRemoteDataSource = MembershipRemoteDataSourceImpl(client: httpClient);
    membershipRepository = MembershipRepositoryImpl(remoteDataSource: membershipRemoteDataSource);
    getMembershipsUseCase = GetMemberships(membershipRepository);
    membershipProvider = MembershipProvider();

    matchParticipantRemoteDataSource = MatchParticipantRemoteDataSourceImpl(client: httpClient);
    matchParticipantRepository = MatchParticipantRepositoryImpl(remoteDataSource: matchParticipantRemoteDataSource);
    getMatchParticipantsUseCase = GetMatchParticipants(matchParticipantRepository);
    matchParticipantProvider = MatchParticipantProvider();
  }
}

final sl = InjectionContainer();
