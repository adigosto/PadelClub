namespace PadelClub.Model.Responses;

public sealed class MembershipTypeReferenceResponse
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; }
}