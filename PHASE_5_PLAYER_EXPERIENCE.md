# Phase 5: player experience

Phase 5 adds player onboarding, partner discovery, trustworthy match results, ratings, and personal match history.

## Included

- Player profiles with skill level, preferred side, location, bio, availability, and discoverability.
- Partner search with skill, city, and name filters.
- Partner invitations with accept/decline workflow and notifications.
- Personal match history.
- Two-party match result confirmation: the reporting player cannot confirm their own score.
- Padel score validation.
- Elo-style ratings updated atomically after confirmation.
- Rankings ordered by rating with wins, matches played, and win rate.

## Test in Swagger

Run `docker compose up -d --build`, open `http://localhost:5000/swagger`, and authenticate as a verified player.

Suggested flow:

1. `PUT /PlayerExperience/profile/mine`
2. `GET /PlayerExperience/partners`
3. `POST /PlayerExperience/partners/{recipientUserId}/invite`
4. Sign in as the recipient and call `PUT /PlayerExperience/invitations/{id}/respond`.
5. As a participant, call `POST /PlayerExperience/matches/{matchId}/result`.
6. Sign in as another participant and call `POST /PlayerExperience/matches/{matchId}/confirm`.
7. Inspect `GET /PlayerExperience/matches/mine` and `GET /Discovery/rankings`.

Example profile:

```json
{
  "skillLevel": "Intermediate",
  "preferredSide": "Right",
  "city": "Sarajevo",
  "bio": "Looking for competitive evening games.",
  "availability": "Weekdays after 18:00",
  "isDiscoverable": true
}
```

Example result:

```json
{ "score": "6-4, 3-6, 10-7", "winnerTeamId": 1 }
```

Migration: `AddPlayerExperience`.
