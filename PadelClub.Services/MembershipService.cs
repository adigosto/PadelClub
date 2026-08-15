using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbMembership = PadelClub.Services.Database.Membership;
using Microsoft.EntityFrameworkCore;

namespace PadelClub.Services
{
    public class MembershipService : BaseCRUDService<MembershipResponse, MembershipSearchObject, DbMembership, MembershipInsertRequest, MembershipUpdateRequest>, IMembershipService
    {
        public MembershipService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        public override async Task<MembershipResponse> CreateAsync(MembershipInsertRequest request)
        {
            if (request.EndDate <= request.StartDate) throw new InvalidOperationException("Membership end date must be after its start date.");
            if (request.Price < 0) throw new InvalidOperationException("Membership price cannot be negative.");
            var overlaps = await _dbContext.Memberships.AnyAsync(x => x.UserId == request.UserId && x.Status == "Active" && x.EndDate > request.StartDate && x.StartDate < request.EndDate);
            if (overlaps) throw new InvalidOperationException("This user already has an overlapping active membership.");
            var result = await base.CreateAsync(request);
            _dbContext.MembershipEvents.Add(new MembershipEvent { MembershipId = result.Id, EventType = "Created", Notes = "Membership created." });
            await _dbContext.SaveChangesAsync();
            return result;
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
