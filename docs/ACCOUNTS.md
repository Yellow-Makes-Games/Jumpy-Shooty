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
3. **Turn on providers.** Under Authentication > Sign In / Providers, turn on each one
   you want (Google, Discord...). Each needs an OAuth app made in that provider's
   developer console, using the callback URL Supabase shows you
   (`https://<ref>.supabase.co/auth/v1/callback`).
4. **Allow the game's redirect.** Under Authentication > URL Configuration, add this to
   Redirect URLs:

       http://127.0.0.1:47811/callback

   The game listens there for a moment while you sign in (`Account.REDIRECT_PORT`).
5. **Point the game at the project.** Copy `game/online/supabase.example.cfg` to
   `game/online/supabase.cfg` and fill in the Project URL and the **anon** (public)
   key from Project Settings > API. List the providers you turned on.
   - The anon key is meant to ship inside the game. Row-level security protects the
     data.
   - **Never** use the `service_role` key.
   - `supabase.cfg` is git-ignored, and the export presets include it in builds.
   - A `user://supabase.cfg` overrides it, for trying another project without
     rebuilding.

With no `supabase.cfg`, the Account section doesn't appear on the Profile page.

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
