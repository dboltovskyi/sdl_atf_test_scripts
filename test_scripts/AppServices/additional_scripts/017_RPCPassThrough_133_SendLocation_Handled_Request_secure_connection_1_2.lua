---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require("test_scripts/Security/SSLHandshakeFlow/common")
local appServices = require('test_scripts/AppServices/commonAppServices')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
common.getConfigAppParams(1).fullAppID = "spt"
common.getConfigAppParams(2).fullAppID = "spt2"

--[[ Local Variables ]]
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

--[[ Local Functions ]]
local function startServiceProtected(pAppId)
  local serviceId = 7
  common.getMobileSession(pAppId):StartSecureService(serviceId)
  common.getMobileSession(pAppId):ExpectControlMessage(serviceId, {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
  common.getMobileSession(pAppId):ExpectHandshakeMessage()
  :Times(1)
end

local function PTUfunc(tbl)
  -- Add permissions for app1
  local pt_entry = appServices.getAppServiceProducerConfig(1)
  pt_entry.app_services.NAVIGATION = { handled_rpcs = {{ function_id = 39 }} }
  tbl.policy_table.app_policies[common.getConfigAppParams(1).fullAppID] = pt_entry
  -- Add permissions for app2
  pt_entry = appServices.getAppServiceConsumerConfig(2)
  table.insert(pt_entry.groups, "SendLocation" )
  tbl.policy_table.app_policies[common.getConfigAppParams(2).fullAppID] = pt_entry
end

local function rpcPassThruSuccess()
  local cid = common.getMobileSession(2):SendRPC(rpcRequest.name, rpcRequest.params)
  common.getMobileSession(1):ExpectRequest(rpcRequest.name, rpcRequest.params)
  :Do(function(_, data)
      common.getMobileSession(1):SendResponse(rpcRequest.name, data.rpcCorrelationId, successResponse)
    end)
  common.getMobileSession(2):ExpectResponse(cid, rpcResponse.params)
end

local function rpcPassThruSuccessProtected_App_1()
  local cid = common.getMobileSession(2):SendRPC(rpcRequest.name, rpcRequest.params)
  common.getMobileSession(1):ExpectEncryptedRequest(rpcRequest.name, rpcRequest.params)
  :Do(function(_, data)
      common.getMobileSession(1):SendEncryptedResponse(rpcRequest.name, data.rpcCorrelationId, successResponse)
    end)
  common.getMobileSession(2):ExpectResponse(cid, rpcResponse.params)
end

local function rpcPassThruSuccessProtected_App_1_2()
  local cid = common.getMobileSession(2):SendEncryptedRPC(rpcRequest.name, rpcRequest.params)
  common.getMobileSession(1):ExpectEncryptedRequest(rpcRequest.name, rpcRequest.params)
  :Do(function(_, data)
      common.getMobileSession(1):SendEncryptedResponse(rpcRequest.name, data.rpcCorrelationId, successResponse)
    end)
  common.getMobileSession(2):ExpectEncryptedResponse(cid, rpcResponse.params)
end

local function setMobileCrt(pCrtFile)
  for _, v in pairs({"serverCertificatePath", "serverPrivateKeyPath", "serverCAChainCertPath" }) do
    config[v] = pCrtFile
  end
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates, { "./files/Security/client_credential.pem" })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Set mobile certificate for App 1", setMobileCrt, { "./files/Security/spt_credential.pem" })
runner.Step("RAI App 1", common.registerApp)
runner.Step("PTU", common.policyTableUpdate, { PTUfunc })
runner.Step("PublishAppService", appServices.publishMobileAppService, { manifest })
runner.Step("Set mobile certificate for App 2", setMobileCrt, { "./files/Security/spt_credential_2.pem" })
runner.Step("RAI App 2", common.registerAppWOPTU, { 2 })
runner.Step("Activate App 2", common.activateApp, { 2 })

runner.Title("Test")
runner.Step("RPCPassThroughTest_SUCCESS_Protection_OFF", rpcPassThruSuccess)
runner.Step("Switch App 1 RPC Service to Protected mode", startServiceProtected, { 1 })
runner.Step("RPCPassThroughTest_SUCCESS_Protection_ON_App_1", rpcPassThruSuccessProtected_App_1)
runner.Step("Switch App 2 RPC Service to Protected mode", startServiceProtected, { 2 })
runner.Step("RPCPassThroughTest_SUCCESS_Protection_ON_App_1_2", rpcPassThruSuccessProtected_App_1_2)

runner.Title("Postconditions")
runner.Step("Stop SDL, clean-up certificates", common.postconditions)
