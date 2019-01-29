---------------------------------------------------------------------------------------------------
-- Smoke API common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local test = require("user_modules/dummy_connecttest")
local utils = require('user_modules/utils')
local json = require("modules/json")

local mobileSession = require("mobile_session")
local mobileConnection  = require('mobile_connection')
local SDL = require("SDL")
local tcp = require('tcp_connection')
local file_connection  = require('file_connection')
local events = require("events")
local constants = require('protocol_handler/ford_protocol_constants')
local expectations = require('expectations')
local atf_logger = require("atf_logger")

--[[ Module ]]
local common = require('user_modules/sequences/actions')

--[[ Mapped functions and constants ]]
common.cloneTable = utils.cloneTable
common.tableToString = utils.tableToString
common.getDeviceName = utils.getDeviceName
common.getDeviceMAC = utils.getDeviceMAC
common.wait = utils.wait
common.cprint = utils.cprint
common.cprintTable = utils.cprintTable
common.tableToJsonFile = utils.tableToJsonFile
common.jsonFileToTable = utils.jsonFileToTable
common.constants = constants
common.json = { decode = json.decode, null = json.null }
common.events = { disconnectedEvent = events.disconnectedEvent }
common.SDL = { buildOptions = SDL.buildOptions }

--[[ Module constants ]]
common.timeout = 4000

--[[ Module functions ]]
function common.runAfter(pFunc, pDelay)
  RUN_AFTER(pFunc, pDelay)
end

function common.failTestCase(pMsg)
  test:FailTestCase(pMsg)
end

function common.readParameterFromSDLINI(pParamName)
  return SDL.INI.get(pParamName)
end

function common.log(...)
  local str = "[" .. atf_logger.formated_time(true) .. "]"
  for i, p in pairs({...}) do
    local delimiter = "\t"
    if i == 1 then delimiter = " " end
    str = str .. delimiter .. p
  end
  utils.cprint(35, str)
end

--[[ Local Variables ]]
local isPreloadedUpdated = false

function common.postconditions()
  if SDL:CheckStatusSDL() == SDL.RUNNING then SDL:StopSDL() end
  common.restoreSDLIniParameters()
  if isPreloadedUpdated == true then SDL.PreloadedPT.restore() end
end

function common.updatePreloadedPT()
  isPreloadedUpdated = true
  SDL.PreloadedPT.backup()
  local pt = SDL.PreloadedPT.get()
  pt.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  local additionalRPCs = {
    "SendLocation", "SubscribeVehicleData", "UnsubscribeVehicleData", "GetVehicleData", "UpdateTurnList",
    "AlertManeuver", "DialNumber", "ReadDID", "GetDTCs", "ShowConstantTBT"
  }
  pt.policy_table.functional_groupings.NewTestCaseGroup = { rpcs = { } }
  for _, v in pairs(additionalRPCs) do
    pt.policy_table.functional_groupings.NewTestCaseGroup.rpcs[v] = {
      hmi_levels = { "BACKGROUND", "FULL", "LIMITED" }
    }
  end
  pt.policy_table.app_policies["0000001"] = utils.cloneTable(pt.policy_table.app_policies.default)
  pt.policy_table.app_policies["0000001"].groups = { "Base-4", "NewTestCaseGroup" }
  pt.policy_table.app_policies["0000001"].keep_context = true
  pt.policy_table.app_policies["0000001"].steal_focus = true
  SDL.PreloadedPT.set(pt)
end

function common.createMobileSession(pAppId, pHBParams, pConId)
  if not pAppId then pAppId = 1 end
  if not pHBParams then pHBParams = {} end
  local connection = test.mobileConnection
  if pConId then
    connection = test.mobileConnection[pConId]
  end
  test.mobileSession[pAppId] = mobileSession.MobileSession(test, connection)
  for k, v in pairs(pHBParams) do
    test.mobileSession[pAppId][k] = v
  end
end

function common.getMobileSession(pAppId)
  if not pAppId then pAppId = 1 end
  return test.mobileSession[pAppId]
end

