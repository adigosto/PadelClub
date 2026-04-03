using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbMatchParticipant = PadelClub.Services.Database.MatchParticipant;

namespace PadelClub.Services
{
    public class MatchParticipantService : BaseCRUDService<MatchParticipantResponse, MatchParticipantSearchObject, DbMatchParticipant, MatchParticipantInsertRequest, MatchParticipantUpdateRequest>, IMatchParticipantService
    {
        public MatchParticipantService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        protected override IQueryable<DbMatchParticipant> ApplyFilter(IQueryable<DbMatchParticipant> query, MatchParticipantSearchObject search)
        {
            if (search.MatchId.HasValue)
            {
                query = query.Where(x => x.MatchId == search.MatchId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (search.TeamNumber.HasValue)
            {
                query = query.Where(x => x.TeamNumber == search.TeamNumber.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.Role))
            {
                query = query.Where(x => x.Role.Contains(search.Role));
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                if (int.TryParse(search.FTS, out var numericFts))
                {
                    query = query.Where(x =>
                        x.Role.Contains(search.FTS) ||
                        x.MatchId == numericFts ||
                        x.UserId == numericFts ||
                        x.TeamNumber == numericFts);
                }
                else
                {
                    query = query.Where(x => x.Role.Contains(search.FTS));
                }
            }

            return base.ApplyFilter(query, search);
        }
    }
}
