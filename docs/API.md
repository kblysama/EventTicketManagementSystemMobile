# Yerin mobile API contract

Base URL is configured with `API_URL`; no database connection exists in the app.
Authenticated requests send `Authorization: Bearer <Sanctum token>` and `Accept: application/json`.

## Identifiers and JSON

- Event routes use `slug`; ticket routes use `code`; mobile order detail uses numeric `id`. Web order-number routes remain unchanged.
- Most endpoints return `{ "data": ... }`. Authentication returns `{ "token": ..., "user": ... }`; `/me` returns `{ "user": ... }`.
- Amounts are integer **Turkish lira**, not kuruş. Times include an ISO-8601 timezone and are displayed in the device timezone with Turkish formatting.
- Event fields: `id`, `slug`, `title`, `description`, `venue`, `city`, `event_category_id`, `category`, `category_label`, `starts_at`, `ends_at`, `status`, `cover_url`, `starting_price`, `sold`, `capacity`, `remaining`, `checked_in`, `revenue`, `organizer`, `ticket_types`.
- Ticket type fields: `id`, `name`, `description`, `price`, `capacity`, `sold`, `remaining`, `sale_status` (`on_sale` / `paused`).
- Ticket fields: `code`, `status` (`unused` / `used`), `buyer_name`, `ticket_type`, `order_number`, `checked_in_at`, nested `event`.
- Order fields: `id`, `number`, `buyer_name`, `buyer_email`, `quantity`, `unit_price`, `total`, `status`, `created_at`, nested `event`, `ticket_type`, and `tickets` containing codes.

## Routes

| Method | Route | Access / purpose |
| --- | --- | --- |
| POST | `/auth/register` | Public; attendee only |
| POST | `/auth/login` | Public; email and password |
| POST | `/auth/forgot-password` | Public; email |
| POST | `/auth/reset-password` | Public; token, email, password, password_confirmation |
| POST | `/auth/logout` | Authenticated; revoke current token |
| GET | `/me` | Authenticated user |
| GET | `/event-categories` | Public category options |
| GET | `/event-cities` | Public city strings |
| GET | `/events` | Published events; `q`, `category`, `city` filters |
| GET | `/events/{slug}` | Public published event |
| GET/POST | `/orders` | Own orders / demo purchase |
| GET | `/orders/{id}` | Authorized order detail |
| GET | `/tickets` | Own tickets |
| GET | `/tickets/{code}` | Authorized ticket detail |
| GET/POST | `/organizer/events` | Organizer list/create |
| GET/PUT/DELETE | `/organizer/events/{slug}` | Owned event detail/update/delete |
| GET | `/organizer/events/{slug}/sales` | Owned sales summary |
| POST | `/organizer/event-categories` | Create or reuse category by name |
| GET/POST | `/organizer/events/{slug}/ticket-types` | Owned ticket types |
| PUT | `/organizer/events/{slug}/ticket-types/{id}` | Owned ticket type update |
| POST | `/organizer/events/{slug}/check-in` | Verify `code` |
| GET | `/admin/events` | All events; `status` filter |
| GET | `/admin/events/{slug}` | Read-only mobile management detail |
| GET | `/admin/orders` | All orders; `event_id` filter |
| POST | `/broadcasting/auth` | Bearer-authorized private channel subscription |

Create/update event uses multipart fields: `title`, `description`, `venue`, `city`, `event_category_id`, `starts_at`, `ends_at`, `status` and optional `cover` (JPG/PNG/WebP, max 5 MB). Update sends POST with `_method=PUT`.

Purchase sends `ticket_type_id`, `quantity` (1–10), `buyer_name`, `buyer_email`. Client totals are display-only; server validates sale status, stock and price. No real payment provider is used. A timed-out purchase is never automatically retried.

Check-in success is HTTP 200 `{ "reused": false, "message": "...", "ticket": ... }`; a previously used ticket is HTTP 409 with `reused: true`. Invalid code returns 422. No offline check-in queue exists.

## Realtime

Pusher protocol v7 over Reverb. Public `events`; private `user.{id}`, `organizer.{id}`, `admin` (wire channel names have `private-` prefix). Only the public app key belongs in Flutter configuration; never embed the Reverb secret.

`event.updated`, `order.created`, `ticket.checked-in` invalidate active REST queries. Mobile reauthorizes subscriptions and refreshes data after reconnect/resume. Backoff is capped at 30 seconds. Public notifications must not include buyer data or draft details. Server notifications must run after successful database commit.

Errors: 401 clears only the matching session; 403 is access denied; 409 is a business conflict; 422 maps field validation errors; network errors offer retry without treating cached data as live.
