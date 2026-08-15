using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbOrder = PadelClub.Services.Database.Order;

namespace PadelClub.Services
{
    public class OrderService : BaseCRUDService<OrderResponse, OrderSearchObject, DbOrder, OrderInsertRequest, OrderUpdateRequest>, IOrderService
    {
        private readonly INotificationService _notificationService;

        public OrderService(PadelClubContext dbContext, IMapper mapper, INotificationService notificationService) : base(dbContext, mapper)
        {
            _notificationService = notificationService;
        }

        public override async Task<OrderResponse> CreateAsync(OrderInsertRequest request)
        {
            var created = await base.CreateAsync(request);
            await _notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = "Order received",
                Message = $"Order {created.OrderNumber} was received and is {created.Status.ToLowerInvariant()}.",
                Type = "Orders",
                RecipientUserIds = new List<int> { created.UserId }
            });
            return created;
        }

        public async Task<OrderResponse> CheckoutAsync(int userId, CheckoutRequest request)
        {
            var address = request.ShippingAddress.Trim();
            var recipientName = request.RecipientName.Trim();
            var phoneNumber = request.PhoneNumber.Trim();
            var city = request.City.Trim();
            var postalCode = request.PostalCode.Trim();
            if (recipientName.Length < 2)
                throw new InvalidOperationException("A recipient name is required.");
            if (phoneNumber.Length < 6)
                throw new InvalidOperationException("A valid phone number is required.");
            if (address.Length < 5)
                throw new InvalidOperationException("A valid shipping address is required.");
            if (city.Length < 2 || postalCode.Length < 3)
                throw new InvalidOperationException("A city and postal code are required.");
            if (request.Items.Count == 0)
                throw new InvalidOperationException("The cart is empty.");

            var requested = request.Items
                .GroupBy(x => x.ProductId)
                .ToDictionary(x => x.Key, x => x.Sum(line => line.Quantity));
            if (requested.Any(x => x.Key <= 0 || x.Value <= 0 || x.Value > 100))
                throw new InvalidOperationException("The cart contains an invalid quantity.");

            await using var transaction = await _dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            var productIds = requested.Keys.ToList();
            var products = await _dbContext.Products
                .Where(x => productIds.Contains(x.Id))
                .ToListAsync();
            if (products.Count != productIds.Count)
                throw new InvalidOperationException("One or more products no longer exist.");

            foreach (var product in products)
            {
                if (!product.IsActive || product.ProductState.Contains("deactivated"))
                    throw new InvalidOperationException($"{product.Name} is no longer available.");
                if (product.StockQuantity < requested[product.Id])
                    throw new InvalidOperationException($"Only {product.StockQuantity} units of {product.Name} remain.");
            }

            var subtotal = products.Sum(product => product.Price * requested[product.Id]);
            Coupon? coupon = null;
            var discount = 0m;
            if (!string.IsNullOrWhiteSpace(request.CouponCode))
            {
                var code = request.CouponCode.Trim().ToUpperInvariant();
                coupon = await _dbContext.Coupons.Include(x => x.Redemptions).SingleOrDefaultAsync(x => x.Code == code);
                var now = DateTime.UtcNow;
                if (coupon is null || !coupon.IsActive || coupon.ValidFrom > now || coupon.ValidUntil < now)
                    throw new InvalidOperationException("The coupon is invalid or expired.");
                if (coupon.UsageLimit.HasValue && coupon.UsageCount >= coupon.UsageLimit.Value)
                    throw new InvalidOperationException("The coupon usage limit has been reached.");
                if (coupon.Redemptions.Count(x => x.UserId == userId) >= coupon.PerUserLimit)
                    throw new InvalidOperationException("You have already used this coupon.");
                discount = CommerceCalculator.CouponDiscount(coupon, subtotal);
                if (discount <= 0) throw new InvalidOperationException($"This coupon requires an order of at least {coupon.MinimumOrderAmount:0.00}.");
            }

            var order = new DbOrder
            {
                UserId = userId,
                OrderNumber = $"PC-{DateTime.UtcNow:yyyyMMddHHmmss}-{Guid.NewGuid().ToString("N")[..6].ToUpperInvariant()}",
                Status = "Pending",
                RecipientName = recipientName,
                PhoneNumber = phoneNumber,
                ShippingAddress = address,
                City = city,
                PostalCode = postalCode,
                Notes = string.IsNullOrWhiteSpace(request.Notes) ? null : request.Notes.Trim(),
                SubtotalAmount = subtotal,
                DiscountAmount = discount,
                CouponId = coupon?.Id,
                CouponCode = coupon?.Code,
                OrderItems = products.Select(product => new OrderItem
                {
                    ProductId = product.Id,
                    Quantity = requested[product.Id],
                    UnitPrice = product.Price,
                    TotalPrice = product.Price * requested[product.Id]
                }).ToList()
            };
            order.TotalAmount = subtotal - discount;
            foreach (var product in products)
                product.StockQuantity -= requested[product.Id];

            _dbContext.Orders.Add(order);
            await _dbContext.SaveChangesAsync();
            foreach (var product in products)
                _dbContext.InventoryMovements.Add(new InventoryMovement { ProductId = product.Id, QuantityChange = -requested[product.Id], BalanceAfter = product.StockQuantity, Reason = "Order checkout", ReferenceType = "Order", ReferenceId = order.Id, ActorUserId = userId });
            if (coupon is not null)
            {
                coupon.UsageCount++;
                _dbContext.CouponRedemptions.Add(new CouponRedemption { CouponId = coupon.Id, UserId = userId, OrderId = order.Id, DiscountAmount = discount });
            }
            await _dbContext.SaveChangesAsync();
            await transaction.CommitAsync();

            var response = _mapper.Map<OrderResponse>(order);
            await _notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = "Order received",
                Message = $"Order {response.OrderNumber} was received and is pending.",
                Type = "Orders",
                RecipientUserIds = new List<int> { userId }
            });
            return response;
        }

        public Task<PadelClub.Model.Responses.PagedResult<OrderResponse>> GetForUserAsync(
            int userId,
            OrderSearchObject search)
        {
            search.UserId = userId;
            return GetAsync(search);
        }

        public override async Task<OrderResponse?> UpdateAsync(int id, OrderUpdateRequest request)
        {
            await using var transaction = await _dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            var previousStatus = await _dbContext.Orders
                .Where(x => x.Id == id)
                .Select(x => x.Status)
                .FirstOrDefaultAsync();
            if (request.Status.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) && previousStatus is "Shipped" or "Delivered")
                throw new InvalidOperationException("Shipped or delivered orders cannot be cancelled.");
            var updated = await base.UpdateAsync(id, request);
            if (updated != null && request.Status.Equals("Cancelled", StringComparison.OrdinalIgnoreCase) && !string.Equals(previousStatus, "Cancelled", StringComparison.OrdinalIgnoreCase))
            {
                var lines = await _dbContext.OrderItems.Include(x => x.Product).Where(x => x.OrderId == id).ToListAsync();
                foreach (var line in lines)
                {
                    line.Product.StockQuantity += line.Quantity;
                    _dbContext.InventoryMovements.Add(new InventoryMovement { ProductId = line.ProductId, QuantityChange = line.Quantity, BalanceAfter = line.Product.StockQuantity, Reason = "Order cancellation", ReferenceType = "Order", ReferenceId = id });
                }
                await _dbContext.SaveChangesAsync();
            }
            if (updated != null && !string.Equals(previousStatus, updated.Status, StringComparison.OrdinalIgnoreCase))
            {
                if (updated.Status.Equals("Delivered", StringComparison.OrdinalIgnoreCase))
                {
                    var entity = await _dbContext.Orders.FindAsync(id);
                    if (entity != null && entity.DeliveredAt is null) { entity.DeliveredAt = DateTime.UtcNow; await _dbContext.SaveChangesAsync(); updated.DeliveredAt = entity.DeliveredAt; }
                }
                await _notificationService.CreateAsync(new NotificationInsertRequest
                {
                    Title = "Order status updated",
                    Message = $"Order {updated.OrderNumber} is now {updated.Status.ToLowerInvariant()}.",
                    Type = "Orders",
                    RecipientUserIds = new List<int> { updated.UserId }
                });
            }
            await transaction.CommitAsync();
            return updated;
        }

        protected override IQueryable<DbOrder> ApplyFilter(IQueryable<DbOrder> query, OrderSearchObject search)
        {
            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.OrderNumber))
            {
                query = query.Where(x => x.OrderNumber.Contains(search.OrderNumber));
            }

            if (!string.IsNullOrWhiteSpace(search.Status))
            {
                query = query.Where(x => x.Status.Contains(search.Status));
            }

            if (search.CreatedFrom.HasValue)
            {
                query = query.Where(x => x.CreatedAt >= search.CreatedFrom.Value);
            }

            if (search.CreatedTo.HasValue)
            {
                query = query.Where(x => x.CreatedAt <= search.CreatedTo.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.OrderNumber.Contains(search.FTS) ||
                    x.Status.Contains(search.FTS) ||
                    x.ShippingAddress.Contains(search.FTS) ||
                    (x.Notes != null && x.Notes.Contains(search.FTS)));
            }

            return base.ApplyFilter(query, search);
        }
    }
}
