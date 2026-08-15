using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;
using Microsoft.AspNetCore.Authorization;

namespace PadelClub.WebAPI.Controllers
{
    public class TournamentController : BaseCRUDController<TournamentResponse, TournamentSearchObject, TournamentInsertRequest, TournamentUpdateRequest>
    {
        public TournamentController(ITournamentService service) : base(service)
        {
        }
        [HttpPost, Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<TournamentResponse>> Create([FromBody] TournamentInsertRequest request) => base.Create(request);
        [HttpPut("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<TournamentResponse?>> Update(int id, [FromBody] TournamentUpdateRequest request) => base.Update(id, request);
        [HttpDelete("{id:int}"), Authorize(Policy = "AdminOnly")]
        public override Task<ActionResult<bool>> Delete(int id) => base.Delete(id);
    }
}
