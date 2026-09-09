using PadelClub.Model;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Model.Responses;
using PadelClub.Services.IService;

namespace PadelClub.Services
{
    public interface IMembershipService : ICRUDService<MembershipResponse, MembershipSearchObject, MembershipInsertRequest, MembershipUpdateRequest>
    {
        Task<List<MembershipTypeReferenceResponse>> GetTypeReferencesAsync(CancellationToken cancellationToken);
    }
}
