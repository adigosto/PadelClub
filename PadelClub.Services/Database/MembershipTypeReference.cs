namespace PadelClub.Services.Database;

public class MembershipTypeReference
{
    public int Id { get; set; }
    public string Name { get; set; } = string.Empty;
    public bool IsActive { get; set; } = true;
}