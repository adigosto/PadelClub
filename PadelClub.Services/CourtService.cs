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
using Court = PadelClub.Services.Database.Court;

namespace PadelClub.Services
{
    public class CourtService : BaseCRUDService<CourtResponse, CourtSearchObject, Court, CourtInsertRequest, CourtUpdateRequest>, ICourtService
    {

        public CourtService(PadelClubContext dbContext, IMapper mapper) : base(dbContext, mapper)
        {
            
        }

        protected override IQueryable<Court> ApplyFilter(IQueryable<Court> query, CourtSearchObject search)
        {
            if (!string.IsNullOrWhiteSpace(search.Name))
            {
                query = query.Where(x => x.Name.Contains(search.Name));
            }

            if (search.IsIndoor.HasValue)
            {
                query = query.Where(x => x.IsIndoor == search.IsIndoor.Value);
            }

            if (search.IsActive.HasValue)
            {
                query = query.Where(x => x.IsActive == search.IsActive.Value);
            }

            if (!string.IsNullOrWhiteSpace(search.FTS))
            {
                query = query.Where(x =>
                    x.Name.Contains(search.FTS) ||
                    x.Description.Contains(search.FTS));
            }

            return base.ApplyFilter(query, search);
        }

    }
}

