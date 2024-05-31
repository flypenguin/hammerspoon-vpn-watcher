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
    elseif __current_run_status == true then
      -- off -> on transition.
      -- the last one was NOT true, otherwise the first "if" would have caught
      print("VPN check - VPN SWITCHED ON.")
      __vpn_active = true
      __set_vpn_on()
    else
      -- on -> off transition.
      -- same reason
      print("VPN check - vpn switched off.")
      __vpn_active = false
      __set_vpn_off()
    end
  end
end


function ping_callback(_, status, ...)
  if status == "receivedPacket" then
    __current_run_status = true
  end
  if status == "didFinish" or status == "didFail" then
    __running_checks = __running_checks - 1
  end
  evaluate_check_run()
end



function check_ping(fqdn)
  -- https://www.hammerspoon.org/docs/hs.network.ping.html
  ping = hs.network.ping(fqdn, 1, 1, 0.5, "any", ping_callback)
end


function __set_vpn_on()
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

  for idx, canvas in ipairs(__canvases) do
    canvas:show()
  end
end


function __set_vpn_off()
  for idx, canvas in ipairs(__canvases) do
    canvas:delete()
  end
  __vpn_active = false
end


function _refresh()
  -- this is modified by the callback functions
  __current_run_status = false
  __running_checks = 0

  for idx, check_me in ipairs({}) do -- self.checkConnect) do
    fqdn, port = string.gmatch(check_me, "([^:]+):([^:]+)")()
    port = tonumber(port)
    __running_checks = __running_checks + 1
    check_connect(fqdn, port)
  end

  for idx, check_me in ipairs(obj.checkPing) do
    __running_checks = __running_checks + 1
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

  __vpn_active = false
  __canvases = {}
  __set_vpn_off()

  return self
end



return obj
