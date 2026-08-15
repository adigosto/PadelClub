namespace PadelClub.Services.Database;

public class InventoryMovement
{
    public long Id { get; set; }
    public int ProductId { get; set; }
    public int QuantityChange { get; set; }
    public int BalanceAfter { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string ReferenceType { get; set; } = string.Empty;
    public int? ReferenceId { get; set; }
    public int? ActorUserId { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public Product Product { get; set; } = null!;
}
