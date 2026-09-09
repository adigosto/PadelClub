using Microsoft.AspNetCore.Authorization;
using PadelClub.Services.Recommendations;
using PadelClub.WebAPI.Controllers;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class ProductRecommendationTests
{
    private static readonly DateTime Now = new(2026, 8, 26, 12, 0, 0, DateTimeKind.Utc);

    [Fact]
    public void Item_based_collaborative_filter_ranks_the_strongest_peer_purchase_pair_first()
    {
        var signals = new[]
        {
            new PurchaseSignal(1, 10, 1, Now),
            new PurchaseSignal(2, 10, 1, Now), new PurchaseSignal(2, 20, 1, Now),
            new PurchaseSignal(3, 10, 1, Now), new PurchaseSignal(3, 20, 1, Now),
            new PurchaseSignal(4, 10, 1, Now), new PurchaseSignal(4, 30, 1, Now)
        };

        var ranked = ItemBasedCollaborativeRanker.Rank(
            targetUserId: 1,
            signals,
            [new RecommendationCandidate(10), new RecommendationCandidate(20), new RecommendationCandidate(30)],
            Now);

        Assert.Collection(
            ranked,
            first =>
            {
                Assert.Equal(20, first.ProductId);
                Assert.Equal(10, first.BecauseProductId);
                Assert.Equal(2, first.SupportingCustomers);
            },
            second => Assert.Equal(30, second.ProductId));
        Assert.True(ranked[0].Score > ranked[1].Score);
    }

    [Fact]
    public void Item_based_collaborative_filter_never_recommends_an_already_owned_product()
    {
        var signals = new[]
        {
            new PurchaseSignal(1, 10, 1, Now), new PurchaseSignal(1, 20, 1, Now),
            new PurchaseSignal(2, 10, 1, Now), new PurchaseSignal(2, 30, 1, Now),
            new PurchaseSignal(3, 20, 1, Now), new PurchaseSignal(3, 30, 1, Now)
        };

        var ranked = ItemBasedCollaborativeRanker.Rank(
            targetUserId: 1,
            signals,
            [new RecommendationCandidate(10), new RecommendationCandidate(20), new RecommendationCandidate(30)],
            Now);

        var recommendation = Assert.Single(ranked);
        Assert.Equal(30, recommendation.ProductId);
    }

    [Fact]
    public void Prepared_ranker_matches_the_player_ranker_for_a_fixed_snapshot()
    {
        var signals = new[]
        {
            new PurchaseSignal(1, 10, 1, Now),
            new PurchaseSignal(2, 10, 1, Now), new PurchaseSignal(2, 20, 1, Now),
            new PurchaseSignal(3, 10, 1, Now), new PurchaseSignal(3, 30, 1, Now),
            new PurchaseSignal(4, 20, 1, Now), new PurchaseSignal(4, 30, 1, Now)
        };
        var candidates = new[]
        {
            new RecommendationCandidate(10),
            new RecommendationCandidate(20),
            new RecommendationCandidate(30)
        };

        var online = ItemBasedCollaborativeRanker.Rank(1, signals, candidates, Now);
        var prepared = ItemBasedCollaborativeRanker.Prepare(signals, Now)
            .Rank(1, candidates);

        Assert.Equal(online.Select(x => x.ProductId), prepared.Select(x => x.ProductId));
        Assert.Equal(
            online.Select(x => x.BecauseProductId),
            prepared.Select(x => x.BecauseProductId));
        Assert.Equal(
            online.Select(x => x.SupportingCustomers),
            prepared.Select(x => x.SupportingCustomers));

        foreach (var (onlineScore, preparedScore) in online
                     .Select(x => x.Score)
                     .Zip(prepared.Select(x => x.Score)))
        {
            Assert.Equal(onlineScore, preparedScore, precision: 12);
        }
    }

    [Fact]
    public void Zero_or_fully_returned_purchase_signals_do_not_create_a_recommendation()
    {
        var signals = new[]
        {
            new PurchaseSignal(1, 10, 0, Now),
            new PurchaseSignal(2, 10, 1, Now), new PurchaseSignal(2, 20, 1, Now)
        };

        var ranked = ItemBasedCollaborativeRanker.Rank(
            targetUserId: 1,
            signals,
            [new RecommendationCandidate(20)],
            Now);

        Assert.Empty(ranked);
    }

    [Fact]
    public void Product_recommendation_endpoint_requires_authentication() =>
        Assert.NotEmpty(typeof(RecommendationsController).GetCustomAttributes(typeof(AuthorizeAttribute), true));
}
