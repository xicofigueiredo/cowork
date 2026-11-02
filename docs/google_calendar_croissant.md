# Google Calendar bridge for Croissant (desks)

Croissant does not talk to this app directly. Both sides share one Google Calendar:

1. Croissant writes its desk/office bookings onto the calendar (partner portal).
2. This app polls that calendar and creates desk `Booking` rows.
3. Desk bookings created in this app are pushed back as calendar events so Croissant sees them as busy.

Meeting room bookings are not synced.

## Google Cloud / OAuth

1. Enable **Google Calendar API** for the same project as `GOOGLE_CLIENT_ID` / `GOOGLE_CLIENT_SECRET`.
2. In Credentials → your OAuth 2.0 Client, add these **Authorized redirect URIs**:
   - Local: `http://localhost:3000/admin/google_calendar/callback`
   - Production: `https://mezzaninecowork.com/admin/google_calendar/callback`
3. Create a dedicated Google Calendar (e.g. “Croissant Desks”) under `hello@mezzaninecowork.com`.
4. Copy the calendar ID from Calendar settings → Integrate calendar into `GOOGLE_CALENDAR_ID`.

Do **not** use the Postman callback (`oauth.pstmn.io`) — Google will return `redirect_uri_mismatch` unless that URI is registered, and the in-app callback is simpler.

## App env vars

```bash
GOOGLE_CLIENT_ID=...
GOOGLE_CLIENT_SECRET=...
GOOGLE_CALENDAR_ID=...                  # calendar ID from Google Calendar settings
GOOGLE_CALENDAR_REFRESH_TOKEN=...       # written automatically after Connect (also in storage/)
# Optional override if APP_HOST is wrong:
# GOOGLE_CALENDAR_REDIRECT_URI=http://localhost:3000/admin/google_calendar/callback
CROISSANT_BOOKING_USER_EMAIL=croissant@mezzaninecowork.com        # optional
```

## Connect (recommended)

1. Log in as an admin.
2. Open **Admin → Google Calendar**.
3. Click **Connect Google Calendar** and approve access as the calendar owner.
4. Click **Sync now** to pull events once (otherwise every 5 minutes).

Or via rake:

```bash
bin/rails google_calendar:authorize_url   # prints the same OAuth URL + required redirect URI
CODE=<code> bin/rails google_calendar:auth
bin/rails google_calendar:status
bin/rails google_calendar:sync
```

The refresh token is stored at `storage/google_calendar_tokens.json` (and optionally in env).

## Croissant partner portal

1. Integrations → Booking Systems → Google Calendar → connect the **same** Google account.
2. Map the private office / day-office listing to the **Croissant Desks** calendar.
3. Confirm: Croissant booking → event on GCal → desk booking in this app; app desk booking → event on GCal → blocked on Croissant.

## Behaviour notes

- Inbound Croissant events book the **first available desk** for that day (or a `monthly` booking for multi-day spans).
- App-originated desk bookings get a Google event tagged with `extendedProperties.private.cowork_booking_id` so inbound sync does not duplicate them.
- Bookings imported from Google use `source=google_calendar` and the shared Croissant system user.
