using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;

namespace PadelClub.WebAPI.Controllers
{
    [Authorize(Policy = "AdminOnly")]
    public class TournamentParticipantsController : BaseCRUDController<TournamentParticipantResponse, TournamentParticipantSearchObject, TournamentParticipantInsertRequest, TournamentParticipantUpdateRequest>
    {
        public TournamentParticipantsController(ITournamentParticipantService service) : base(service)
        {
        }
    }
}
