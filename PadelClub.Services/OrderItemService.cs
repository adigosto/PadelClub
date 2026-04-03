using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbOrderItem = PadelClub.Services.Database.OrderItem;

namespace PadelClub.Services
{
    public class OrderItemService : BaseCRUDService<OrderItemResponse, OrderItemSearchObject, DbOrderItem, OrderItemInsertRequest, OrderItemUpdateRequest>, IOrderItemService
    {
        public OrderItemService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        protected override IQueryable<DbOrderItem> ApplyFilter(IQueryable<DbOrderItem> query, OrderItemSearchObject search)
        {
            if (search.OrderId.HasValue)
            {
                query = query.Where(x => x.OrderId == search.OrderId.Value);
            }

            if (search.ProductId.HasValue)
            {
                query = query.Where(x => x.ProductId == search.ProductId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS) && int.TryParse(search.FTS, out var numericFts))
            {
                query = query.Where(x => x.OrderId == numericFts || x.ProductId == numericFts);
            }

            return base.ApplyFilter(query, search);
        }
    }
}