function common.putFile(pParams)
  local cid = common.getMobileSession():SendRPC("PutFile", pParams.requestParams, pParams.filePath)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

function common.registerApp(pAppId, pHBParams)
  common.createMobileSession(pAppId, pHBParams)
  common.getMobileSession(pAppId):ExpectNotification("OnDriverDistraction", { state = "DD_OFF" })
  common.registerAppWOPTU(pAppId)
end

function common.getPathToFileInAppStorage(pFileName, pAppId)
  return SDL.AppStorage.path() .. common.getConfigAppParams(pAppId).fullAppID .. "_"
    .. utils.getDeviceMAC() .. "/" .. pFileName
end

function common.isFileExistInAppStorage(pFileName)
  return SDL.AppStorage.isFileExist(pFileName)
end

function common.unRegisterApp(pAppId)
  if pAppId == nil then pAppId = 1 end
  local cid = common.getMobileSession(pAppId):SendRPC("UnregisterAppInterface", {})
  common.getMobileSession(pAppId):ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  :Do(function()
      common.deleteMobileSession(pAppId)
    end)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered",
    { unexpectedDisconnect = false, appID = common.getHMIAppId(pAppId) })
  :Do(function()
      common.setHMIAppId(nil, pAppId)
    end)
end

function common.reRegisterApp(pResultCode, pExpResDataFunc, pExpResLvlFunc)
  common.createMobileSession()
  local params = common.cloneTable(common.getConfigAppParams())
  params.hashID = common.hashId
  common.getMobileSession():StartService(7)
  :Do(function()
      if pExpResDataFunc then pExpResDataFunc() end
      if pExpResLvlFunc then pExpResLvlFunc() end
      local cid = common.getMobileSession():SendRPC("RegisterAppInterface", params)
      common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered")
      common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = pResultCode })
      :Do(function()
          common.getMobileSession():ExpectNotification("OnPermissionsChange")
          :Times(AnyNumber())
        end)
    end)
  common.wait(common.timeout)
end

function common.deleteMobileSession(pAppId)
  if pAppId == nil then pAppId = 1 end
  common.getMobileSession(pAppId):Stop()
  :Do(function()
      test.mobileSession[pAppId] = nil
    end)
end

function test.mobileConnection:Close()
  for i = 1, common.getAppsCount() do
    test.mobileSession[i] = nil
  end
  self.connection:Close()
end

common.resParams = {
  AddCommand = {
    mob = { cmdID = 1, vrCommands = { "OnlyVRCommand" }},
    hmi = { cmdID = 1, type = "Command", vrCommands = { "OnlyVRCommand" }}
  },
  AddSubMenu = {
    mob = { menuID = 1, position = 500, menuName = "SubMenu" },
    hmi = { menuID = 1, menuParams = { position = 500, menuName = "SubMenu" }}
  }
}

function common.addCommand()
  local cid = common.getMobileSession():SendRPC("AddCommand", common.resParams.AddCommand.mob)
  common.getHMIConnection():ExpectRequest("VR.AddCommand", common.resParams.AddCommand.hmi)
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getMobileSession():ExpectNotification("OnHashChange")
  :Do(function(_, data)
      common.hashId = data.payload.hashID
    end)
end

function common.addSubMenu()
  local cid = common.getMobileSession():SendRPC("AddSubMenu", common.resParams.AddSubMenu.mob)
  common.getHMIConnection():ExpectRequest("UI.AddSubMenu", common.resParams.AddSubMenu.hmi)
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getMobileSession():ExpectNotification("OnHashChange")
  :Do(function(_, data)
      common.hashId = data.payload.hashID
    end)
end

function common.ignitionOff(pExpFunc)
  local isOnSDLCloseSent = false
  if pExpFunc then pExpFunc() end
  common.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications", { reason = "SUSPEND" })
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnSDLPersistenceComplete")
  :Do(function()
      common.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications", { reason = "IGNITION_OFF" })
      common.getHMIConnection():ExpectNotification("BasicCommunication.OnSDLClose")
      :Do(function()
          isOnSDLCloseSent = true
          SDL.DeleteFile()
        end)
      :Times(AtMost(1))
    end)
  common.wait(3000)
  :Do(function()
      if isOnSDLCloseSent == false then common.cprint(35, "BC.OnSDLClose was not sent") end
      if SDL:CheckStatusSDL() == SDL.RUNNING then SDL:StopSDL() end
      common.getMobileConnection():Close()
    end)
