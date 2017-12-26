---------------------------------------------------------------------------------------------------
-- Issue: https://github.com/SmartDeviceLink/sdl_core/issues/1028
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Policies/Policies_Security/Trigger_PTU_NO_Certificate/common')
local runner = require('user_modules/script_runner')
local test = require("user_modules/dummy_connecttest")
local log = require("user_modules/shared_testcases/testCasesForPolicySDLErrorsStops")

--[[ Local Variables ]]
local appHMIType = "NAVIGATION"
local isHandshakeCompleted = false
local streamingData = {
  audio = {
    serviceId = 10,
    expectedRequestOnHMI = "Navigation.StartAudioStream",
    file = "files/Kalimba3.mp3",
    expectedNotificationOnHMI = "Navigation.OnAudioDataStreaming"
  },
  video = {
    serviceId = 11,
    expectedRequestOnHMI = "Navigation.StartStream",
    file = "files/Wildlife.wmv",
    expectedNotificationOnHMI = "Navigation.OnVideoDataStreaming"
  }
}

--[[ General configuration parameters ]]
config.defaultProtocolVersion = 3
config.application1.registerAppInterfaceParams.appName = "server"
config.application1.registerAppInterfaceParams.appID = "SPT"
config.application1.registerAppInterfaceParams.appHMIType = { appHMIType }

--[[ Local Functions ]]
local function ptUpdate(pTbl)
  local filePath = "./files/Security/client_credential.pem"
  local crt = common.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
  pTbl.policy_table.app_policies[common.getAppID()].AppHMIType = { appHMIType }
end

local function startStreamingSecured(pStreamingData)
  local serviceId = pStreamingData.serviceId
  common.getMobileSession():StartSecureService(serviceId)
  common.getMobileSession():ExpectControlMessage(serviceId, {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
  :Do(function()
      common.getHMIConnection():ExpectRequest(pStreamingData.expectedRequestOnHMI)
      :Do(function(_, data)
          common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
          common.getMobileSession():StartStreaming(serviceId, pStreamingData.file)
          common.getHMIConnection():ExpectNotification(pStreamingData.expectedNotificationOnHMI, { available = true })
        end)
    end)

  if isHandshakeCompleted == false then
    common.getMobileSession():ExpectHandshakeMessage()
    :Do(function() isHandshakeCompleted = true end)
  end
  common.delayedExp(1000)
end

local function stopStreaming(pStreamingData)
  common.getMobileSession():StopStreaming(pStreamingData.file)
  common.getHMIConnection():ExpectNotification(pStreamingData.expectedNotificationOnHMI, { available = false })
end

local function checkSDLLog(pServiceId)
  local str1 = "Version: 3, Protection: "
  local str2 = ", FrameType: 1, ServiceType: " .. pServiceId .. ", FrameData: 0"
  local resSecured = log.ReadSpecificMessage(str1 .. "ON" .. str2)
  local resNotSecured = log.ReadSpecificMessage(str1 .. "OFF" .. str2)
  if resSecured == false and resNotSecured == false then
    test:FailTestCase("Appropriate message regarding streaming was not found in SDL log")
  elseif resSecured == true then
    print("Streaming was encrypted")
  elseif resNotSecured == true then
    test:FailTestCase("Streaming was not encrypted")
  end
end

--[[ Scenario ]]
runner.SetParameters({ isSelfIncluded = false })
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Set ForceProtectedService OFF", common.setForceProtectedServiceParam, { "Non" })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")

runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("PolicyTableUpdate with certificate", common.policyTableUpdate, { ptUpdate })

runner.Step("StartAudioStreaming Secured", startStreamingSecured, { streamingData.audio })
runner.Step("StopAudioStreaming", stopStreaming, { streamingData.audio })

runner.Step("StartVideoStreaming Secured", startStreamingSecured, { streamingData.video })
runner.Step("StopVideoStreaming", stopStreaming, { streamingData.video })

runner.Step("Check SDL Log for Audio streaming", checkSDLLog, { streamingData.audio.serviceId })
runner.Step("Check SDL Log for Video streaming", checkSDLLog, { streamingData.video.serviceId })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
