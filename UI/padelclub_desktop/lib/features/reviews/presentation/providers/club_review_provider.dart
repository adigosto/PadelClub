import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:padelclub_desktop/core/network/api_config.dart';
import 'package:padelclub_desktop/features/reviews/data/models/club_review_model.dart';
import 'package:padelclub_desktop/features/reviews/domain/entities/club_review.dart';
import 'package:padelclub_desktop/providers/auth_provider.dart';

class ClubReviewProvider extends ChangeNotifier {
  List<ClubReview> reviews = const [];
  bool isLoading = false;
  String? errorMessage;
  bool isSaving = false;

  Future<void> loadPublished() async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}/ClubReviews').replace(
        queryParameters: {'PageSize': '10', 'IncludeTotalCount': 'true'},
      );
      final response = await http.get(
        uri,
        headers: AuthProvider.authenticatedHeaders(),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception('Club reviews could not be loaded.');
      }
      final decoded = jsonDecode(response.body) as Map<String, dynamic>;
      reviews = (decoded['items'] as List<dynamic>? ?? const [])
          .map((item) => ClubReviewModel.fromJson(item as Map<String, dynamic>))
          .where((review) => review.comment.trim().isNotEmpty)
          .toList(growable: false);
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> saveMine({required int rating, required String comment}) async {
    isSaving = true;
    errorMessage = null;
    notifyListeners();
    try {
      final response = await http.put(
        Uri.parse('${ApiConfig.baseUrl}/ClubReviews/mine'),
        headers: AuthProvider.authenticatedHeaders(),
        body: jsonEncode({'rating': rating, 'comment': comment.trim()}),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw Exception(
          response.body.trim().isEmpty
              ? 'Your review could not be saved.'
              : response.body.replaceAll('"', ''),
        );
      }
      await loadPublished();
      return true;
    } catch (error) {
      errorMessage = error.toString().replaceFirst('Exception: ', '');
      return false;
    } finally {
      isSaving = false;
      notifyListeners();
    }
  }
}
