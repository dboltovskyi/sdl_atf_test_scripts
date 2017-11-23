---------------------------------------------------------------------------------------------------
-- Navigation common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.defaultProtocolVersion = 5

--[[ Required Shared libraries ]]
local mobile_session = require("mobile_session")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local commonTestCases = require("user_modules/shared_testcases/commonTestCases")
local constants = require('protocol_handler/ford_protocol_constants')
local events = require('events')
local Event = events.Event
local bson = require('bson4lua')

local m = {}

--[[ Constants ]]
m.timeout = 2000
m.minTimeout = 500

m.app = {
  id1 = 1,
  id2 = 2
}

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

--[[ @getSelfAndParams: shifting parameters in order to move self at 1st position
--! @parameters:
--! ... - various parameters and self
--! @return: self and other parameters
--]]
function m.getSelfAndParams(...)
  local out = { }
  local selfIdx = nil
  for i,v in pairs({...}) do
    if type(v) == "table" and v.isTest then
      table.insert(out, v)
      selfIdx = i
      break
    end
  end
  local idx = 2
  for i = 1, table.maxn({...}) do
    if i ~= selfIdx then
      out[idx] = ({...})[i]
      idx = idx + 1
    end
  end
  return table.unpack(out, 1, table.maxn(out))
end

--[[ @getHMIAppId: get HMI application identifier
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: application identifier
--]]
function m.getHMIAppId(pAppId)
  if not pAppId then pAppId = 1 end
  return hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
end

--[[ @getMobileSession: get mobile session
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! self - test object
--! @return: mobile session
--]]
function m.getMobileSession(pAppId, self)
  if not pAppId then pAppId = 1 end
  return self["mobileSession" .. pAppId]
end

--[[ @registerApp: register mobile application
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! self - test object
--]]
function m.registerApp(pAppId, self)
  self, pAppId = m.getSelfAndParams(pAppId, self)
  if not pAppId then pAppId = 1 end
  local mobSession = m.getMobileSession(pAppId, self)
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
function m.activateApp(pAppId, self)
  self, pAppId = m.getSelfAndParams(pAppId, self)
  if not pAppId then pAppId = 1 end
  local pHMIAppId = hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
  local mobSession = m.getMobileSession(pAppId, self)
  local requestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = pHMIAppId })
  EXPECT_HMIRESPONSE(requestId)
  mobSession:ExpectNotification("OnHMIStatus",
    { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
  commonTestCases:DelayedExp(m.minTimeout)
end

--[[ @allowSDL: sequence that allows SDL functionality
--! @parameters:
--! self - test object
--]]
local function allowSDL(self)
  self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
    { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = "127.0.0.1" } })
end

--[[ @start: starting sequence: starting of SDL, initialization of HMI, connect mobile
--! @parameters:
--! pHMIParams - table with parameters for HMI initialization
--! self - test object
--]]
function m.start(pHMIParams, self)
  self, pHMIParams = m.getSelfAndParams(pHMIParams, self)
  self:runSDL()
  commonFunctions:waitForSDLStart(self)
  :Do(function()
      self:initHMI(self)
      :Do(function()
          commonFunctions:userPrint(35, "HMI initialized")
          self:initHMI_onReady(pHMIParams)
          :Do(function()
              commonFunctions:userPrint(35, "HMI is ready")
              self:connectMobile()
              :Do(function()
                  commonFunctions:userPrint(35, "Mobile connected")
                  allowSDL(self)
                end)
            end)
        end)
    end)
end

function m.startMobileSession(pAppId, self)
  self, pAppId = m.getSelfAndParams(pAppId, self)
  if not pAppId then pAppId = 1 end
  self["mobileSession" .. pAppId] = mobile_session.MobileSession(self, self.mobileConnection)
end

function m.sendControlMessage(pAppId, pServiceId, pFrameInfo, pPayload, self)
  self, pPayload = m.getSelfAndParams(pPayload, self)
  local mobSession = m.getMobileSession(pAppId, self)
  local payload = nil
  if pPayload then payload = bson.to_bytes(pPayload) end
  local binaryData = nil
  if pFrameInfo == constants.FRAME_INFO.END_SERVICE then
    binaryData = mobSession.mobile_session_impl.hashCode
  end
  local msg = {
    frameType = constants.FRAME_TYPE.CONTROL_FRAME,
    frameInfo = pFrameInfo,
    serviceType = pServiceId,
    payload = payload,
    binaryData = binaryData
  }
  mobSession.mobile_session_impl:Send(msg)
end

function m.expectControlMessage(pAppId, pServiceId, pFrameInfo, pPayload, self)
  self, pPayload = m.getSelfAndParams(pPayload, self)
  if not pPayload then pPayload = { } end
  local mobSession = m.getMobileSession(pAppId, self)
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
        mobSession.mobile_session_impl.hashCode = data.binaryData
      end
    end)
  :ValidIf(function(_, data)
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
      -- commonFunctions:printTable(pPayload)
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