end

function common.masterReset(pExpFunc)
  local isOnSDLCloseSent = false
  if pExpFunc then pExpFunc() end
  common.getHMIConnection():SendNotification("BasicCommunication.OnExitAllApplications", { reason = "MASTER_RESET" })
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnSDLClose")
  :Do(function()
      isOnSDLCloseSent = true
      SDL.DeleteFile()
    end)
  :Times(AtMost(1))
  common.wait(3000)
  :Do(function()
      if isOnSDLCloseSent == false then common.cprint(35, "BC.OnSDLClose was not sent") end
      if SDL:CheckStatusSDL() == SDL.RUNNING then SDL:StopSDL() end
      common.getMobileConnection():Close()
    end)
end

function common.unexpectedDisconnect(pAppId)
  if pAppId == nil then pAppId = 1 end
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered",
    { unexpectedDisconnect = true, appID = common.getHMIAppId(pAppId) })
  common.deleteMobileSession(pAppId)
end

function common.createEvent(pMatchFunc)
  if pMatchFunc == nil then
    pMatchFunc = function(e1, e2) return e1 == e2 end
  end
  local event = events.Event()
  event.matches = pMatchFunc
  return event
end

function common.createConnection(pConId, pDevices)
  if pConId == nil then pConId = 1 end
  if pDevices == nil then pDevices = { [1] = config.mobileHost } end
  local filename = "mobile" .. pConId .. ".out"
  local tcpConnection = tcp.Connection(pDevices[pConId], config.mobilePort)
  local fileConnection = file_connection.FileConnection(filename, tcpConnection)
  local connection = mobileConnection.MobileConnection(fileConnection)
  test.mobileConnection[pConId] = connection
  function connection:ExpectEvent(pEvent, pEventName)
    if pEventName == nil then pEventName = "noname" end
    local ret = expectations.Expectation(pEventName, self)
    ret.event = pEvent
    event_dispatcher:AddEvent(self, pEvent, ret)
    test:AddExpectation(ret)
    return ret
  end
  event_dispatcher:AddConnection(connection)
  local ret = connection:ExpectEvent(events.connectedEvent, "Connection started")
  ret:Do(function()
      common.cprint(35, "Mobile #" .. pConId .. " connected")
    end)
  connection:Connect()
  return ret
end

common.init = {}

function common.init.SDL()
  test:runSDL()
  local ret = SDL.WaitForSDLStart(test)
  ret:Do(function()
      utils.cprint(35, "SDL started")
    end)
  return ret
end

function common.init.HMI()
  local ret = test:initHMI()
  ret:Do(function()
      utils.cprint(35, "HMI initialized")
    end)
  return ret
end

function common.init.HMI_onReady()
  local ret = test:initHMI_onReady()
  ret:Do(function()
      utils.cprint(35, "HMI is ready")
    end)
  return ret
end

function common.init.connectMobile()
  local ret = test:connectMobile()
  ret:Do(function()
      utils.cprint(35, "Mobile connected")
    end)
  return ret
end

function common.init.allowSDL()
  local ret = common.allowSDL()
  ret:Do(function()
      utils.cprint(35, "SDL allowed")
    end)
  return ret
end

function common.execCmd(pCmd)
  local handle = io.popen(pCmd)
  local result = handle:read("*a")
  handle:close()
  return result
end

common.dummyConnection = {}

function common.dummyConnection.add(pId, pAddress)
  os.execute("ifconfig lo:" .. pId .." " .. pAddress)
end

function common.dummyConnection.delete(pId)
  os.execute("ifconfig lo:" .. pId .." down")
  os.execute("rm -f " .. "mobile" .. pId .. ".out")
end

return common
