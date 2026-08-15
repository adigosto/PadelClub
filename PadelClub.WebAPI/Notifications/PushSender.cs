using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;
using Microsoft.Extensions.Options;
using System.Text;

namespace PadelClub.WebAPI.Notifications;

public interface IPushSender
{
    Task<string?> SendAsync(string installationId, string title, string body, IReadOnlyDictionary<string, string> data, CancellationToken cancellationToken);
}

public sealed class FirebasePushSender : IPushSender
{
    private readonly FirebaseMessaging? _messaging;

    public FirebasePushSender(IOptions<NotificationDeliveryOptions> options, ILogger<FirebasePushSender> logger)
    {
        var projectId = options.Value.FirebaseProjectId;
        if (string.IsNullOrWhiteSpace(projectId))
        {
            logger.LogInformation("Firebase push delivery is disabled because Notifications:FirebaseProjectId is empty.");
            return;
        }

        GoogleCredential credential;
        if (string.IsNullOrWhiteSpace(options.Value.FirebaseServiceAccountJson))
        {
            credential = GoogleCredential.GetApplicationDefault();
        }
        else
        {
            using var json = new MemoryStream(Encoding.UTF8.GetBytes(options.Value.FirebaseServiceAccountJson));
            credential = ServiceAccountCredential.FromServiceAccountData(json).ToGoogleCredential();
        }
        var app = FirebaseApp.DefaultInstance ?? FirebaseApp.Create(new AppOptions
        {
            Credential = credential, ProjectId = projectId
        });
        _messaging = FirebaseMessaging.GetMessaging(app);
    }

    public Task<string?> SendAsync(string installationId, string title, string body, IReadOnlyDictionary<string, string> data, CancellationToken cancellationToken)
    {
        if (_messaging is null) throw new InvalidOperationException("Firebase push delivery is not configured.");
        var message = new Message
        {
            Fid = installationId,
            Notification = new FirebaseAdmin.Messaging.Notification { Title = title, Body = body },
            Data = new Dictionary<string, string>(data)
        };
        return _messaging.SendAsync(message, cancellationToken);
    }
}
