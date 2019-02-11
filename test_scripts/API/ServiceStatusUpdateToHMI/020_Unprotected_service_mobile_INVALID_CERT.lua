---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful OnStatusUpdate
-- (REQUEST_REJECTED, INVALID_CERT) notification in case certification in DB after update is not valid and services are
-- not force protected and not force unprotected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (Video, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (VIDEO, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Successful
-- SDL does:
-- 1) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- In case:
-- 3) Mobile app asks SDL to provide client cert
-- SDL does:
-- 1) send cert to mobile app
-- In case:
-- 4) Mobile cert is invalid
-- SDL does:
-- 1) send OnServiceUpdate (RPC, INVALID_CERT) to HMI (for RPC ServiceType)
-- 2) send StartServiceNACK (RPC, encryption = false) to mobile app
-- 3) send OnServiceUpdate (SERVICETYPE, REQUEST_ACCEPTED) to HMI (for Audio, Video ServiceType)
-- 4) respond StartServiceACK (INVALID_CERT, encryption = false) to mobile app (for Audio, Video ServiceType)
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
function common.onServiceUpdateFunc(pServiceTypeValue)
  if pServiceTypeValue == "RPC" then
    common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_REJECTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId(),
        reason = "INVALID_CERT" })
    :Times(2)
  else
    common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_ACCEPTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() })
      :Times(2)
  end
end

function common.serviceResponseFunc(pServiceId, pStreamingFunc)
  common.serviceResponseWithACKandNACK(pServiceId, pStreamingFunc)
end

function common.policyTableUpdateFunc()
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate")
  :Times(0)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential.pem", true })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Set mobile certificate for app", common.setMobileCrt,
  { "./files/Security/spt_credential_expired.pem" })
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected", common.startServiceWithOnServiceUpdate, { 11, 1, 1 })
runner.Step("Start Audio Service protected", common.startServiceWithOnServiceUpdate, { 10, 1, 1 })
runner.Step("Start RPC Service protected", common.startServiceWithOnServiceUpdate, { 7, 1, 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
