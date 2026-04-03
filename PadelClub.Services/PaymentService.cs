using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbPayment = PadelClub.Services.Database.Payment;

namespace PadelClub.Services
{
    public class PaymentService : BaseCRUDService<PaymentResponse, PaymentSearchObject, DbPayment, PaymentInsertRequest, PaymentUpdateRequest>, IPaymentService
    {
        public PaymentService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
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
