using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using PadelClub.Services.Recommendations;
using DbOrder = PadelClub.Services.Database.Order;

namespace PadelClub.Services
{
    public class OrderService : BaseCRUDService<OrderResponse, OrderSearchObject, DbOrder, OrderInsertRequest, OrderUpdateRequest>, IOrderService
    {
        private static readonly string[] FulfillmentStatuses =
        [
            "Pending",
            "Processing",
            "Shipped",
            "Delivered",
            "Cancelled"
        ];

        private readonly INotificationService _notificationService;
        private readonly IProductRecommendationService _recommendations;

        public OrderService(
            PadelClubContext dbContext,
            IMapper mapper,
            INotificationService notificationService,
            IProductRecommendationService recommendations) : base(dbContext, mapper)
        {
            _notificationService = notificationService;
            _recommendations = recommendations;
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

        public override Task<bool> DeleteAsync(int id) =>
            throw new InvalidOperationException("Order history cannot be deleted. Use the cancellation workflow.");

        protected override Task BeforeInsert(DbOrder entity, OrderInsertRequest request)
        {
            // The only public caller of generic order creation is the
            // administrator-only CRUD endpoint. It is intentionally never
            // treated as a customer-originated interaction in recommendation
            // evidence.
            entity.Origin = OrderOrigin.AdminCreated;
            entity.IsSeededForDemo = false;
            return Task.CompletedTask;
        }

        public async Task<OrderResponse> CheckoutAsync(int userId, CheckoutRequest request)
        {
            var idempotencyKey = request.IdempotencyKey.Trim();
            if (idempotencyKey.Length is < 8 or > 100)
                throw new InvalidOperationException("Idempotency key must contain between 8 and 100 characters.");

            var existingOrder = await _dbContext.Orders
                .AsNoTracking()
                .SingleOrDefaultAsync(x => x.UserId == userId && x.IdempotencyKey == idempotencyKey);
            if (existingOrder is not null)
                return _mapper.Map<OrderResponse>(existingOrder);

            var address = request.ShippingAddress.Trim();
            var recipientName = request.RecipientName.Trim();
            var phoneNumber = request.PhoneNumber.Trim();
            var city = request.City.Trim();
            var postalCode = request.PostalCode.Trim();
            if (recipientName.Length < 2)
                throw new InvalidOperationException("Recipient name must contain at least 2 characters.");
            if (phoneNumber.Length < 6)
                throw new InvalidOperationException("Phone number must contain at least 6 characters.");
            if (address.Length < 5)
                throw new InvalidOperationException("Street address must contain at least 5 characters.");
            if (city.Length < 2)
                throw new InvalidOperationException("City must contain at least 2 characters.");
            if (postalCode.Length < 3)
                throw new InvalidOperationException("Postal code must contain at least 3 characters.");
            if (request.Items.Count == 0)
                throw new InvalidOperationException("The cart is empty.");

            var requested = request.Items
                .GroupBy(x => x.ProductId)
                .ToDictionary(x => x.Key, x => x.Sum(line => line.Quantity));
            if (requested.Any(x => x.Key <= 0 || x.Value <= 0 || x.Value > 100))
                throw new InvalidOperationException("The cart contains an invalid quantity.");

            await using var transaction = await _dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);
            // Serialize checkouts for this customer across API instances. Lock an
            // existing row so competing requests cannot both claim a missing key.
            if (_dbContext.Database.IsSqlServer())
                await _dbContext.Users.FromSqlInterpolated(
                    $"SELECT * FROM [Users] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {userId}")
                    .AsNoTracking().SingleAsync();

            existingOrder = await _dbContext.Orders.AsNoTracking()
                .SingleOrDefaultAsync(x => x.UserId == userId && x.IdempotencyKey == idempotencyKey);
            if (existingOrder is not null)
            {
                await transaction.CommitAsync();
                return _mapper.Map<OrderResponse>(existingOrder);
            }

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
                IdempotencyKey = idempotencyKey,
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
                Origin = OrderOrigin.CustomerCheckout,
                IsSeededForDemo = false,
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
            var recommendationAttributions = request.Items
                .Where(line => line.RecommendationExposureId.HasValue)
                .Select(line => new RecommendationCheckoutAttribution(
                    line.RecommendationExposureId!.Value,
                    line.ProductId))
                .ToArray();
            await _recommendations.RecordCheckoutAttributionsAsync(
                userId,
                order.Id,
                recommendationAttributions);
            foreach (var product in products)
                _dbContext.InventoryMovements.Add(new InventoryMovement { ProductId = product.Id, QuantityChange = -requested[product.Id], BalanceAfter = product.StockQuantity, Reason = "Order checkout", ReferenceType = "Order", ReferenceId = order.Id, ActorUserId = userId });
            if (coupon is not null)
            {
                coupon.UsageCount++;
                _dbContext.CouponRedemptions.Add(new CouponRedemption { CouponId = coupon.Id, UserId = userId, OrderId = order.Id, DiscountAmount = discount });
            }
            await _dbContext.SaveChangesAsync();

            var response = _mapper.Map<OrderResponse>(order);
            await _notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = "Order received",
                Message = $"Order {response.OrderNumber} was received and is pending.",
                Type = "Orders",
                RecipientUserIds = new List<int> { userId }
            });
            await transaction.CommitAsync();
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
            ArgumentNullException.ThrowIfNull(request);

