using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbRole = PadelClub.Services.Database.Role;

namespace PadelClub.Services
{
    public class RoleService : BaseCRUDService<RoleResponse, RoleSearchObject, DbRole, RoleInsertRequest, RoleUpdateRequest>, IRoleService
    {
        public RoleService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        protected override IQueryable<DbRole> ApplyFilter(IQueryable<DbRole> query, RoleSearchObject search)
        {
            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                query = query.Where(x => x.Name.Contains(search.Name));
            }

            if (search.IsActive.HasValue)
            {
                query = query.Where(x => x.IsActive == search.IsActive.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.Name.Contains(search.FTS) ||
                    (x.Description != null && x.Description.Contains(search.FTS)));
            }

            return base.ApplyFilter(query, search);
        }
    }
}
