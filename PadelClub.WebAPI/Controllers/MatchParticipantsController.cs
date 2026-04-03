using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    public class MatchParticipantsController : BaseCRUDController<MatchParticipantResponse, MatchParticipantSearchObject, MatchParticipantInsertRequest, MatchParticipantUpdateRequest>
    {
        public MatchParticipantsController(IMatchParticipantService service) : base(service)
        {
        }
    }
}
