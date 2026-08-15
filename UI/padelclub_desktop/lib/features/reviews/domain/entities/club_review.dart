class ClubReview {
  const ClubReview({
    required this.id,
    required this.userId,
    required this.memberName,
    required this.rating,
    required this.comment,
    required this.createdAt,
  });

  final int id;
  final int userId;
  final String memberName;
  final int rating;
  final String comment;
  final DateTime createdAt;
}
