using PadelClub.Model;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using System.Collections.Generic;
using System.Threading.Tasks;
using Court = PadelClub.Services.Database.Court;

namespace PadelClub.Services
{
    public interface ICourtService
    {
        Task<List<CourtResponse>> Get(CourtSearchObject? search);
        Task<CourtResponse?> GetById(int id);
        Task<CourtResponse> Create(CourtRequest request);
        Task<CourtResponse?> Update(int id, CourtRequest request);
        Task<bool> Delete(int id);
        CourtResponse? MapToResponse(Court court);
    }
}

