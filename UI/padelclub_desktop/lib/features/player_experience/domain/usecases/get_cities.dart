import 'package:padelclub_desktop/features/player_experience/domain/entities/player_city.dart';
import 'package:padelclub_desktop/features/player_experience/domain/repositories/city_repository.dart';

class GetCities {
  const GetCities(this.repository);
  final CityRepository repository;
  Future<List<PlayerCity>> call() => repository.getCities();
}
