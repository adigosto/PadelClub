using PadelClub.Model.Responses;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.IService;

namespace PadelClub.Services
{
    public interface IClubReviewService : IService<ClubReviewResponse, ClubReviewSearchObject>
    {
        Task<ClubReviewResponse?> GetForUserAsync(int userId);
        Task<ClubReviewResponse> UpsertForUserAsync(int userId, ClubReviewRequest request);
    }
}
