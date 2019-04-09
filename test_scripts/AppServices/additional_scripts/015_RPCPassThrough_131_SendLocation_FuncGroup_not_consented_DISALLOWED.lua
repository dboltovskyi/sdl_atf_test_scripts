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

local grpId

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
  -- Add consent prompt to func. group
  tbl.policy_table.functional_groupings.SendLocation.user_consent_prompt = "SendLocation"
end

local function RPCPassThruTestSuccess()
  local providerMobileSession = common.getMobileSession(1)
  local mobileSession = common.getMobileSession(2)

  local cid = mobileSession:SendRPC(rpcRequest.name, rpcRequest.params)

  providerMobileSession:ExpectRequest(rpcRequest.name, rpcRequest.params):Do(function(_, data)
      providerMobileSession:SendResponse(rpcRequest.name, data.rpcCorrelationId, successResponse)
  end)

  mobileSession:ExpectResponse(cid, rpcResponse.params)
end

local function RPCPassThruTestDisallowed(pResultCode)
  local cid = common.getMobileSession(2):SendRPC(rpcRequest.name, rpcRequest.params)

  common.getMobileSession(1):ExpectRequest(rpcRequest.name, rpcRequest.params)
  :Times(0)

  common.getHMIConnection():ExpectRequest(rpcRequest.hmi_name, rpcRequest.hmi_params)
  :Times(0)

  common.getMobileSession(2):ExpectResponse(cid, { success = false, resultCode = pResultCode })
end

local function allowFuncGroup(isAllowed)
  local key = "userDisallowed"
  if isAllowed == true then
    key = "allowed"
  end
  common.getHMIConnection():SendNotification("SDL.OnAppPermissionConsent", {
    appID = common.getHMIAppId(2), source = "GUI",
    consentedFunctions = {{ name = "SendLocation", id = grpId, allowed = isAllowed }}
  })
  common.getMobileSession(2):ExpectNotification("OnPermissionsChange")
  :Do(function(_, data)
      for _, item in pairs(data.payload.permissionItem) do
        if item.rpcName == "SendLocation" and #item.hmiPermissions[key] > 0 then
          utils.cprint(35, "SendLocation func. group is " .. key)
        end
      end
    end)
end

local function getGroupId()
  local cid = common.getHMIConnection():SendRequest("SDL.GetListOfPermissions", { appID = common.getHMIAppId(2) })
  common.getHMIConnection():ExpectResponse(cid)
  :Do(function(_, data)
      for i = 1, #data.result.allowedFunctions do
        if(data.result.allowedFunctions[i].name == "SendLocation") then
         grpId = data.result.allowedFunctions[i].id
        end
      end
      utils.cprint(35, "GroupId:", grpId)
    end)
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
runner.Step("Get Group Id", getGroupId)

runner.Step("RPCPassThroughTest_DISALLOWED", RPCPassThruTestDisallowed, { "DISALLOWED" })
runner.Step("Allow Functional Group", allowFuncGroup, { true })
runner.Step("RPCPassThroughTest_SUCCESS", RPCPassThruTestSuccess)
runner.Step("Disallow Functional Group", allowFuncGroup, { false })
runner.Step("RPCPassThroughTest_USER_DISALLOWED", RPCPassThruTestDisallowed, { "USER_DISALLOWED" })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
