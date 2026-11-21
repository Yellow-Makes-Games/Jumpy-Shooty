# Online accounts (optional)

Players can sign in with Google, Discord or another OAuth provider. Their profile and
progress are then kept in a Supabase project and follow them to any computer. Signing in
is optional: signed out (or in a build with no Supabase project configured), the game
works exactly as before and saves on this computer only.

What's kept (see `game/online/cloud_save.gd`):

- **Profile:** username, the robot you play as, custom characters, calling card and
  icon, colour, weapon and mobility picks, and tracked achievements.
- **Progress:** every achievement count, including XP (and so your level), kills,
  deaths, games and time played. Also unlocks, weapons used, courses finished, race
  best times and medals, top speed, and when each achievement was completed.

## Setting it up (once, by whoever runs the project)

1. **Create a Supabase project** at https://supabase.com.
2. **Create the table.** Run `supabase/migrations/20261118000000_player_data.sql` in
   the SQL editor, or `supabase db push` with the Supabase CLI. It creates
   `public.player_data`, one row per player, with row-level security so each player can
   only read and write their own row.
   Then run `supabase/migrations/20261121000000_friends.sql` the same way, for
   friends (see [Friends](#friends) below).
3. **Turn on providers.** Under Authentication > Sign In / Providers, turn on each one
   you want (Google, Discord...). Each needs an OAuth app made in that provider's
   developer console, using the callback URL Supabase shows you
   (`https://<ref>.supabase.co/auth/v1/callback`).
4. **Allow the game's redirect.** Under Authentication > URL Configuration, add this to
   Redirect URLs:

       http://127.0.0.1:47811/callback

   The game listens there for a moment while you sign in (`Account.REDIRECT_PORT`).
5. **Point the game at the project.** Copy `game/online/supabase.example.cfg` to
   `game/online/supabase.cfg` and fill in the Project URL and the **anon** or **publishable**
   (`sb_publishable_...`, public)
   key from Project Settings > API. List the providers you turned on.
   - The anon key is meant to ship inside the game. Row-level security protects the
     data.
   - **Never** use the `service_role` key.
   - `supabase.cfg` is git-ignored, and the export presets include it in builds.
   - A `user://supabase.cfg` overrides it, for trying another project without
     rebuilding.

With no `supabase.cfg`, the Account section doesn't appear on the Profile page.

6. **Release builds** (the Playtest build workflow) are made from a fresh checkout,
   which has no `supabase.cfg`. The workflow writes it from three repository Actions
   **variables** (Settings > Secrets and variables > Actions > Variables):
   `SUPABASE_URL`, `SUPABASE_KEY` (the anon or publishable key) and
   `SUPABASE_PROVIDERS` (e.g. `google, discord`). Or from the command line:

       gh variable set SUPABASE_URL --body "https://<ref>.supabase.co"
       gh variable set SUPABASE_KEY --body "sb_publishable_..."
       gh variable set SUPABASE_PROVIDERS --body "google, discord"

   Without them the build works, with no sign-in.

## How it works

- **Signing in** (`game/online/account.gd`) is OAuth with PKCE, the flow for apps that
  can't keep a secret:
  1. The game opens the browser at Supabase's authorize page and starts a tiny web
     server on 127.0.0.1:47811.
  2. After you sign in, Supabase redirects to it with a one-time code.
  3. The game trades that code, plus a secret only this copy knows (the PKCE
     verifier), for a session.
  4. The refresh token is kept in `user://account.cfg`, so you stay signed in.
     Sign out ends the session and deletes that file.
- **Syncing** runs:
  - on sign-in;
  - when the game starts signed in;
  - at the end of every match;
  - about 20 s after the profile or progress changes.

  Each sync reads the cloud copy, merges it with this computer's, keeps the result
  here and writes it back. When offline it keeps working locally and retries every
  minute.
- **Merging** (`CloudSave.merge`):
  - Progress only goes up: each count keeps the bigger of the two copies, sets and
    unlocks are joined, best times keep the quickest.
  - The profile is taken whole from whichever copy was changed most recently.
  - Custom characters are joined by name.
  - Counts take the bigger copy rather than adding the two, so the same kill is never
    counted twice. The trade-off: if you play signed out on two computers, then sign
    in on both, you keep the larger of the two counts, not their sum.
  - Signing in merges what's on this computer into the account. Signing in to a
    different account later merges this computer's data into that one too.

Tests: `tests/cloud_save_test.gd` checks the merge, restoring a cloud copy, the PKCE
challenge, the redirect parsing and the Profile page's account panel. It needs no
network.

## Friends

Signed-in players can add each other as friends, see what their friends are doing and
invite them into a lobby. Signed out, the Friends section on the Profile page says to
sign in, and nothing is sent.

- **Usernames.** A player claims a username on the Profile page, under Friends. It's
  3 to 16 letters, digits or `_`, and unique whatever the case. It's suggested from
  their display name, which stays as it is (display names don't have to be unique).
- **Requests.** Type a friend's username and press Add. They see the request with
  Accept and Decline. If both players ask each other, they become friends. Remove takes
  a friend off, and Cancel takes back a request you sent.
- **Status.** Each friend shows as Online, In a lobby, In a match (Practice and Vs Bots
  count) or Offline.
- **Invites.** In a lobby they host, the host presses **Invite friends** beside the
  lobby code and then Invite beside a friend who isn't offline. The friend sees
  "*name* invited you" in the top right of the main menu, with Join and a cross. Join
  joins that lobby code as a player, the same way as Join lobby. Invites last
  10 minutes.

### Setting it up

Run `supabase/migrations/20261121000000_friends.sql` once in the Supabase dashboard:
**SQL Editor > New query**, paste the whole file and press **Run**. Or use
`supabase db push`. Run it after the `player_data` migration. It can be run again
safely.

It creates:

| | |
|---|---|
| `player_profiles` | One row per player with a username: the username, `status` (`online`, `lobby`, `match`) and `last_seen`. |
| `friendships` | One row per pair of players: `accepted` is false while it's a request. |
| `lobby_invites` | A host's invite to a friend, with the lobby code. |

It also creates the functions the game calls, `POST /rest/v1/rpc/<name>`. Each one
returns the whole friends state, so one request is enough:

| Function | Does |
|---|---|
| `friends_heartbeat(p_status)` | Says you're here and what you're doing; returns the state. |
| `friends_state()` | The state: your username, friends with status and seconds since last seen, requests both ways, and invites to you. |
| `claim_username(p_name)` | Takes or changes your username. |
| `send_friend_request(p_name)` | Asks a player by username; if they already asked you, you're friends. |
| `respond_friend_request(p_from, p_accept)` | Accepts or declines a request to you. |
| `remove_friend(p_id)` | Removes a friend or takes back a request, and any invites between you. |
| `invite_friend(p_id, p_code)` | Invites a friend into your lobby. |
| `dismiss_invite(p_from)` | Clears an invite to you. |

Security:

- Row-level security is on for all three tables.
- Players can read their own rows directly. They can read a profile only if it's
  their own or an accepted friend's.
- Nothing can be written to the tables directly. Every write goes through a
  function, which runs as `security definer`, checks `auth.uid()` and checks the rules.
  For example, you can only invite accepted friends, and usernames must be valid and
  free.
- Only signed-in players (`authenticated`) can call the functions. `anon` can't.
- There are limits: 50 unanswered requests and 200 friends per player.

### How it works

- **Client:** `game/online/friends.gd` (the `Friends` autoload). It calls the functions
  with `Account.call_function`, which refreshes the session first when needed. Two
  calls that both need a refresh share one, because each refresh token works only once.
- **Presence** is a heartbeat over REST, not Realtime, so the game stays REST-only:
  - While signed in with a username, the game calls `friends_heartbeat` every 15 s
    (`Friends.POLL`). It also calls within a second when you go between the menu, a
    lobby and a match.
  - A friend not heard from for 45 s (`Friends.ONLINE_FOR`) shows as offline. The
    server sends seconds since last seen, so clocks don't need to agree.
  - That's about four small requests a minute per player, and none while signed out
    or before a username is claimed.
- **UI:** `game/ui/friends_panel.gd` is the Friends section on the Profile page, and
  the same list (with Invite buttons) in the lobby's Invite friends window. The invite
  note is in `game/ui/main_menu.gd` (`_show_invite`). Its Join goes through
  `join_code`, the same code path as the Join lobby window.

Tests: `tests/friends_test.gd`, with the server mocked. It checks:

- statuses and usernames;
- reading the server's state (sorting, offline after 45 s, dropping invites with a bad
  code, ignoring junk);
- the function and arguments each action sends;
- server errors shown in the server's own words;
- a new invite announced once;
- signing out clearing everything;
- the Profile and lobby panels and the main menu's invite note.
