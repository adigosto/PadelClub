using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbPayment = PadelClub.Services.Database.Payment;

namespace PadelClub.Services
{
    public class PaymentService : BaseCRUDService<PaymentResponse, PaymentSearchObject, DbPayment, PaymentInsertRequest, PaymentUpdateRequest>, IPaymentService
    {
        private readonly INotificationService _notificationService;

        public PaymentService(PadelClubContext dbContext, IMapper mapper, INotificationService notificationService) : base(dbContext, mapper)
        {
            _notificationService = notificationService;
        }

        public override async Task<PaymentResponse> CreateAsync(PaymentInsertRequest request)
        {
            var created = await base.CreateAsync(request);
            await NotifyPaymentAsync(created, "Payment received");
            return created;
        }

        public override async Task<PaymentResponse?> UpdateAsync(int id, PaymentUpdateRequest request)
        {
            var previousStatus = await _dbContext.Payments
                .Where(x => x.Id == id)
                .Select(x => x.Status)
                .FirstOrDefaultAsync();
            var updated = await base.UpdateAsync(id, request);
            if (updated != null && !string.Equals(previousStatus, updated.Status, StringComparison.OrdinalIgnoreCase))
                await NotifyPaymentAsync(updated, "Payment status updated");
            return updated;
        }

        private Task<NotificationResponse> NotifyPaymentAsync(PaymentResponse payment, string title)
        {
            return _notificationService.CreateAsync(new NotificationInsertRequest
            {
                Title = title,
                Message = $"Your {payment.Amount:F2} KM payment is {payment.Status.ToLowerInvariant()}.",
                Type = "Payments",
                RecipientUserIds = new List<int> { payment.UserId }
            });
        }

        protected override IQueryable<DbPayment> ApplyFilter(IQueryable<DbPayment> query, PaymentSearchObject search)
        {
            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.PaymentType))
            {
                query = query.Where(x => x.PaymentType.Contains(search.PaymentType));
            }

            if (search.ReservationId.HasValue)
            {
                query = query.Where(x => x.ReservationId == search.ReservationId.Value);
            }

            if (search.MembershipId.HasValue)
            {
                query = query.Where(x => x.MembershipId == search.MembershipId.Value);
            }

            if (search.OrderId.HasValue)
            {
                query = query.Where(x => x.OrderId == search.OrderId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.PaymentMethod))
            {
                query = query.Where(x => x.PaymentMethod.Contains(search.PaymentMethod));
            }

            if (!string.IsNullOrWhiteSpace(search.Status))
            {
                query = query.Where(x => x.Status.Contains(search.Status));
            }

            if (!string.IsNullOrWhiteSpace(search.TransactionId))
            {
                query = query.Where(x => x.TransactionId != null && x.TransactionId.Contains(search.TransactionId));
            }

            if (search.PaymentDateFrom.HasValue)
            {
                query = query.Where(x => x.PaymentDate >= search.PaymentDateFrom.Value);
            }

            if (search.PaymentDateTo.HasValue)
            {
                query = query.Where(x => x.PaymentDate <= search.PaymentDateTo.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.PaymentType.Contains(search.FTS) ||
                    x.PaymentMethod.Contains(search.FTS) ||
                    x.Status.Contains(search.FTS) ||
                    (x.TransactionId != null && x.TransactionId.Contains(search.FTS)));
            }

            return base.ApplyFilter(query, search);
        }
    }
}
