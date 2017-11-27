---------------------------------------------------------------------------------------------------
-- Navigation common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
-- config.defaultProtocolVersion = 5

--[[ Required Shared libraries ]]
local mobile_session = require("mobile_session")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local commonTestCases = require("user_modules/shared_testcases/commonTestCases")
local constants = require('protocol_handler/ford_protocol_constants')
local events = require('events')
local Event = events.Event
local bson = require('bson4lua')
local test = require('user_modules/dummy_connecttest')

local m = {}

--[[ Constants ]]
m.timeout = 2000
m.minTimeout = 500

m.bsonType = {
  DOUBLE = 0x01,
  STRING = 0x02,
  ARRAY = 0x03,
  DOCUMENT = 0x04,
  BOOLEAN = 0x08,
  INT32 = 0x10,
  INT64 = 0x12
}

m.serviceType = constants.SERVICE_TYPE

m.frameInfo = constants.FRAME_INFO

--[[ Variables ]]
local pAppId = 1
local hmiAppIds = {}

--[[ Functions ]]

--[[ @preconditions: precondition steps
--! @parameters: none
--]]
function m.preconditions()
  commonFunctions:SDLForceStop()
  commonSteps:DeletePolicyTable()
  commonSteps:DeleteLogsFiles()
end

--[[ @postconditions: postcondition steps
--! @parameters: none
--]]
function m.postconditions()
  StopSDL()
end

--[[ @getHMIAppId: get HMI application identifier
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: application identifier
--]]
function m.getHMIAppId()
  return hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
end

--[[ @getMobileSession: get mobile session
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! self - test object
--! @return: mobile session
--]]
function m.getMobileSession()
  return test["mobileSession" .. pAppId]
end

