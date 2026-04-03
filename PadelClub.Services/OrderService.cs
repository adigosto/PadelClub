using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbOrder = PadelClub.Services.Database.Order;

namespace PadelClub.Services
{
    public class OrderService : BaseCRUDService<OrderResponse, OrderSearchObject, DbOrder, OrderInsertRequest, OrderUpdateRequest>, IOrderService
    {
        public OrderService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
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
