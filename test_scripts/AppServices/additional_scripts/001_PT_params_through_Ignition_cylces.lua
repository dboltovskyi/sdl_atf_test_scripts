---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/AppServices/commonAppServices')
local events = require('events')
local SDL = require("SDL")
local test = require("user_modules/dummy_connecttest")
local utils = require("user_modules/utils")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local manifest = {
  serviceName = common.getConfigAppParams(1).appName,
  serviceType = "MEDIA",
  handledRPCs = { 39 },
  allowAppConsumers = true,
  rpcSpecVersion = common.getConfigAppParams(1).syncMsgVersion,
  mediaServiceManifest = {},
  navigationServiceManifest = {}
}

--[[ Local Functions ]]
local function PTUfunc(tbl)
  local pt_entry = common.getAppServiceProducerConfig(1)
  pt_entry.app_services.MEDIA = { handled_rpcs = {{ function_id = 39 }} }
  tbl.policy_table.app_policies[common.getConfigAppParams(1).fullAppID] = pt_entry
  pt_entry = common.getAppServiceConsumerConfig(2)
  table.insert(pt_entry.groups, "SendLocation")
  tbl.policy_table.app_policies[common.getConfigAppParams(2).fullAppID] = pt_entry
end

local function rpcGetAppServiceData()
  local rpc = {
    name = "GetAppServiceData",
    params = {
      serviceType = manifest.serviceType
    }
  }
  local expectedResponse = {
    serviceData = {
      serviceType = manifest.serviceType,
      mediaServiceData = {
        mediaType = "MUSIC",
      }
    },
    success = true,
    resultCode = "SUCCESS"
  }
  local cid = common.getMobileSession(2):SendRPC(rpc.name, rpc.params)
  local responseParams = expectedResponse
  responseParams.serviceData.serviceID = common.getAppServiceID()
  common.getMobileSession(1):ExpectRequest(rpc.name, rpc.params)
  :Do(function(_, data)
      common.getMobileSession(1):SendResponse(rpc.name, data.rpcCorrelationId, responseParams)
    end)
  common.getMobileSession(2):ExpectResponse(cid, responseParams)
end

local function wait(pTimeOut)
  if not pTimeOut then pTimeOut = common.timeout end
  local event = events.Event()
  event.matches = function(event1, event2) return event1 == event2 end
  local ret = EXPECT_EVENT(event, "Delayed event")
  :Timeout(pTimeOut + 60000)
  RUN_AFTER(function() RAISE_EVENT(event, event) end, pTimeOut)
  return ret
end

local function ignitionOff()
  local isOnSDLCloseSent = false
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
  wait(3000)
  :Do(function()
      if isOnSDLCloseSent == false then utils.cprint(35, "BC.OnSDLClose was not sent") end
      if SDL:CheckStatusSDL() == SDL.RUNNING then SDL:StopSDL() end
      common.getMobileConnection():Close()
      test.mobileSession[1] = nil
      test.mobileSession[2] = nil
    end)
end

local function rpcSendLocationPassThrough()
  local successResponse = {
    success = true,
    resultCode = "SUCCESS",
    info = "Request was handled by app services"
  }
  local rpcRequest = {
    name = "SendLocation",
    hmi_name = "Navigation.SendLocation",
    params = {
      longitudeDegrees = 50,
      latitudeDegrees = 50,
      locationName = "TestLocation"
    }
  }
  local rpcResponse = {
    params = successResponse
  }

  local cid = common.getMobileSession(2):SendRPC(rpcRequest.name, rpcRequest.params)

  common.getMobileSession(1):ExpectRequest(rpcRequest.name, rpcRequest.params)
  :Do(function(_, data)
      common.getMobileSession(1):SendResponse(rpcRequest.name, data.rpcCorrelationId, successResponse)
    end)

  --Core will NOT handle the RPC
  common.getHMIConnection():ExpectRequest(rpcRequest.hmi_name)
  :Times(0)

  common.getMobileSession(2):ExpectResponse(cid, rpcResponse.params)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI 1", common.registerApp)
runner.Step("PTU", common.policyTableUpdate, { PTUfunc })
runner.Step("RAI 2 w/o PTU", common.registerAppWOPTU, { 2 })
runner.Step("Publish App Service", common.publishMobileAppService, { manifest })
runner.Step("Activate App", common.activateApp, { 2 })

runner.Title("Test")
runner.Step("RPC GetAppServiceData SUCCESS", rpcGetAppServiceData)
runner.Step("RPC PassThrough SendLocation SUCCESS", rpcSendLocationPassThrough)

runner.Step("Ignition Off", ignitionOff)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI 1 w/o PTU", common.registerAppWOPTU, { 1 })
runner.Step("RAI 2 w/o PTU", common.registerAppWOPTU, { 2 })
runner.Step("Publish App Service", common.publishMobileAppService, { manifest })
runner.Step("Activate App", common.activateApp, { 2 })

runner.Step("RPC GetAppServiceData SUCCESS", rpcGetAppServiceData)
runner.Step("RPC PassThrough SendLocation SUCCESS", rpcSendLocationPassThrough)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
