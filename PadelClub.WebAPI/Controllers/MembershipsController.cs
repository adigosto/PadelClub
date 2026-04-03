using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    public class MembershipsController : BaseCRUDController<MembershipResponse, MembershipSearchObject, MembershipInsertRequest, MembershipUpdateRequest>
    {
        public MembershipsController(IMembershipService service) : base(service)
        {
        }
    }
}
