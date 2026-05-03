using System;
using System.ComponentModel.DataAnnotations;

namespace PadelClub.Services.Database
{
    public class Product
    {
        public int Id { get; set; }
        public string Name { get; set; } = string.Empty;
        public string Description { get; set; } = string.Empty;
        public decimal Price { get; set; }
        public int StockQuantity { get; set; }
        public int ProductCategoryId { get; set; }
        public int ProductTypeId { get; set; }
        public string? ImageUrl { get; set; }
        public bool IsActive { get; set; } = true;
        public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
        public DateTime? UpdatedAt { get; set; }

        // Navigation properties
        public virtual ProductCategory ProductCategory { get; set; } = null!;
        public virtual ProductType ProductType { get; set; } = null!;
        public virtual ICollection<OrderItem> OrderItems { get; set; } = new List<OrderItem>();
        public virtual ICollection<Asset> Assets { get; set; } = new List<Asset>();
        [MaxLength(1000)]
        public string ProductState { get; set; } = string.Empty;
    }
}

