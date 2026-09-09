namespace PadelClub.Model.Requests;

public sealed class CancelReservationRequest
{
    public string Reason { get; set; } = string.Empty;
}
