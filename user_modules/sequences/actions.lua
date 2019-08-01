---------------------------------------------------------------------------------------------------
-- Common actions module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local mobileSession = require("mobile_session")
local json = require("modules/json")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local events = require("events")
local test = require("user_modules/dummy_connecttest")
local expectations = require('expectations')
local reporter = require("reporter")
local utils = require("user_modules/utils")
local sdl = require("SDL")

--[[ Module ]]
local m = {}

--[[ Constants ]]
m.minTimeout = 500

--[[ Variables ]]
local hmiAppIds = {}
local originalValuesInSDLIni = {}
local policyModes = {
  P  = "PROPRIETARY",
  EP = "EXTERNAL_PROPRIETARY",
  H  = "HTTP"
}
local ptuAppNum

test.mobileSession = {}

--[[ Functions ]]

--[[ @getPTUFromPTS: create policy table update table (PTU)
--! @parameters:
--! pTbl - table with policy table snapshot (PTS)
--! @return: table with PTU
--]]
local function getPTUFromPTS()
  local pTbl = {}
  local ptsFileName = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath") .. "/"
    .. commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
  if utils.isFileExist(ptsFileName) then
    pTbl = utils.jsonFileToTable(ptsFileName)
  else
    utils.cprint(35, "PTS file was not found, PreloadedPT is used instead")
    local appConfigFolder = commonFunctions:read_parameter_from_smart_device_link_ini("AppConfigFolder")
    if appConfigFolder == nil or appConfigFolder == "" then
      appConfigFolder = commonPreconditions:GetPathToSDL()
    end
    local preloadedPT = commonFunctions:read_parameter_from_smart_device_link_ini("PreloadedPT")
    local ptsFile = appConfigFolder .. preloadedPT
    if utils.isFileExist(ptsFile) then
      pTbl = utils.jsonFileToTable(ptsFile)
    else
      utils.cprint(35, "PreloadedPT was not found, PTS is not created")
    end
  end
  if next(pTbl) ~= nil then
    pTbl.policy_table.consumer_friendly_messages = nil
    pTbl.policy_table.device_data = nil
    pTbl.policy_table.module_meta = nil
    pTbl.policy_table.usage_and_error_counts = nil
    pTbl.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
    pTbl.policy_table.module_config.preloaded_pt = nil
    pTbl.policy_table.module_config.preloaded_date = nil
  end
  return pTbl
end

--[[ @getAppDataForPTU: provide application data for PTU
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
function m.getAppDataForPTU(pAppId)
  return {
    keep_context = false,
    steal_focus = false,
    priority = "NONE",
    default_hmi = "NONE",
    groups = { "Base-4", "Location-1" },
    AppHMIType = m.getConfigAppParams(pAppId).appHMIType
  }
end

local function policyTableUpdateProprietary(pPTUpdateFunc, pExpNotificationFunc)
  local ptsFileName = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath") .. "/"
    .. commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
  local ptuFileName = os.tmpname()
  local requestId = m.getHMIConnection():SendRequest("SDL.GetURLS", { service = 7 })
  m.getHMIConnection():ExpectResponse(requestId)
  :Do(function()
      m.getHMIConnection():SendNotification("BasicCommunication.OnSystemRequest",
        { requestType = "PROPRIETARY", fileName = ptsFileName })
      local ptuTable = getPTUFromPTS()
      for i = 1, m.getAppsCount() do
        ptuTable.policy_table.app_policies[m.getConfigAppParams(i).fullAppID] = m.getAppDataForPTU(i)
      end
      if pPTUpdateFunc then
        pPTUpdateFunc(ptuTable)
      end
      utils.tableToJsonFile(ptuTable, ptuFileName)
      local event = events.Event()
      event.matches = function(e1, e2) return e1 == e2 end
      m.getHMIConnection():ExpectEvent(event, "PTU event")
      for id = 1, m.getAppsCount() do
        m.getMobileSession(id):ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
        :Do(function()
            m.getHMIConnection():ExpectRequest("BasicCommunication.SystemRequest")
            :Do(function(_, d3)
                if not pExpNotificationFunc then
                  m.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
                  m.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate", { status = "UP_TO_DATE" })
                end
                m.getHMIConnection():SendResponse(d3.id, "BasicCommunication.SystemRequest", "SUCCESS", { })
                m.getHMIConnection():SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = d3.params.fileName })
              end)
            utils.cprint(35, "App ".. id .. " was used for PTU")
            m.getHMIConnection():RaiseEvent(event, "PTU event")
            local corIdSystemRequest = m.getMobileSession(id):SendRPC("SystemRequest", {
              requestType = "PROPRIETARY" }, ptuFileName)
            m.getMobileSession(id):ExpectResponse(corIdSystemRequest, { success = true, resultCode = "SUCCESS" })
            :Do(function() os.remove(ptuFileName) end)
          end)
        :Times(AtMost(1))
      end
    end)
