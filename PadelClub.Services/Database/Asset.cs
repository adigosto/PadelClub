using System;

namespace PadelClub.Services.Database
{
    public class Asset
    {
        public int Id { get; set; }
        public int ProductId { get; set; }
        public string Base64Image { get; set; } = string.Empty;
        public int DisplayOrder { get; set; } = 0;
        public bool IsPrimary { get; set; } = false;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public virtual Product Product { get; set; } = null!;
    }
}

