using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    public class TournamentController : BaseCRUDController<TournamentResponse, TournamentSearchObject, TournamentInsertRequest, TournamentUpdateRequest>
    {
        public TournamentController(ITournamentService service) : base(service)
        {
        }
    }
}
