using MapsterMapper;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using DbTournamentParticipant = PadelClub.Services.Database.TournamentParticipant;

namespace PadelClub.Services
{
    public class TournamentParticipantService : BaseCRUDService<TournamentParticipantResponse, TournamentParticipantSearchObject, DbTournamentParticipant, TournamentParticipantInsertRequest, TournamentParticipantUpdateRequest>, ITournamentParticipantService
    {
        public TournamentParticipantService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
        }

        protected override IQueryable<DbTournamentParticipant> ApplyFilter(IQueryable<DbTournamentParticipant> query, TournamentParticipantSearchObject search)
        {
            if (search.TournamentId.HasValue)
            {
                query = query.Where(x => x.TournamentId == search.TournamentId.Value);
            }

            if (search.UserId.HasValue)
            {
                query = query.Where(x => x.UserId == search.UserId.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.Status))
            {
                query = query.Where(x => x.Status.Contains(search.Status));
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x => x.Status.Contains(search.FTS));
            }

            return base.ApplyFilter(query, search);
        }
    }
}
