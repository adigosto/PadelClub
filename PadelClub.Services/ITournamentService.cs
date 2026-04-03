using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;
using PadelClub.Services.IService;
using System.Collections.Generic;
using System.Threading.Tasks;
using Tournament = PadelClub.Services.Database.Tournament;

namespace PadelClub.Services
{
    public interface ITournamentService : ICRUDService<TournamentResponse, TournamentSearchObject, TournamentInsertRequest, TournamentUpdateRequest>
    {
        
    }
}

