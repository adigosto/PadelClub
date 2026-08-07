import 'dart:developer' as developer;

import 'package:padelclub_desktop/features/product/domain/entities/product.dart';
import 'package:padelclub_desktop/features/product/data/models/search_result.dart';
import 'package:padelclub_desktop/features/product/presentation/providers/product_provider.dart';

class LoggedProductProvider extends ProductProvider {
  LoggedProductProvider({super.baseUrl});

  @override
  Future<SearchResult<Product>> get({Map<String, dynamic>? filter}) async {
    final stopwatch = Stopwatch()..start();
    developer.log('Starting product fetch request', name: 'LoggedProductProvider');

    try {
      final result = await super.get(filter: filter);
      stopwatch.stop();
      developer.log(
        'Product fetch completed in ${stopwatch.elapsed}',
        name: 'LoggedProductProvider',
      );
      return result;
    } catch (e) {
      stopwatch.stop();
      developer.log(
        'Error fetching products after ${stopwatch.elapsed}: $e',
        name: 'LoggedProductProvider',
      );
      rethrow;
    }
  }
}
