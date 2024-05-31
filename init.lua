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
  if __running_checks > 0 then
    print(string.format("evaluate_check_run(): %d checks still running, skipping evaluation ...", __running_checks))
  else
    print("evaluate_check_run(): starting evaluation")
    -- first, current run status is last run status
    print("checks done, evaluating")
    if __current_run_status == __vpn_active then
      -- actually, do nothing :)
      print("VPN check - no change.")
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

function connect_callback(...)
end

function ping_callback(_, status, ...)
  print(status, ...)
  if status == "receivedPacket" then
    __current_run_status = true
  end
  if status == "didFinish" or status == "didFail" then
    __running_checks = __running_checks - 1
  end
  evaluate_check_run()
end

function check_connect(fqdn, port)
  print(string.format("Checking %s:%s", fqdn, port))
  -- https://www.hammerspoon.org/docs/hs.socket.html
  local socket = hs.socket.new()
  socket:setTimeout(0.5)
  socket:connect(fqdn, port)
  if socket:connected() then
    print("in VPN!!")
  else
    print("not in vpn :/")
  end
end


function check_ping(fqdn)
  -- https://www.hammerspoon.org/docs/hs.network.ping.html
  print("check_ping(): ", fqdn)
  ping = hs.network.ping(fqdn, 1, 1, 0.5, "any", ping_callback)
end


function __set_vpn_on()
  -- https://www.hammerspoon.org/docs/hs.screen.html#allScreens
  for idx, screen in ipairs(hs.screen.allScreens()) do

    -- get screen geometry, https://www.hammerspoon.org/docs/hs.geometry.html#rect
    rect = screen:fullFrame()

    -- convenience calculation
    ten_percent = rect.h / 10

    -- create the text for the canvas. note that we assume 1pt==1px (which is, let's face it,
    -- most probably horribly false)
    -- https://www.hammerspoon.org/docs/hs.styledtext.html
    text = hs.styledtext.new("VPN", {
        font = {name = "Arial Black", size = ten_percent * 3},
        color = hs.drawing.color.x11["red"], -- https://is.gd/0mbc11, https://is.gd/KBkjB2
        paragraphStyle = {alignment = "center"},
    })

    -- create a new canvas
    -- https://www.hammerspoon.org/docs/hs.canvas.html
    canvas = hs.canvas.new({
        x = rect.x,
        y = rect.y + (3 * ten_percent),
        w = rect.w,
        h = 3 * ten_percent
    })
    canvas:alpha(0.2)

    -- create a new _layer_ in the canvas (??)
    -- canvas[1] = {
    --     type = "rectangle",
    --     action = "fill",
    --     fillColor = {hex="#eeeeee"},
    -- }
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
    -- http://lua-users.org/wiki/StringTrim
    -- http://lua-users.org/wiki/SplitJoin
    -- https://www.lua.org/manual/5.1/manual.html#5.4.1
    -- https://www.lua.org/manual/5.4/manual.html#pdf-string.gmatch
    -- QUOTE: "Returns an iterator function that, each time it is called,
    --         returns the next captures from pattern [...]"
    fqdn, port = string.gmatch(check_me, "([^:]+):([^:]+)")()
    port = tonumber(port)
    __running_checks = __running_checks + 1
    check_connect(fqdn, port)
  end

  for idx, check_me in ipairs(obj.checkPing) do
    __running_checks = __running_checks + 1
    print(string.format("refresh(): checking PING for '%s'", check_me))
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
  -- set those two from the outside on the object
  self.checkConnect = {}
  self.checkPing = {}
  self.checkInterval = 10

  -- internal variables, but not object-bound (i do not get so much of this stuff ...)
  __vpn_active = false
  __canvases = {}
  __set_vpn_off()

  -- for config file reading, WHICH WE DON'T DO ANY MORE, too annoying.
  -- https://stackoverflow.com/a/7617366/902327
  -- should be "FQDN:PORT" in there
  -- https://stackoverflow.com/a/11204889/902327
  --local target_file_path = os.getenv("HOME") .. "/.vpnwatch.txt"
  --local target_file = io.open(target_file_path, "rb")
  --if target_file then
  --  print(string.format("file '%s' loaded.", target_file_path))
  --  content = target_file:read()
  --  target_file:close()
  --else
  --  content = ""
  --end
  return self
end



return obj
