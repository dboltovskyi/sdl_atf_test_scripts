---------------------------------------------------------------------------------------------------
--  Precondition:
--  1) app1 and app2 are registered on SDL.
--  2) AppServiceProvider permissions(with NAVIGATION AppService permissions to handle rpc SendLocation) are assigned for <app1ID>
--  3) SendLocation permissions are assigned for <app2ID>
--  4) app1 sends a PublishAppService (with {serviceType=NAVIGATION, handledRPC=SendLocation} in the manifest)
--
--  Steps:
--  1) app2 sends a SendLocation request to core
--
--  Expected:
--  1) Core forwards the request to app1
--  2) app1 responds to core with { success = true, resultCode = "SUCCESS", info = "Request was handled by app services" }
--  3) Core forwards the response from app1 to app2
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/AppServices/commonAppServices')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
common.getConfigAppParams(2).appHMIType = { "REMOTE_CONTROL" }

--[[ Local variables ]]
local manifest = {
  serviceName = common.getConfigAppParams(1).appName,
  serviceType = "MEDIA",
  handledRPCs = { 41 },
  allowAppConsumers = true,
  rpcSpecVersion = common.getConfigAppParams(1).syncMsgVersion,
  mediaServiceManifest = {}
}

local rpcRequest = {
  name = "ButtonPress",
  hmi_name = "Buttons.ButtonPress",
  params = {
    moduleType = "RADIO",
    buttonName = "VOLUME_UP",
    buttonPressMode = "SHORT"
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
  pt_entry.app_services.MEDIA = { handled_rpcs = {{ function_id = 41 }} }
  tbl.policy_table.app_policies[common.getConfigAppParams(1).fullAppID] = pt_entry
  --Add permissions for app2
  pt_entry = common.getAppDataForPTU(2)
  pt_entry.groups = { "Base-4" } -- ButtonPress is NOT in scope of this group
  pt_entry.AppHMIType = { "REMOTE_CONTROL" }
  pt_entry.moduleType = { "RADIO" }
  tbl.policy_table.app_policies[common.getConfigAppParams(2).fullAppID] = pt_entry
end

local function RPCPassThruTest()
  local cid = common.getMobileSession(2):SendRPC(rpcRequest.name, rpcRequest.params)

  common.getMobileSession(1):ExpectRequest(rpcRequest.name, rpcRequest.params)
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
