# Playing online with friends (before Steam)

Until Steam is wired in, the game connects by address (direct IP, over ENet/UDP). To
reach a host over the internet without touching a router, the host runs a free
**playit.gg** tunnel: it gives the host a public address that forwards to the game on
their PC. Only the host installs anything; friends just type the address.

Everyone must run **the same build**. After any change to the game, export again and
send the new copy round.

## 1. Make a build to share (once per version)

1. Open the project in Godot 4.7.2.
2. First time only: **Editor → Manage Export Templates → Download and Install**
   (about 1 GB, so give it a few minutes).
3. **Project → Export…**. The **Windows Desktop** preset is already set up. Click
   **Export Project…**, untick **Export With Debug**, and save. It writes
   `builds/windows/JumpyShooty.exe` (a single file, about 110 MB, with everything
   inside). There is also a **Linux** preset.
4. Upload the .exe to Google Drive, Dropbox or similar and send friends the link
   (Discord's upload limit is usually too small).

Windows may warn about an unrecognised app the first time someone runs it, because the
build is not signed. Click **More info → Run anyway**. Windows Firewall may also ask
about network access the first time someone hosts or joins: click **Allow**.

## 2. Host: set up the tunnel (once)

1. Make an account at https://playit.gg and download the **playit** program for
   Windows. Run it; it opens a page in your browser to link ("claim") it to your
   account.
2. On the playit.gg website, go to **Tunnels → Add tunnel**:
   - Tunnel type: **UDP** (a plain/custom UDP tunnel, not a Minecraft one).
   - Local address `127.0.0.1`, local port **24680**.
3. playit shows the tunnel's public address, something like
   `quiet-robot.gl.at.ply.gg:41234`. That is what friends type. It stays the same, so
   you can pin it in your group chat.

The playit program must be running whenever you host.

## 3. Play

- **Host:** run the game, **Multiplayer → Create lobby**.
- **Friends:** **Multiplayer → Join**, type the tunnel address **including the
  `:port` on the end**, then **Join lobby**.
- Up to 5 players. Pick the map and rules in the lobby and start.

If a friend's join hangs for about 30 seconds and then fails: check playit is running
and the tunnel shows as connected, the address and port are typed exactly, and the
host is sitting in the lobby.

Traffic goes through playit's servers, so expect a little extra ping (usually 10 to
50 ms). The game is built to stay smooth at 100 ms, so this is fine for testing.

## Other ways

**Tailscale (lower ping, everyone installs it).** Everyone installs Tailscale
(https://tailscale.com) and signs in. The host invites friends to their machine
(Tailscale admin page → the host's machine → **Share**). When the host creates a
lobby, the lobby screen shows a `100.x.x.x` address; friends type that. Connections
usually go straight between PCs, so ping is what you would get anyway.

**Port forwarding (nothing to install).** In the host's router settings, forward
**UDP port 24680** to the host PC's local address (the `192.168.x.x` the lobby shows).
Friends type the host's public IP (search "what is my IP" on the host PC). This does
not work if the internet provider puts the host behind carrier-grade NAT, which is
common on mobile and some fibre connections.

**Steam (the long-term plan).** Steam lobbies and invites with Steam's relay, so no
addresses at all. It needs the GodotSteam plugin installed in the editor and code for
a Steam transport; until the game has its own Steam app id, testing uses Valve's
test app (Spacewar, app id 480), and everyone needs Steam running.
