---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local sslCommon = require("test_scripts/Security/SSLHandshakeFlow/common")
local utils = require("user_modules/utils")
local test = require("user_modules/dummy_connecttest")
local events = require('events')
local constants = require('protocol_handler/ford_protocol_constants')

--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2
config.SecurityProtocol = "DTLS"
config.application1.registerAppInterfaceParams.fullAppID = "spt"
constants.FRAME_SIZE["P2"] = 1400

--[[ Variables ]]
local m = actions

m.cloneTable = utils.cloneTable
m.spairs = utils.spairs
m.cprint = utils.cprint
m.wait = utils.wait

--[[ Common Functions ]]
function m.updatePreloadedPT(pAppPolicy, pFuncGroup)
  local function pPTUpdateFunc(pPT)
    pPT.policy_table.functional_groupings["Base-4"].encryption_required = pFuncGroup
    pPT.policy_table.app_policies["spt"] = utils.cloneTable(pPT.policy_table.app_policies.default)
    pPT.policy_table.app_policies["spt"].encryption_required = pAppPolicy
  end
  m.preloadedPTUpdate(pPTUpdateFunc)
end

function m.getAddCommandParams(pCmdId)
  return {
    cmdID = pCmdId,
    menuParams = {
      position = pCmdId,
      menuName = "Command_" .. pCmdId
    }
  }
end

function m.unprotectedRpcInUnprotectedModeSuccess()
  local cid = m.getMobileSession():SendRPC("AddCommand", m.getAddCommandParams(1))
  m.getHMIConnection():ExpectRequest("UI.AddCommand", m.getAddCommandParams(1))
  :Do(function(_, data)
      m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
    end)
  m.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  m.getMobileSession():ExpectNotification("OnHashChange")
end

function m.switchRPCServiceToProtected()
  local serviceId = 7
  m.getMobileSession():StartSecureService(serviceId)
  m.getMobileSession():ExpectHandshakeMessage()
  m.getMobileSession():ExpectControlMessage(serviceId, {
    frameInfo = m.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
end

function m.spairs(pTbl)
  local keys = {}
  for k in pairs(pTbl) do
    keys[#keys+1] = k
  end
  local function getStringKey(pKey)
    return tostring(string.format("%03d", pKey))
  end
  table.sort(keys, function(a, b) return getStringKey(a) < getStringKey(b) end)
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], pTbl[keys[i]]
    end
  end
end

function m.cleanSessions()
  for i = 1, m.getAppsCount() do
    test.mobileSession[i]:StopRPC()
    :Do(function(_, d)
        utils.cprint(35, "Mobile session " .. d.sessionId .. " deleted")
        test.mobileSession[i] = nil
      end)
  end
  utils.wait()
end

function m.ignitionOff()
  config.ExitOnCrash = false
  local timeout = 5000
  local function removeSessions()
    for i = 1, m.getAppsCount() do
      test.mobileSession[i] = nil
    end
  end
  local event = events.Event()
  event.matches = function(event1, event2) return event1 == event2 end
  EXPECT_EVENT(event, "SDL shutdown")
  :Do(function()
      removeSessions()
      StopSDL()
      config.ExitOnCrash = true
    end)
  m.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications", { reason = "SUSPEND" })
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnSDLPersistenceComplete")
  :Do(function()
      m.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications",{ reason = "IGNITION_OFF" })
      for i = 1, m.getAppsCount() do
        m.getMobileSession(i):ExpectNotification("OnAppInterfaceUnregistered", { reason = "IGNITION_OFF" })
      end
    end)
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered", { unexpectedDisconnect = false })
  :Times(m.getAppsCount())
  local isSDLShutDownSuccessfully = false
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnSDLClose")
  :Do(function()
      utils.cprint(35, "SDL was shutdown successfully")
      isSDLShutDownSuccessfully = true
      RAISE_EVENT(event, event)
    end)
  :Timeout(timeout)
  local function forceStopSDL()
    if isSDLShutDownSuccessfully == false then
      utils.cprint(35, "SDL was shutdown forcibly")
      RAISE_EVENT(event, event)
    end
  end
  RUN_AFTER(forceStopSDL, timeout + 500)
end

function m.reRegisterAppSuccess(pAppId)
  if not pAppId then pAppId = 1 end
  local mobSession = m.getMobileSession(pAppId)
  mobSession:StartService(7)
  :Do(function()
      local params = utils.cloneTable(m.getConfigAppParams(pAppId))
      local corId = mobSession:SendRPC("RegisterAppInterface", params)
      m.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered", {
          application = { appName = m.getConfigAppParams(pAppId).appName }
        })
      mobSession:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          mobSession:ExpectNotification("OnPermissionsChange")
        end)
    end)
end

local preconditionsOrig = m.preconditions
function m.preconditions(ptUpdateFunc)
  preconditionsOrig(ptUpdateFunc)
  sslCommon.initSDLCertificates("./files/Security/client_credential.pem")
end

function m.subscribeToVD()
  local cid = m.getMobileSession():SendRPC("SubscribeVehicleData", { speed = true })
  m.getHMIConnection():ExpectRequest("VehicleInfo.SubscribeVehicleData", { speed = true })
  :Do(function(_, data)
      m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {
        gps = { dataType = "VEHICLEDATA_GPS", resultCode = "SUCCESS" }})
    end)
  m.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS"})
end

function m.printFailedTCs(pFailedTCs)
  for tc, msg in m.spairs(pFailedTCs) do
    local e = string.find(msg, "\n")
    if e > 80 then e = 80 end
    m.cprint(35, string.format("%03d", tc), string.sub(msg, 1, e - 1) .. " ...")
  end
end

function m.getExp(pApp, pFG)
  local app = pApp
  local fg = nil
  if pFG == true and pApp ~= false then fg = true end
  return app, fg
end

function m.getTransitions(pStates, pStart, pFinish)
  local out = {}
  for i = 1, #pStates do
    for j = 1, #pStates do
      table.insert(out, { from = i, to = j })
    end
  end
  for i = 1, #out do
    if i < pStart or i > pFinish then out[i] = nil end
  end
  return out
end

return m
