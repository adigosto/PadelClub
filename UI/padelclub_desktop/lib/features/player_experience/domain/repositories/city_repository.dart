import 'package:padelclub_desktop/features/player_experience/domain/entities/player_city.dart';

abstract class CityRepository {
  Future<List<PlayerCity>> getCities();
}
