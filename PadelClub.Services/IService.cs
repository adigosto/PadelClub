using PadelClub.Model.Responses;
using PadelClub.Model.SearchObjects;

namespace PadelClub.Services.IService
{
    public interface IService<T, TSearch> where T : class where TSearch : BaseSearchObject
    {
        Task<PagedResult<T>> GetAsync(TSearch search);
        Task<T?> GetByIdAsync(int id);
    }
}