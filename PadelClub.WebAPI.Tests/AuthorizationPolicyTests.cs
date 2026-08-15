using System.Reflection;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using PadelClub.WebAPI.Controllers;
using Xunit;

namespace PadelClub.WebAPI.Tests;

public class AuthorizationPolicyTests
{
    private static readonly Type[] AdminManagedControllers =
    [
        typeof(CourtsController), typeof(MatchParticipantsController), typeof(MembershipsController),
        typeof(NotificationsController), typeof(OrderItemsController), typeof(OrdersController),
        typeof(PaymentsController), typeof(ProductCategoriesController), typeof(ProductController),
        typeof(ProductTypesController), typeof(ReservationsController), typeof(RolesController),
        typeof(TournamentController), typeof(TournamentParticipantsController), typeof(UsersController), typeof(StripePaymentsController)
        , typeof(NotificationSettingsController), typeof(TournamentLifecycleController), typeof(CommerceOperationsController)
    ];

    [Fact]
    public void Every_admin_managed_mutation_requires_admin_policy()
    {
        foreach (var controller in AdminManagedControllers)
        foreach (var method in controller.GetMethods(BindingFlags.Instance | BindingFlags.Public | BindingFlags.DeclaredOnly))
        {
            var mutates = method.GetCustomAttributes().Any(x => x is HttpPostAttribute or HttpPutAttribute or HttpDeleteAttribute);
            if (!mutates || IsPlayerSelfService(method)) continue;
            var policies = controller.GetCustomAttributes<AuthorizeAttribute>().Concat(method.GetCustomAttributes<AuthorizeAttribute>());
            Assert.Contains(policies, x => x.Policy == "AdminOnly");
        }
    }

    private static bool IsPlayerSelfService(MethodInfo method) =>
        (method.DeclaringType == typeof(ReservationsController) && method.Name == "Create") || method.Name is
        "Checkout" or "Cancel" or "SaveMine" or "MarkRead" or "MarkAllRead" or
        "CreateRecurring" or "JoinWaitlist" or "CreateIntent" or "Webhook" or
        "RegisterDevice" or "UnregisterDevice" or
        "CancelAtPeriodEnd" or "AutoRenew" or
        "Register" or "Respond" or "Withdraw" or
        "RequestReturn" or
        "Logout" or "RequestEmailVerification" or "UpdateMe" or "Login" or "Refresh" or
        "ForgotPassword" or "ResetPassword" or "VerifyEmail";
}
