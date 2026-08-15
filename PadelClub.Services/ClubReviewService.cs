using MapsterMapper;
using Microsoft.EntityFrameworkCore;
using PadelClub.Model.Responses;
using PadelClub.Model.Requests;
using PadelClub.Model.SearchObjects;
using PadelClub.Services.Database;

namespace PadelClub.Services
{
    public class ClubReviewService : BaseService<ClubReviewResponse, ClubReviewSearchObject, ClubReview>, IClubReviewService
    {
        private readonly PadelClubContext _context;

        public ClubReviewService(PadelClubContext context, IMapper mapper) : base(context, mapper)
        {
            _context = context;
        }

        public override async Task<PagedResult<ClubReviewResponse>> GetAsync(ClubReviewSearchObject search)
        {
            IQueryable<ClubReview> query = _context.ClubReviews
                .AsNoTracking()
                .Include(x => x.User)
                .Where(x => x.IsPublished);

            var totalCount = search.IncludeTotalCount ? await query.CountAsync() : (int?)null;
            var page = Math.Max(search.Page.GetValueOrDefault(1), 1);
            var pageSize = search.PageSize.GetValueOrDefault(10);
            query = query.OrderByDescending(x => x.CreatedAt);
            if (pageSize > 0)
                query = query.Skip((page - 1) * pageSize).Take(pageSize);

            var items = await query.ToListAsync();
            return new PagedResult<ClubReviewResponse>
            {
                Items = items.Select(MapReview).ToList(),
                TotalCount = totalCount
            };
        }

        public override async Task<ClubReviewResponse?> GetByIdAsync(int id)
        {
            var review = await _context.ClubReviews.AsNoTracking()
                .Include(x => x.User)
                .FirstOrDefaultAsync(x => x.Id == id && x.IsPublished);
            return review == null ? null : MapReview(review);
        }

        public async Task<ClubReviewResponse?> GetForUserAsync(int userId)
        {
            var review = await _context.ClubReviews.AsNoTracking()
                .Include(x => x.User)
                .FirstOrDefaultAsync(x => x.UserId == userId);
            return review == null ? null : MapReview(review);
        }

        public async Task<ClubReviewResponse> UpsertForUserAsync(int userId, ClubReviewRequest request)
        {
            var comment = request.Comment.Trim();
            if (request.Rating is < 1 or > 5)
                throw new InvalidOperationException("Rating must be between 1 and 5.");
            if (comment.Length is < 10 or > 600)
                throw new InvalidOperationException("Review must contain between 10 and 600 characters.");

            var review = await _context.ClubReviews
                .Include(x => x.User)
                .FirstOrDefaultAsync(x => x.UserId == userId);
            if (review == null)
            {
                review = new ClubReview
                {
                    UserId = userId,
                    Rating = request.Rating,
                    Comment = comment,
                    IsPublished = true
                };
                _context.ClubReviews.Add(review);
            }
            else
            {
                review.Rating = request.Rating;
                review.Comment = comment;
                review.IsPublished = true;
                review.UpdatedAt = DateTime.UtcNow;
            }

            await _context.SaveChangesAsync();
            await _context.Entry(review).Reference(x => x.User).LoadAsync();
            return MapReview(review);
        }

        private static ClubReviewResponse MapReview(ClubReview review) => new()
        {
            Id = review.Id,
            UserId = review.UserId,
            MemberName = $"{review.User.FirstName} {review.User.LastName}".Trim(),
            Rating = review.Rating,
            Comment = review.Comment,
            CreatedAt = review.CreatedAt
        };
    }
}
