# Hammerspoon VpnWatch Spoon

This is my first attempt at a Spoon, it's probably really bad.

Anyway.

It does one thing: It will overlay a big fat **"VPN"** over your screen as long as a VPN is active.

It detects VPNs by performing a PING to hosts which are only reachable when you're in the VPN.

## TL;DR

Configuration:

```lua
hs.loadSpoon("VpnWatch")
spoon.VpnWatch.checkPing = {"my.host-from-the.vpn","...",}
spoon.VpnWatch:setupTimer()
```

The interval is configurable:

```lua
spoon.VpnWatch.checkInterval = 25
-- or
spoon.VpnWatch.setupTimer(25)
```

... aaand that's about it.
