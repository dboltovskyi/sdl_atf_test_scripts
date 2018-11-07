local utils = require('user_modules/utils')
local m = require('user_modules/sequences/actions')

local timeout = 1000

local function log(pData)
  local function format(pValue)
    return pValue .. string.rep(" ", 10 - string.len(pValue))
  end
  local lvl = format(pData.payload.hmiLevel)
  local ass = format(pData.payload.audioStreamingState)
  local vss = format(pData.payload.videoStreamingState)
  utils.cprint(35, lvl, ass, vss)
end

function m.activateApp(pAppId)
  local requestId = m.getHMIConnection():SendRequest("SDL.ActivateApp", { appID = m.getHMIAppId(pAppId) })
  m.getHMIConnection():ExpectResponse(requestId)
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(1)
  :Timeout(timeout)
end

function m.deactivateApp(pAppId)
  m.getHMIConnection():SendNotification("BasicCommunication.OnAppDeactivated", { appID = m.getHMIAppId(pAppId) })
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(1)
  :Timeout(timeout)
end

function m.embeddedEventStart(pEvent)
  m.getHMIConnection():SendNotification("BasicCommunication.OnEventChanged", { eventName = pEvent, isActive = true })
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(AtMost(1))
  utils.wait(timeout)
end

function m.embeddedEventFinish(pEvent)
  m.getHMIConnection():SendNotification("BasicCommunication.OnEventChanged", { eventName = pEvent, isActive = false })
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(AtMost(1))
  utils.wait(timeout)
end

function m.ttsStart()
  m.getHMIConnection():SendNotification("TTS.Started")
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(AtMost(1))
  utils.wait(timeout)
end

function m.ttsStop()
  m.getHMIConnection():SendNotification("TTS.Stopped")
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(AtMost(1))
  utils.wait(timeout)
end

function m.vrStart()
  m.getHMIConnection():SendNotification("VR.Started")
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(AtMost(1))
  utils.wait(timeout)
end

function m.vrStop()
  m.getHMIConnection():SendNotification("VR.Stopped")
  m.getMobileSession():ExpectNotification("OnHMIStatus")
  :Do(function(_, data) log(data) end)
  :Times(AtMost(1))
  utils.wait(timeout)
end

return m
