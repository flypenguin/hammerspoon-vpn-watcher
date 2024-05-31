--- === VpnWatch ===

local obj = {}
obj.__index = obj

-- Metadata
obj.name = "VpnWatch"
obj.version = "1.0.0"
obj.author = "Axel Bock <ab@a3b3.de>"
obj.homepage = "https://github.com/flypenguin/hammerspoon-vpn-watcher"
obj.license = "MIT - https://opensource.org/licenses/MIT"


-- --------------------------------------------------------------------------
-- --------------------------------------------------------------------------
-- --------------------------------------------------------------------------

local __vpn_active = false
local __canvases = {}

local __running_checks = 0
local __current_run_status = false

-- --------------------------------------------------------------------------
-- --------------------------------------------------------------------------
-- --------------------------------------------------------------------------

function evaluate_check_run()
  if __running_checks == 0 then
    -- first, current run status is last run status
    if __current_run_status == __vpn_active then
      -- actually, do nothing :)
      if obj.logLevel > 2 then
        print(string.format("[VpnWatch] VPN STATE: no change."))
      end
    elseif __current_run_status == true then
      -- off -> on transition.
      -- the last one was NOT true, otherwise the first "if" would have caught
      print(string.format("[VpnWatch] VPN STATE TRANSISION: OFF -> ON"))
      __set_vpn_on()
    else
      -- on -> off transition.
      -- same reason
      print(string.format("[VpnWatch] vpn state transition: on -> off"))
      __set_vpn_off()
    end
  end
end


function ping_callback(ping, status, ...)
  if obj.logLevel > 1 then
    print(string.format("[VpnWatch] ping '%s': got '%s'", ping:server(), status))
  end
  if status == "receivedPacket" then
    __current_run_status = true
  end
  if status == "didFinish" or status == "didFail" then
    __running_checks = __running_checks - 1
  end
  if obj.logLevel > 2 then
    print(string.format("[VpnWatch] check still running after this: %d", __running_checks))
  end
  evaluate_check_run()
end



function check_ping(fqdn)
  -- https://www.hammerspoon.org/docs/hs.network.ping.html
  ping = hs.network.ping(fqdn, 1, 1, 0.5, "any", ping_callback)
end


function __init_canvases()
  __canvases = {}

  -- https://www.hammerspoon.org/docs/hs.screen.html#allScreens
  for idx, screen in ipairs(hs.screen.allScreens()) do

    -- get screen geometry, https://www.hammerspoon.org/docs/hs.geometry.html#rect
    rect = screen:fullFrame()

    -- convenience calculation
    ten_percent = rect.h / 10

    -- https://www.hammerspoon.org/docs/hs.styledtext.html
    text = hs.styledtext.new("VPN", {
        font = {name = "Arial Black", size = ten_percent * 3},
        color = hs.drawing.color.x11["red"], -- https://is.gd/0mbc11, https://is.gd/KBkjB2
        paragraphStyle = {alignment = "center"},
    })

    -- https://www.hammerspoon.org/docs/hs.canvas.html
    canvas = hs.canvas.new({
        x = rect.x,
        y = rect.y + (3 * ten_percent),
        w = rect.w,
        h = 3 * ten_percent
    })
    canvas:alpha(0.2)

    canvas[1] = {
        type = "text",
        text = text,
        canvasAlpha = 0.8,
    }

    table.insert(__canvases, canvas)
  end
end


function __set_vpn_on()
  for idx, canvas in ipairs(__canvases) do
    canvas:show()
  end
  __vpn_active = true
end


function __set_vpn_off()
  for idx, canvas in ipairs(__canvases) do
    canvas:hide()
  end
  __vpn_active = false
end


function _refresh()
  -- this is modified by the callback functions
  __current_run_status = false
  __running_checks = 0

  if obj.logLevel > 2 then
    print(string.format("[VpnWatch] refresh(): starting. current vpn status == %s", __vpn_active))
  end
  for idx, check_me in ipairs({}) do -- self.checkConnect) do
    fqdn, port = string.gmatch(check_me, "([^:]+):([^:]+)")()
    port = tonumber(port)
    __running_checks = __running_checks + 1
    check_connect(fqdn, port)
  end

  for idx, check_me in ipairs(obj.checkPing) do
    __running_checks = __running_checks + 1
    if obj.logLevel > 1 then
      print(string.format("[VpnWatch] start PING check for %s", check_me))
    end
    check_ping(check_me)
  end
end


-- https://github.com/Hammerspoon/hammerspoon/issues/1942#issuecomment-1545526480
function obj:setupTimer(interval)
  if interval == nil then
    interval = obj.checkInterval
  end
  local timer = hs.timer.doEvery(interval, _refresh);
  return hs.caffeinate.watcher.new(function()
    if timer ~= nil then
      timer:stop();
    end
    timer = hs.timer.doEvery(interval, _refresh);
  end):start();
end


-- simple wrapper around _refresh() ...
function obj:refresh()
  _refresh()
end


function obj:init()
  self.checkPing = {}
  self.checkInterval = 10
  self.logLevel = 0
  __vpn_active = false
  __init_canvases()
  __set_vpn_off()

  return self
end



return obj
