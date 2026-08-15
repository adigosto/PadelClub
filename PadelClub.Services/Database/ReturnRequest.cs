namespace PadelClub.Services.Database;

public class ReturnRequest
{
    public int Id { get; set; }
    public int OrderId { get; set; }
    public int UserId { get; set; }
    public string Reason { get; set; } = string.Empty;
    public string Status { get; set; } = "Requested";
    public decimal RefundAmount { get; set; }
    public string? AdminNotes { get; set; }
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? ResolvedAt { get; set; }
    public Order Order { get; set; } = null!;
    public ICollection<ReturnRequestItem> Items { get; set; } = new List<ReturnRequestItem>();
}

public class ReturnRequestItem
{
    public int Id { get; set; }
    public int ReturnRequestId { get; set; }
    public int OrderItemId { get; set; }
    public int Quantity { get; set; }
    public decimal RefundAmount { get; set; }
    public bool Restocked { get; set; }
    public ReturnRequest ReturnRequest { get; set; } = null!;
    public OrderItem OrderItem { get; set; } = null!;
}
