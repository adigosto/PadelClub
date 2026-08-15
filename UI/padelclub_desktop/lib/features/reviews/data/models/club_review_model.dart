import 'package:padelclub_desktop/features/reviews/domain/entities/club_review.dart';

class ClubReviewModel extends ClubReview {
  const ClubReviewModel({
    required super.id,
    required super.userId,
    required super.memberName,
    required super.rating,
    required super.comment,
    required super.createdAt,
  });

  factory ClubReviewModel.fromJson(Map<String, dynamic> json) {
    return ClubReviewModel(
      id: json['id'] as int,
      userId: json['userId'] as int,
      memberName: json['memberName'] as String? ?? 'Club member',
      rating: json['rating'] as int? ?? 0,
      comment: json['comment'] as String? ?? '',
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