--[[ @registerApp: register mobile application
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! self - test object
--]]
function m.registerApp()
  local mobSession = m.getMobileSession(pAppId)
  local corId = mobSession:SendRPC("RegisterAppInterface",
    config["application" .. pAppId].registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered",
    { application = { appName = config["application" .. pAppId].registerAppInterfaceParams.appName } })
  :Do(function(_, d1)
      hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID] = d1.params.application.appID
    end)
  mobSession:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
  :Do(function()
      mobSession:ExpectNotification("OnHMIStatus",
        { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
      mobSession:ExpectNotification("OnPermissionsChange")
    end)
end

--[[ @activateApp: activate application
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! self - test object
--]]
function m.activateApp()
  local pHMIAppId = hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
  local mobSession = m.getMobileSession(pAppId)
  local requestId = test.hmiConnection:SendRequest("SDL.ActivateApp", { appID = pHMIAppId })
  EXPECT_HMIRESPONSE(requestId)
  mobSession:ExpectNotification("OnHMIStatus",
    { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
  commonTestCases:DelayedExp(m.minTimeout)
end

--[[ @allowSDL: sequence that allows SDL functionality
--! @parameters:
--! self - test object
--]]
local function allowSDL()
  test.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
    { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = "127.0.0.1" } })
end

--[[ @start: starting sequence: starting of SDL, initialization of HMI, connect mobile
--! @parameters:
--! pHMIParams - table with parameters for HMI initialization
--! self - test object
--]]
function m.start()
  test:runSDL()
  commonFunctions:waitForSDLStart(test)
  :Do(function()
      test:initHMI()
      :Do(function()
          commonFunctions:userPrint(35, "HMI initialized")
          test:initHMI_onReady()
          :Do(function()
              commonFunctions:userPrint(35, "HMI is ready")
              test:connectMobile()
              :Do(function()
                  commonFunctions:userPrint(35, "Mobile connected")
                  allowSDL()
                end)
            end)
        end)
    end)
end

function m.startMobileSession()
  test["mobileSession" .. pAppId] = mobile_session.MobileSession(test, test.mobileConnection)
end

function test:delayedExp(pTime)
  local event = events.Event()
  event.matches = function(self, e) return self == e end
  EXPECT_HMIEVENT(event, "Delayed event")
  :Timeout(pTime + 5000)
  local function toRun()
    event_dispatcher:RaiseEvent(test.hmiConnection, event)
  end
  RUN_AFTER(toRun, pTime)
end

function test.sendControlMessage(pServiceId, pFrameInfo, pVersion, pPayload)
  local mobSession = m.getMobileSession(pAppId)
  local payload = nil
  if pPayload then payload = bson.to_bytes(pPayload) end
  local binaryData = nil
  if pFrameInfo == constants.FRAME_INFO.END_SERVICE then
    if pServiceId == m.serviceType.RPC and pVersion >= 1 and pVersion <= 4 then
      binaryData = mobSession.mobile_session_impl.hashCode
    end
  end
  local msg = {
    frameType = constants.FRAME_TYPE.CONTROL_FRAME,
    frameInfo = pFrameInfo,
    serviceType = pServiceId,
    payload = payload,
    version = pVersion,
    binaryData = binaryData
  }
  mobSession.mobile_session_impl:Send(msg)
end

function test.expectControlMessage(pServiceId, pFrameInfo, pVersion, pPayload)
  if not pPayload then pPayload = { } end
  local mobSession = m.getMobileSession(pAppId)
  local event = Event()
  event.matches = function(_, data)
    return (data.frameType == constants.FRAME_TYPE.CONTROL_FRAME) and
      (data.serviceType == pServiceId) and
      (pServiceId == m.serviceType.RPC or data.sessionId == mobSession.sessionId) and
      (data.frameInfo == pFrameInfo)
  end
  local ret = mobSession:ExpectEvent(event, "ControlService")
  :Do(function(_, data)
      if data.serviceType == m.serviceType.RPC and data.frameInfo == constants.FRAME_INFO.START_SERVICE_ACK then
        mobSession.mobile_session_impl.sessionId.set(data.sessionId)
        if data.version >= 1 and data.version <=4 then
          mobSession.mobile_session_impl.hashCode = data.binaryData
        end
      end
    end)
  :ValidIf(function(_, data)
      if data.version ~= pVersion then
        return false, "\nExpected protocol version is '" .. pVersion .. "', actual is '" .. data.version .. "'"
      end
      return true
    end)
  :ValidIf(function(_, data) -- only for v5 protocol version
      if data.version ~= 5 then return true end
      local function getBSONType(pValue)
        for k, v in pairs(m.bsonType) do
          if v == pValue then return k end
        end
        return nil
      end
      local actualPayload = {}
      if string.len(data.binaryData) > 0 then
        actualPayload = bson.to_table(data.binaryData)
      end
      -- commonFunctions:printTable(data)
      -- commonFunctions:printTable(actualPayload)
      local msg = ""
      for k in pairs(pPayload) do
        if actualPayload[k] == nil then
          msg = msg .. "\nExpected key '" .. k .. "' is missing"
        else
          if actualPayload[k].type ~= pPayload[k].type then
            msg = msg .. "\nExpected type for '" .. k .. "' key is '" .. getBSONType(pPayload[k].type)
              .. "', actual is '" .. tostring(getBSONType(actualPayload[k].type)) .. "'"
          end
          if actualPayload[k].value ~= pPayload[k].value then
            msg = msg .. "\nExpected value for '" .. k .. "' key is '" .. pPayload[k].value
              .. "', actual is '" .. tostring(actualPayload[k].value) .. "'"
          end
        end
      end
      for k in pairs(actualPayload) do
        if pPayload[k] == nil then
          msg = msg .. "\nUnexpected key '" .. k .. "' is present"
        end
      end
      return (string.len(msg) > 0 and {false} or {true})[1], msg
    end)
  return ret
end

function m.delayedExp()
  test:delayedExp(m.timeout)
end

function m.sendControlMessage(...)
  test.sendControlMessage(...)
end

function m.expectControlMessage(...)
  return test.expectControlMessage(...)
end

function m.startRPCService()
  local serviceType = m.serviceType.RPC
  local request = {
    frameInfo = m.frameInfo.START_SERVICE,
    version = 1,
    params = { }
  }
  local response = {
    frameInfo = m.frameInfo.START_SERVICE_ACK,
    version = 4,
    params = { }
  }
  m.sendControlMessage(serviceType, request.frameInfo, request.version, request.params)
  m.expectControlMessage(serviceType, response.frameInfo, response.version, response.params)
end

--[[ @protect: make table immutable
--! @parameters:
--! pTbl - mutable table
--! @return: immutable table
--]]
local function protect(pTbl)
  local mt = {
    __index = pTbl,
    __newindex = function(_, k, v)
      error("Attempting to change item " .. tostring(k) .. " to " .. tostring(v), 2)
    end
  }
  return setmetatable({}, mt)
end

return protect(m)
