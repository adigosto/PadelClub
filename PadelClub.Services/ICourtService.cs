using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using PadelClub.Services.IService;
using System.Collections.Generic;
using System.Threading.Tasks;
using Court = PadelClub.Services.Database.Court;

namespace PadelClub.Services
{
    public interface ICourtService : ICRUDService<CourtResponse, CourtSearchObject, CourtInsertRequest, CourtUpdateRequest>
    {
        
    }
}

