---------------------------------------------------------------------------------------------------
-- EXTERNAL_PROPRIETARY flow only
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/AppServices/commonAppServices')
local utils = require("user_modules/utils")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local variables ]]
local manifest = {
  serviceName = common.getConfigAppParams(1).appName,
  serviceType = "NAVIGATION",
  handledRPCs = { 39 },
  allowAppConsumers = true,
  rpcSpecVersion = common.getConfigAppParams(1).syncMsgVersion,
  navigationServiceManifest = {}
}

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
  },
  hmi_params = {
    longitudeDegrees = 50,
    latitudeDegrees = 50,
    locationName = "TestLocation"
  }
}

local rpcResponse = {
  params = successResponse
}

--[[ Local functions ]]
local function PTUfunc(tbl)
  -- Add permissions for app1
  local pt_entry = common.getAppServiceProducerConfig(1)
  pt_entry.app_services.NAVIGATION = { handled_rpcs = {{ function_id = 39 }} }
  tbl.policy_table.app_policies[common.getConfigAppParams(1).fullAppID] = pt_entry
  -- Add permissions for app2
  pt_entry = common.getAppDataForPTU(2)
  pt_entry.groups = { "Base-4" , "SendLocation" }
  tbl.policy_table.app_policies[common.getConfigAppParams(2).fullAppID] = pt_entry
end

local function RPCPassThruTestSuccess()
  local cid = common.getMobileSession(2):SendRPC(rpcRequest.name, rpcRequest.params)

  common.getMobileSession(1):ExpectRequest(rpcRequest.name, rpcRequest.params):Do(function(_, data)
      common.getMobileSession(1):SendResponse(rpcRequest.name, data.rpcCorrelationId, successResponse)
    end)

  common.getHMIConnection():ExpectRequest(rpcRequest.hmi_name, rpcRequest.hmi_params)
  :Times(0)

  common.getMobileSession(2):ExpectResponse(cid, rpcResponse.params)
end

local function RPCPassThruTestDisallowed()
  local cid = common.getMobileSession(1):SendRPC(rpcRequest.name, rpcRequest.params)

  common.getMobileSession(2):ExpectRequest(rpcRequest.name, rpcRequest.params)
  :Times(0)

  common.getHMIConnection():ExpectRequest(rpcRequest.hmi_name, rpcRequest.hmi_params)
  :Times(0)

  common.getMobileSession(1):ExpectResponse(cid, { success = false, resultCode = "DISALLOWED" })
end

local function allowSDL(isAllowed)
  common.getHMIConnection():SendNotification("SDL.OnAllowSDLFunctionality", {
    allowed = isAllowed,
    source = "GUI",
    device = {
      id = utils.getDeviceMAC(),
      name = utils.getDeviceName()
    }
  })
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI App 1", common.registerApp)
runner.Step("PTU", common.policyTableUpdate, { PTUfunc })
runner.Step("PublishAppService", common.publishMobileAppService, { manifest, 1 })
runner.Step("RAI App 2", common.registerAppWOPTU, { 2 })
runner.Step("Activate App", common.activateApp, { 2 })

runner.Title("Test")
runner.Step("RPCPassThroughTest_SUCCESS", RPCPassThruTestSuccess)
runner.Step("Disallow Device", allowSDL, { false })
runner.Step("RPCPassThroughTest_DISALLOWED", RPCPassThruTestDisallowed)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
