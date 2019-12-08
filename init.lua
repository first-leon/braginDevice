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
period                      = 10000
tv                          = 10000
gist                        = 1
delayTimer                  = 0
relayPin=3
gpio.mode(relayPin, gpio.OUTPUT)

ln =dofile('ln.lc')
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
    dofile('httpServer.lc')
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
  wf        = {}
  wf.ssid   = p.wifi_ssid
  wf.pwd    = p.wifi_password
  wifi.setmode(wifi.STATION)
  wifi.sta.config(wf)
  wf=nil
  device.id = p.device_id
  perid     = p.period or period
  gist      = p.gist or gist
  tv        = p.tv  or tv
  print('Parameters: ', sjson.encode(p))
  p         = nil
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
mytimer:register(tv, tmr.ALARM_AUTO, function()
    GetSensorData()
    local gamma = 17.27 * device.sensors["t1"].value/(237.7+device.sensors["t1"].value) + ln[math.floor(device.sensors["h1"].value)]
    local t = 237.7 * gamma/ (17.27 - gamma)
    print('gist: ', gist)
    print('gamma: ', gamma)
    print('t: ', t)
    print(sjson.encode(device))
    if ( ( t + gist) > tonumber(device.sensors["t2"].value) ) then
        delayTimer = tmr.now()
        print('Disable power')
        gpio.write(relayPin, gpio.LOW)
    end
    if ( (( t - gist) < tonumber(device.sensors["t2"].value)) and ((tmr.now() - delayTimer) > tonumber(tv)*1000) ) then
        print('Enable power')
        gpio.write(relayPin, gpio.HIGH)
    end
    
end)
mytimer:interval(tv)
mytimer:start()
