using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Model.Responses;
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

        public override Task<bool> DeleteAsync(int id) =>
            throw new InvalidOperationException("Membership history cannot be deleted. Use the cancellation workflow.");

        public override Task<MembershipResponse?> UpdateAsync(int id, MembershipUpdateRequest request) =>
            throw new InvalidOperationException("Memberships can only be changed through the lifecycle workflow.");

        public Task<List<MembershipTypeReferenceResponse>> GetTypeReferencesAsync(CancellationToken cancellationToken) =>
            _dbContext.MembershipTypeReferences.AsNoTracking()
                .Where(x => x.IsActive)
                .OrderBy(x => x.Name)
                .Select(x => new MembershipTypeReferenceResponse { Id = x.Id, Name = x.Name, IsActive = x.IsActive })
                .ToListAsync(cancellationToken);

        protected override async Task BeforeInsert(DbMembership entity, MembershipInsertRequest request)
        {
            var typeName = request.MembershipType.Trim();
            var reference = request.MembershipTypeReferenceId.HasValue
                ? await _dbContext.MembershipTypeReferences.SingleOrDefaultAsync(
                    x => x.Id == request.MembershipTypeReferenceId.Value && x.IsActive)
                : await _dbContext.MembershipTypeReferences.SingleOrDefaultAsync(
                    x => x.IsActive && x.Name == typeName);
            if (reference is null)
                throw new InvalidOperationException("Membership type must be selected from the configured reference list.");

            entity.MembershipType = reference.Name;
            entity.MembershipTypeReferenceId = reference.Id;
        }

        protected override IQueryable<DbMembership> ApplyFilter(IQueryable<DbMembership> query, MembershipSearchObject search)
        {
            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.MembershipTypeReferenceId.HasValue)
            {
                query = query.Where(x => x.MembershipTypeReferenceId == search.MembershipTypeReferenceId.Value);
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
