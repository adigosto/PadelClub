using Microsoft.AspNetCore.Mvc;
using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services;

namespace PadelClub.WebAPI.Controllers
{
    
    public class CourtsController : BaseCRUDController<CourtResponse, CourtSearchObject, CourtInsertRequest, CourtUpdateRequest>
    {
        public CourtsController(ICourtService service) : base(service)
        {
        }
    }
        
}

