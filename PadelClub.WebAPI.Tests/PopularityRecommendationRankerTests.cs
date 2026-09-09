using PadelClub.Services.Recommendations;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class PopularityRecommendationRankerTests
{
    private static readonly DateTime Now = new(2026, 9, 6, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Ranks_by_distinct_buyer_count_not_quantity_or_repeat_purchase_lines()
    {
        var ranked = PopularityRecommendationRanker.Rank(
            targetUserId: 1,
            purchaseSignals:
            [
                new PurchaseSignal(1, 10, 5, Now),
                new PurchaseSignal(2, 20, 50, Now),
                new PurchaseSignal(2, 20, 1, Now),
                new PurchaseSignal(3, 20, 1, Now),
                new PurchaseSignal(4, 30, 1, Now),
                new PurchaseSignal(5, 30, 1, Now),
                new PurchaseSignal(6, 30, 1, Now),
                new PurchaseSignal(7, 40, 1, Now)
            ],
            candidates:
            [
                new RecommendationCandidate(10),
                new RecommendationCandidate(20),
                new RecommendationCandidate(30),
                new RecommendationCandidate(40)
            ]);

        Assert.Collection(
            ranked,
            first =>
            {
                Assert.Equal(30, first.ProductId);
                Assert.Equal(3d, first.Score);
                Assert.Equal(3, first.SupportingCustomers);
            },
            second =>
            {
                Assert.Equal(20, second.ProductId);
                Assert.Equal(2d, second.Score);
                Assert.Equal(2, second.SupportingCustomers);
            },
            third => Assert.Equal(40, third.ProductId));
        Assert.DoesNotContain(ranked, score => score.ProductId == 10);
    }

    [Fact]
    public void Uses_product_id_as_a_stable_tie_breaker_and_retains_zero_support_candidates()
    {
        var ranked = PopularityRecommendationRanker.Rank(
            targetUserId: 1,
            purchaseSignals:
            [
                new PurchaseSignal(3, 30, 1, Now),
                new PurchaseSignal(2, 20, 1, Now),
                new PurchaseSignal(5, 20, 1, Now),
                new PurchaseSignal(4, 30, 1, Now)
            ],
            candidates:
            [
                new RecommendationCandidate(40),
                new RecommendationCandidate(30),
                new RecommendationCandidate(20),
                new RecommendationCandidate(30),
                new RecommendationCandidate(0),
                new RecommendationCandidate(-1)
            ]);

        Assert.Equal([20, 30, 40], ranked.Select(score => score.ProductId));
        Assert.Equal([2, 2, 0], ranked.Select(score => score.SupportingCustomers));
        Assert.Equal(0d, ranked[2].Score);
    }

    [Fact]
    public void Ignores_non_retained_signals_for_support_and_target_ownership()
    {
        var ranked = PopularityRecommendationRanker.Rank(
            targetUserId: 1,
            purchaseSignals:
            [
                new PurchaseSignal(1, 10, 0, Now),
                new PurchaseSignal(1, 20, 1, Now),
                new PurchaseSignal(2, 10, 1, Now),
                new PurchaseSignal(0, 10, 9, Now),
                new PurchaseSignal(3, 10, 0, Now),
                new PurchaseSignal(2, 30, -1, Now)
            ],
            candidates:
            [
                new RecommendationCandidate(10),
                new RecommendationCandidate(20),
                new RecommendationCandidate(30)
            ]);

        Assert.Collection(
            ranked,
            recommendation =>
            {
                Assert.Equal(10, recommendation.ProductId);
                Assert.Equal(1d, recommendation.Score);
                Assert.Equal(1, recommendation.SupportingCustomers);
            },
            zeroSupport =>
            {
                Assert.Equal(30, zeroSupport.ProductId);
                Assert.Equal(0d, zeroSupport.Score);
                Assert.Equal(0, zeroSupport.SupportingCustomers);
            });
    }
}
