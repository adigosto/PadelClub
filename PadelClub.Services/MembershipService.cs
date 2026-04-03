using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbMembership = PadelClub.Services.Database.Membership;

namespace PadelClub.Services
{
    public class MembershipService : BaseCRUDService<MembershipResponse, MembershipSearchObject, DbMembership, MembershipInsertRequest, MembershipUpdateRequest>, IMembershipService
    {
        public MembershipService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        protected override IQueryable<DbMembership> ApplyFilter(IQueryable<DbMembership> query, MembershipSearchObject search)
        {
            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.MembershipType))
            {
                query = query.Where(x => x.MembershipType.Contains(search.MembershipType));
            }

            if (search.IsActive.HasValue)
            {
                query = query.Where(x => x.IsActive == search.IsActive.Value);
            }

            if (search.StartDateFrom.HasValue)
            {
                query = query.Where(x => x.StartDate >= search.StartDateFrom.Value);
            }

            if (search.StartDateTo.HasValue)
            {
                query = query.Where(x => x.StartDate <= search.StartDateTo.Value);
            }

            if (search.EndDateFrom.HasValue)
            {
                query = query.Where(x => x.EndDate >= search.EndDateFrom.Value);
            }

            if (search.EndDateTo.HasValue)
            {
                query = query.Where(x => x.EndDate <= search.EndDateTo.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x => x.MembershipType.Contains(search.FTS));
            }

            return base.ApplyFilter(query, search);
        }
    }
}