end

local function policyTableUpdateHttp(pPTUpdateFunc, pExpNotificationFunc)
  local ptuFileName = os.tmpname()
  local ptuTable = getPTUFromPTS()
  for i = 1, m.getAppsCount() do
    ptuTable.policy_table.app_policies[m.getConfigAppParams(i).fullAppID] = m.getAppDataForPTU(i)
  end
  if pPTUpdateFunc then
    pPTUpdateFunc(ptuTable)
  end
  utils.tableToJsonFile(ptuTable, ptuFileName)
  local cid = m.getMobileSession(ptuAppNum):SendRPC("SystemRequest",
    { requestType = "HTTP", fileName = "PolicyTableUpdate" }, ptuFileName)
  if not pExpNotificationFunc then
    m.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
    m.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate", { status = "UP_TO_DATE" })
  end
  m.getMobileSession(ptuAppNum):ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  :Do(function() os.remove(ptuFileName) end)
end
--[[ @policyTableUpdate: perform PTU
--! @parameters:
--! pPTUpdateFunc - function with additional updates (optional)
--! pExpNotificationFunc - function with specific expectations (optional)
--! @return: none
--]]
function m.policyTableUpdate(pPTUpdateFunc, pExpNotificationFunc)
  if pExpNotificationFunc then
    pExpNotificationFunc()
  end
  local policyMode = sdl.buildOptions.extendedPolicy
  if policyMode == policyModes.P or policyMode == policyModes.EP then
    policyTableUpdateProprietary(pPTUpdateFunc, pExpNotificationFunc)
  elseif policyMode == policyModes.H then
    policyTableUpdateHttp(pPTUpdateFunc, pExpNotificationFunc)
  end
end

--[[ @allowSDL: allow SDL functionality for default device
--! @parameters: none
--! @return: none
--]]
local function allowSDL()
  local event = events.Event()
  event.matches = function(e1, e2) return e1 == e2 end
  m.getHMIConnection():SendNotification("SDL.OnAllowSDLFunctionality", {
    allowed = true,
    source = "GUI",
    device = {
      id = utils.getDeviceMAC(),
      name = utils.getDeviceName()
    }
  })
  RUN_AFTER(function() m.getHMIConnection():RaiseEvent(event, "Allow SDL event") end, 500)
  return m.getHMIConnection():ExpectEvent(event, "Allow SDL event")
end

--[[ @getConfigAppParams: return app's configuration from defined in config file
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: application identifier from configuration file
--]]
function m.getConfigAppParams(pAppId)
  if not pAppId then pAppId = 1 end
  return config["application" .. pAppId].registerAppInterfaceParams
end

--[[ @preconditions: precondition steps
--! @parameters: none
--! @return: none
--]]
function m.preconditions()
  commonFunctions:SDLForceStop()
  commonSteps:DeletePolicyTable()
  commonSteps:DeleteLogsFiles()
end

