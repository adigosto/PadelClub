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

        public override Task<PaymentResponse> CreateAsync(PaymentInsertRequest request) =>
            throw new InvalidOperationException("Payments must be initiated and verified through the payment provider workflow.");

        public override Task<PaymentResponse?> UpdateAsync(int id, PaymentUpdateRequest request) =>
            throw new InvalidOperationException("Payment amounts, references and settlement status cannot be edited manually.");

        public override Task<bool> DeleteAsync(int id) =>
            throw new InvalidOperationException("Payment history cannot be deleted. Use the refund workflow.");

        protected override PaymentResponse MapToResponse(DbPayment entity)
        {
            var response = base.MapToResponse(entity);
            response.ReferenceDescription = entity.Reservation is not null
                ? entity.Reservation.Court.Name
                : entity.Order?.OrderNumber ?? entity.Membership?.MembershipType ?? entity.PaymentType;
            return response;
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

            return base.ApplyFilter(query.Include(x => x.Reservation).ThenInclude(x => x!.Court).Include(x => x.Membership).Include(x => x.Order), search);
        }
    }
}
