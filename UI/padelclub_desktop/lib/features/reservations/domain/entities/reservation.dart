class Reservation {
  int? id;
  int courtId;
  int userId;
  DateTime start;
  DateTime end;

  Reservation({this.id, required this.courtId, required this.userId, required this.start, required this.end});
}