--[[ @activateApp: activate application
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
function m.activateApp(pAppId)
  if not pAppId then pAppId = 1 end
  local requestId = m.getHMIConnection():SendRequest("SDL.ActivateApp", { appID = m.getHMIAppId(pAppId) })
  m.getHMIConnection():ExpectResponse(requestId)
  m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus",
    { hmiLevel = "FULL", systemContext = "MAIN" })
  local function getRegisteredSessionIds()
    local out = {}
    for k in pairs(test.mobileSession) do
      table.insert(out, k)
    end
    return out
  end
  if #getRegisteredSessionIds() > 1 then
    utils.wait(500)
  end
end

--[[ @getHMIAppId: get HMI application identifier
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: application identifier
--]]
function m.getHMIAppId(pAppId)
  if not pAppId then pAppId = 1 end
  return hmiAppIds[m.getConfigAppParams(pAppId).fullAppID]
end

--[[ @getMobileSession: get mobile session
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: mobile session object
--]]
function m.getMobileSession(pAppId)
  if not pAppId then pAppId = 1 end
  local session
  if not test.mobileSession[pAppId] then
    session = mobileSession.MobileSession(test, test.mobileConnection)
    test.mobileSession[pAppId] = session
    if config.defaultProtocolVersion > 2 then
      session.activateHeartbeat = true
      session.sendHeartbeatToSDL = true
      session.answerHeartbeatFromSDL = true
      session.ignoreSDLHeartBeatACK = true
    end
  else
    session = test.mobileSession[pAppId]
  end
  return session
end

function m.isPTUStarted()
  local event = events.Event()
  event.matches = function(e1, e2) return e1 == e2 end
  local function raisePtuEvent()
    RUN_AFTER(function() m.getHMIConnection():RaiseEvent(event, "PTU start event") end, m.minTimeout)
  end
  local policyMode = sdl.buildOptions.extendedPolicy
  if policyMode == policyModes.P or policyMode == policyModes.EP then
    m.getHMIConnection():ExpectRequest("BasicCommunication.PolicyUpdate")
    :Do(function(_, d2)
        m.getHMIConnection():SendResponse(d2.id, d2.method, "SUCCESS", { })
        raisePtuEvent()
      end)
  elseif policyMode == policyModes.H then
    local function getAppNums()
      local out = {}
        for k in pairs(test.mobileSession) do
          table.insert(out, k)
        end
      return out
    end
    for _, appNum in pairs(getAppNums()) do
      m.getMobileSession(appNum):ExpectNotification("OnSystemRequest")
      :Do(function(_, d3)
          if d3.payload.requestType == "HTTP" then
            utils.cprint(35, "App ".. appNum .. " will be used for PTU")
            ptuAppNum = appNum
            raisePtuEvent()
          end
        end)
      :Times(AtMost(2))
    end
  end
  return m.getHMIConnection():ExpectEvent(event, "PTU start event")
end

--[[ @registerApp: register mobile application
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
function m.registerApp(pAppId)
  if not pAppId then pAppId = 1 end
  m.getMobileSession(pAppId):StartService(7)
  :Do(function()
      local corId = m.getMobileSession(pAppId):SendRPC("RegisterAppInterface", m.getConfigAppParams(pAppId))
      m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered",
        { application = { appName = m.getConfigAppParams(pAppId).appName } })
      :Do(function(_, d1)
          m.setHMIAppId(d1.params.application.appID, pAppId)
          m.isPTUStarted()
        end)
      m.getMobileSession(pAppId):ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
          m.getMobileSession(pAppId):ExpectNotification("OnPermissionsChange")
          :Times(AnyNumber())
        end)
    end)
end

--[[ @registerAppWOPTU: register mobile application and do not perform PTU
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
function m.registerAppWOPTU(pAppId)
  if not pAppId then pAppId = 1 end
  m.getMobileSession(pAppId):StartService(7)
  :Do(function()
      local corId = m.getMobileSession(pAppId):SendRPC("RegisterAppInterface", m.getConfigAppParams(pAppId))
      m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered",
        { application = { appName = m.getConfigAppParams(pAppId).appName } })
      :Do(function(_, d1)
          hmiAppIds[m.getConfigAppParams(pAppId).fullAppID] = d1.params.application.appID
        end)
      m.getMobileSession(pAppId):ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
          m.getMobileSession(pAppId):ExpectNotification("OnPermissionsChange")
        end)
    end)
end

--[[ @start: starting sequence: starting of SDL, initialization of HMI, connect mobile
--! @parameters:
--! pHMIParams - table with parameters for HMI initialization
--! @return: none
--]]
function m.start(pHMIParams)
  local event = events.Event()
  event.matches = function(e1, e2) return e1 == e2 end
  test:runSDL()
  commonFunctions:waitForSDLStart(test)
  :Do(function()
      test:initHMI()
      :Do(function()
          utils.cprint(35, "HMI initialized")
          test:initHMI_onReady(pHMIParams)
          :Do(function()
              utils.cprint(35, "HMI is ready")
              test:connectMobile()
              :Do(function()
                  utils.cprint(35, "Mobile connected")
                  allowSDL()
                  :Do(function()
                      m.getHMIConnection():RaiseEvent(event, "Start event")
                    end)
                end)
            end)
        end)
    end)
  return m.getHMIConnection():ExpectEvent(event, "Start event")
end

--[[ @ExpectRequest: register expectation for request on HMI connection
--! @parameters:
--! pName - name of the request
--! ... - expected data
--! @return: Expectation object
--]]
function test.hmiConnection:ExpectRequest(pName, ...)
  local event = events.Event()
  event.matches = function(_, data) return data.method == pName end
  local args = table.pack(...)
  local ret = expectations.Expectation("HMI call " .. pName, self)
  if #args > 0 then
    ret:ValidIf(function(e, data)
        local arguments
        if e.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[e.occurences]
        end
        reporter.AddMessage("EXPECT_HMICALL",
          { ["Id"] = data.id, ["name"] = tostring(pName),["Type"] = "EXPECTED_RESULT" }, arguments)
        reporter.AddMessage("EXPECT_HMICALL",
          { ["Id"] = data.id, ["name"] = tostring(pName),["Type"] = "AVAILABLE_RESULT" }, data.params)
        return compareValues(arguments, data.params, "params")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(self, event, ret)
  test:AddExpectation(ret)
  return ret
end

--[[ @ExpectNotification: register expectation for notification on HMI connection
--! @parameters:
--! pName - name of the notification
--! ... - expected data
--! @return: Expectation object
--]]
function test.hmiConnection:ExpectNotification(pName, ...)
  local event = events.Event()
  event.matches = function(_, data) return data.method == pName end
  local args = table.pack(...)
  local ret = expectations.Expectation("HMI notification " .. pName, self)
  if #args > 0 then
    ret:ValidIf(function(e, data)
        local arguments
        if e.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[e.occurences]
        end
        local cid = test.notification_counter
        test.notification_counter = test.notification_counter + 1
        reporter.AddMessage("EXPECT_HMINOTIFICATION",
          { ["Id"] = cid, ["name"] = tostring(pName), ["Type"] = "EXPECTED_RESULT" }, arguments)
        reporter.AddMessage("EXPECT_HMINOTIFICATION",
          { ["Id"] = cid, ["name"] = tostring(pName), ["Type"] = "AVAILABLE_RESULT" }, data.params)
        return compareValues(arguments, data.params, "params")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(self, event, ret)
  test:AddExpectation(ret)
  return ret
end

--[[ @ExpectResponse: register expectation for notification on HMI connection
--! @parameters:
--! pName - name of the notification
--! ... - expected data
--! @return: Expectation object
--]]
function test.hmiConnection:ExpectResponse(pId, ...)
  local event = events.Event()
  event.matches = function(_, data) return data.id == pId end
  local args = table.pack(...)
  local ret = expectations.Expectation("HMI response " .. pId, self)
  if #args > 0 then
    ret:ValidIf(function(e, data)
        local arguments
        if e.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[e.occurences]
        end
        reporter.AddMessage("EXPECT_HMIRESPONSE", { ["Id"] = data.id, ["Type"] = "EXPECTED_RESULT" }, arguments)
        reporter.AddMessage("EXPECT_HMIRESPONSE", { ["Id"] = data.id, ["Type"] = "AVAILABLE_RESULT" }, data.result)
        return compareValues(arguments, data, "data")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(self, event, ret)
  test:AddExpectation(ret)
  return ret
end

function test.hmiConnection:RaiseEvent(pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
  reporter.AddMessage(debug.getinfo(1, "n").name, pEventName)
  event_dispatcher:RaiseEvent(self, pEvent)
end

function test.hmiConnection:ExpectEvent(pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
  local ret = expectations.Expectation(pEventName, self)
  ret.event = pEvent
  event_dispatcher:AddEvent(self, pEvent, ret)
  test:AddExpectation(ret)
  return ret
end

function test.mobileConnection:RaiseEvent(pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
    reporter.AddMessage(debug.getinfo(1, "n").name, pEventName)
    event_dispatcher:RaiseEvent(self, pEvent)
end

function test.mobileConnection:ExpectEvent(pEvent, pEventName)
  if pEventName == nil then pEventName = "noname" end
  local ret = expectations.Expectation(pEventName, self)
  ret.event = pEvent
  event_dispatcher:AddEvent(self, pEvent, ret)
  test:AddExpectation(ret)
  return ret
end

--[[ @getMobileConnection: return Mobile connection object
--! @parameters: none
--! @return: Mobile connection object
--]]
function m.getMobileConnection()
  return test.mobileConnection
end

--[[ @getHMIConnection: return HMI connection object
--! @parameters: none
--! @return: HMI connection object
--]]
function m.getHMIConnection()
  return test.hmiConnection
end

--[[ @setSDLConfigParameter: change original value of parameter in SDL .ini file
--! @parameters:
--! pParamName - name of the parameter
--! pParamValue - value to be set
--! @return: none
--]]
function m.setSDLIniParameter(pParamName, pParamValue)
  originalValuesInSDLIni[pParamName] = commonFunctions:read_parameter_from_smart_device_link_ini(pParamName)
  commonFunctions:write_parameter_to_smart_device_link_ini(pParamName, pParamValue)
end

--[[ @restoreSDLConfigParameters: restore original values of parameters in SDL .ini file
--! @parameters: none
--! @return: none
--]]
function m.restoreSDLIniParameters()
  for pParamName, pParamValue in pairs(originalValuesInSDLIni) do
    commonFunctions:write_parameter_to_smart_device_link_ini(pParamName, pParamValue)
  end
end

--[[ @postconditions: postcondition steps
--! @parameters: none
--! @return: none
--]]
function m.postconditions()
  StopSDL()
  m.restoreSDLIniParameters()
end

--[[ @getAppsCount: provide count of registered applications
--! @parameters: none
--! @return: count of apps
--]]
function m.getAppsCount()
  return #test.mobileSession
end

--[[ @getPathToFileInStorage: full path to file in storage folder
--! @parameters:
--! @pFileName - file name
--! @pAppId - application number (1, 2, etc.)
--! @return: path
--]]
function m.getPathToFileInStorage(pFileName, pAppId)
  if not pAppId then pAppId = 1 end
  return commonPreconditions:GetPathToSDL() .. "storage/" .. m.getConfigAppParams( pAppId ).fullAppID .. "_"
    .. utils.getDeviceMAC() .. "/" .. pFileName
end

--[[ @setHMIAppId: set HMI application identifier
--! @parameters:
--! pHMIAppId - HMI application identifier
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
function m.setHMIAppId(pHMIAppId, pAppId)
  if not pAppId then pAppId = 1 end
  hmiAppIds[m.getConfigAppParams(pAppId).fullAppID] = pHMIAppId
end

--[[ @getHMIAppIds: return array of all HMI application identifiers
--! @parameters: none
--! @return: array of all HMI application identifiers
--]]
function m.getHMIAppIds()
  return hmiAppIds
end

--[[ @deleteHMIAppId: remove HMI application identifier
--! @parameters:
--! pAppId - application number (1, 2, etc.)
--! @return: none
--]]
function m.deleteHMIAppId(pAppId)
  hmiAppIds[m.getConfigAppParams(pAppId).fullAppID] = nil
end

return m
