---------------------------------------------------------------------------------------------------
--  Precondition:
--  1) app1 and app2 are registered on SDL.
--  2) AppServiceProvider permissions(with NAVIGATION AppService permissions to handle rpc SendLocation) are assigned for app 1
--  3) SendLocation permissions are NOT assigned for app2
--  4) app1 sends a PublishAppService (with {serviceType=NAVIGATION, handledRPC=SendLocation} in the manifest)
--
--  Steps:
--  1) app2 sends a SendLocation request to core
--
--  Expected:
--  1) Core does not forward the request to app1
--  2) Core does not forward the request to HMI
--  3) Core responds to app2 with { success = false, resultCode = "DISALLOWED" }
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/AppServices/commonAppServices')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local variables ]]
local manifest = {
  serviceName = common.getConfigAppParams(1).appName,
  serviceType = "NAVIGATION",
  handledRPCs = { 39 },
  allowAppConsumers = true,
  rpcSpecVersion = common.getConfigAppParams(1).syncMsgVersion,
  mediaServiceManifest = {}
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
  params = { success = false, resultCode = "DISALLOWED" }
}

--[[ Local functions ]]
local function PTUfunc(tbl)
  local pt_entry
  --Add permissions for app1
  pt_entry = common.getAppServiceProducerConfig(1)
  pt_entry.app_services.NAVIGATION = { handled_rpcs = {{ function_id = 39 }} }
  tbl.policy_table.app_policies[common.getConfigAppParams(1).fullAppID] = pt_entry
  --Add permissions for app2
  pt_entry = common.getAppDataForPTU(2)
  pt_entry.groups = { "Base-4" } -- SendLocation is NOT in scope of this group
  tbl.policy_table.app_policies[common.getConfigAppParams(2).fullAppID] = pt_entry
end

local function RPCPassThruTest()
  local cid = common.getMobileSession(2):SendRPC(rpcRequest.name, rpcRequest.params)

  common.getMobileSession(1):ExpectRequest(rpcRequest.name)
  :Times(0)
  common.getHMIConnection():ExpectRequest(rpcRequest.hmi_name)
  :Times(0)

  common.getMobileSession(2):ExpectResponse(cid, rpcResponse.params)
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
runner.Step("RPCPassThroughTest_DISALLOWED", RPCPassThruTest)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
