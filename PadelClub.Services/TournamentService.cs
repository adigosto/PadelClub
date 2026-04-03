using Microsoft.EntityFrameworkCore;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System;
using System.Collections.Generic;
using System.Linq;
using System.Threading.Tasks;
using MapsterMapper;
using Tournament = PadelClub.Services.Database.Tournament;

namespace PadelClub.Services
{
    public class TournamentService : BaseCRUDService<TournamentResponse, TournamentSearchObject, Tournament, TournamentInsertRequest, TournamentUpdateRequest>, ITournamentService
    {

        public TournamentService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
            
        }

        protected override IQueryable<Tournament> ApplyFilter(IQueryable<Tournament> query, TournamentSearchObject search)
        {
            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                query = query.Where(x => x.Name.Contains(search.Name));
            }

            if (search.StartDate.HasValue)
            {
                query = query.Where(x => x.StartDate >= search.StartDate.Value);
            }

            if (search.EndDate.HasValue)
            {
                query = query.Where(x => x.EndDate <= search.EndDate.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.Name.Contains(search.FTS) ||
                    x.Description.Contains(search.FTS) ||
                    x.Status.Contains(search.FTS) ||
                    (x.PrizeInfo != null && x.PrizeInfo.Contains(search.FTS)));
            }

            return base.ApplyFilter(query, search);
        }

    }
}

