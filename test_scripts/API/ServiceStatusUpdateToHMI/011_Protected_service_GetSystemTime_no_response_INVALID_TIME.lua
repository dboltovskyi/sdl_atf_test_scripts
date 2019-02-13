---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful
--  OnStatusUpdate(REQUEST_REJECTED, INVALID_TIME) in case GetSystemTime response is not received from HMI
--  and services are force protected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (SERVICETYPE, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (SERVICETYPE, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- In case: HMI not send GetSystemTime_Rq() to SDL
-- SDL does:
-- 1) send StartServiceNACK(SERVICETYPE) to mobile app
-- 2) send OnServiceUpdate (SERVICETYPE, REQUEST_REJECTED, INVALID_TIME) to HMI
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
function common.sendGetSystemTimeResponse()
  -- no response
end

function common.onServiceUpdateFunc(pServiceTypeValue)
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
    { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
    { serviceEvent = "REQUEST_REJECTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId(),
      reason = "INVALID_TIME" })
  :Times(2)
end

function common.serviceResponseFunc(pServiceId)
  common.getMobileSession():ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_NACK,
    encryption = false
  })
  :Timeout(11000)
end

function common.policyTableUpdateFunc()
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions, { "0x0B, 0x0A" })
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential_expired.pem", true })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected without response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 11, 0, 1 })
runner.Step("Start Audio Service protected without response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 10, 0, 1 })
runner.Step("Start RPC Service protected without response to GetSystemTime request",
  common.startServiceWithOnServiceUpdate, { 7, 0, 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)