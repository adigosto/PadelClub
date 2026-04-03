namespace PadelClub.Model.Requests
{
    public class OrderInsertRequest
    {
        public int UserId { get; set; }
        public string OrderNumber { get; set; } = string.Empty;
        public decimal TotalAmount { get; set; }
        public string Status { get; set; } = "Pending";
        public string ShippingAddress { get; set; } = string.Empty;
        public string? Notes { get; set; }
    }
}
