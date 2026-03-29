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

    }
}