            await using var transaction = await _dbContext.Database.BeginTransactionAsync(System.Data.IsolationLevel.Serializable);

            // Claim the order before validating its state. SQL Server keeps this
            // update lock through the serializable transaction, so two staff
            // members cannot both accept a transition based on the same stale
            // status (or restore stock twice during cancellation).
            IQueryable<DbOrder> orders = _dbContext.Database.IsSqlServer()
                ? _dbContext.Orders.FromSqlInterpolated($"SELECT * FROM [Orders] WITH (UPDLOCK, HOLDLOCK) WHERE [Id] = {id}")
                : _dbContext.Orders.Where(x => x.Id == id);
            var entity = await orders.SingleOrDefaultAsync();
            if (entity is null)
                return null;

            var previousStatus = CanonicalExistingStatus(entity.Status);
            var nextStatus = CanonicalRequestedStatus(request.Status);
            if (!IsAllowedTransition(previousStatus, nextStatus))
                throw new InvalidOperationException(
                    "Orders must progress Pending → Processing → Shipped → Delivered. Cancellation is allowed only while pending or processing.");

            request.Status = nextStatus;
            var statusChanged = !string.Equals(previousStatus, nextStatus, StringComparison.Ordinal);
            entity.Status = nextStatus;
            entity.UpdatedAt = DateTime.UtcNow;
            await BeforeUpdate(entity, request);

            if (statusChanged && nextStatus == "Cancelled")
            {
                var lines = await _dbContext.OrderItems.Include(x => x.Product).Where(x => x.OrderId == id).ToListAsync();
                foreach (var line in lines)
                {
                    line.Product.StockQuantity += line.Quantity;
                    _dbContext.InventoryMovements.Add(new InventoryMovement { ProductId = line.ProductId, QuantityChange = line.Quantity, BalanceAfter = line.Product.StockQuantity, Reason = "Order cancellation", ReferenceType = "Order", ReferenceId = id });
                }
            }

            if (statusChanged && nextStatus == "Delivered" && entity.DeliveredAt is null)
            {
                // A delivery timestamp is a lifecycle fact, not a client field.
                // We only set it when staff actually transition to Delivered;
                // legacy delivered rows are deliberately not backfilled.
                entity.DeliveredAt = entity.UpdatedAt;
            }

            await _dbContext.SaveChangesAsync();
            var updated = MapToResponse(entity);

            if (statusChanged)
            {
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

        private static string CanonicalRequestedStatus(string? status)
        {
            var canonical = FulfillmentStatuses.FirstOrDefault(candidate =>
                string.Equals(candidate, status?.Trim(), StringComparison.OrdinalIgnoreCase));
            return canonical ?? throw new InvalidOperationException(
                "Order status must be Pending, Processing, Shipped, Delivered, or Cancelled.");
        }

        private static string CanonicalExistingStatus(string? status)
        {
            var canonical = FulfillmentStatuses.FirstOrDefault(candidate =>
                string.Equals(candidate, status, StringComparison.OrdinalIgnoreCase));
            return canonical ?? throw new InvalidOperationException(
                "This order has an unsupported status and cannot be changed through the fulfilment workflow.");
        }

        private static bool IsAllowedTransition(string current, string next) =>
            current == next || (current, next) switch
            {
                ("Pending", "Processing") => true,
                ("Pending", "Cancelled") => true,
                ("Processing", "Shipped") => true,
                ("Processing", "Cancelled") => true,
                ("Shipped", "Delivered") => true,
                _ => false
            };

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
