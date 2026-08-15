using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;

namespace PadelClub.WebAPI.Controllers
{
    [Authorize(Policy = "AdminOnly")]
    public class MatchParticipantsController : BaseCRUDController<MatchParticipantResponse, MatchParticipantSearchObject, MatchParticipantInsertRequest, MatchParticipantUpdateRequest>
    {
        public MatchParticipantsController(IMatchParticipantService service) : base(service)
        {
        }
    }
}
