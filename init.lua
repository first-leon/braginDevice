DHTpin1                     = 1
DHTpin2                     = 2
BUTTONpin                   = 3    --> GPIO2
firmwareVersion             = 1
device                      = {}
device.sensors              = {}
device.sensors["h1"]        = {}
device.sensors["h1"].value  = "0"
device.sensors["t1"]        = {}
device.sensors["t1"].value  = "0"
device.sensors["h2"]        = {}
device.sensors["h2"].value  = "0"
device.sensors["t2"]        = {}
device.sensors["t2"].value  = "0"

ln = {0,0.69,1.1,1.39,1.61,1.79,1.95,2.08,2.2,2.3,2.4,2.48,2.56,2.64,2.71,2.77,2.83,2.89,2.94,3,3.04,3.09,3.14,3.18,3.22,3.26,3.3,3.33,3.37,3.4,3.43,3.47,3.5,3.53,3.56,3.58,3.61,3.64,3.66,3.69,3.71,3.74,3.76,3.78,3.81,3.83,3.85,3.87,3.89,3.91,3.93,3.95,3.97,3.99,4.01,4.03,4.04,4.06,4.08,4.09,4.11,4.13,4.14,4.16,4.17,4.19,4.2,4.22,4.23,4.25,4.26,4.28,4.29,4.3,4.32,4.33,4.34,4.36,4.37,4.38,4.39,4.41,4.42,4.43,4.44,4.45,4.47,4.48,4.49,4.5,4.51,4.52,4.53,4.54,4.55,4.56,4.57,4.58,4.6,4.61}

longPressKey3Timer = 0
function key(l, t)
    if ( l == 0 ) then
        longPressKey3Timer = t
    elseif ( t - longPressKey3Timer > 1000000) then
        file.remove("eus_params.lua")
        node.restart()
    end
end
gpio.mode(BUTTONpin,gpio.INT,gpio.PULLUP)
gpio.trig(BUTTONpin, 'both', key)
function httpServerStart()
    dofile('httpServer.lua')
    httpServer:listen(80)
    httpServer:use('/api/version', function(req, res)
        resp                    = {}
        resp.firmwareVersion    = firmware
        resp.heap               = node.heap()
        res:type('application/json')
        res:send(sjson.encode(resp))
    end)
    httpServer:use('/api', function(req, res)
        res:type('application/json')
        res:send(sjson.encode(device))
    end)

end
if file.exists("eus_params.lua") then
    p = dofile('eus_params.lua')
end
if p then
  wf = {}
  wf.ssid = p.wifi_ssid
  wf.pwd = p.wifi_password
  device.id = p.device_id
  p = nil
  wifi.setmode(wifi.STATION)
  wifi.sta.config(wf)
  wf=nil
  node.egc.setmode(node.egc.ALWAYS)
  httpServerStart()
else
    enduser_setup.start(
      function()
        print("Connected to WiFi as:" .. wifi.sta.getip())
        local sleepTtimer = tmr.create()
        sleepTtimer:register(5000, tmr.ALARM_SINGLE, function()
            node.restart()
        end)
        sleepTtimer:start()
      end,
      function(err, str)
        print("enduser_setup: Err #" .. err .. ": " .. str)
      end
    )
end

function GetSensorData()
    local s, t, h = dht.read(DHTpin1)
    if s == dht.OK then
        device.sensors["t1"].value = tostring(t)
        device.sensors["h1"].value = tostring(h)
    else
        print("dht1.s:"..s )
    end
    local s, t, h = dht.read(DHTpin2)
    if s == dht.OK then
        device.sensors["t2"].value = tostring(t)
        device.sensors["h2"].value = tostring(h)
    else
        print("dht2.s:"..s )
    end
end

local mytimer = tmr.create()
mytimer:register(10000, tmr.ALARM_AUTO, function()
    GetSensorData()
end)
mytimer:interval(10000)
mytimer:start()
