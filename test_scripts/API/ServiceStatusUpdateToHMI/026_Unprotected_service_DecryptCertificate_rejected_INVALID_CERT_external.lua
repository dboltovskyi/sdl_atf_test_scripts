---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: The attempt to open the protected Video, Audio, RPC services with unsuccessful
--  OnStatusUpdate(REQUEST_REJECTED, INVALID_CERT) notification by receiving DecryptCertificate response with error code
--  from HMI and services are not force protected
-- Precondition:
-- 1) App is registered with NAVIGATION appHMIType and activated.
-- In case:
-- 1) Mobile app requests StartService (SERVICETYPE, encryption = false)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (SERVICETYPE, REQUEST_RECEIVED) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Successful
-- SDL does:
-- 1) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 2) send BC.DecryptCertificate_Rq() and wait response from HMI BC.DecryptCertificate_Rq()
-- In case:
-- 3) Certificate in DB is valid, but HMI responds with error result code to DecryptCertificate_Rq
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
function common.decryptCertificateRes(pId, pMethod)
  common.getHMIConnection():SendError(pId, pMethod, "REJECTED", "Cert is not decrypted")
end

function common.onServiceUpdateFunc(pServiceTypeValue)
  local expData
  if pServiceTypeValue == "RPC" then
    expData = {
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_REJECTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId(),
        reason = "INVALID_CERT" }
    }
  else
    expData = {
      { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() },
      { serviceEvent = "REQUEST_ACCEPTED", serviceType = pServiceTypeValue, appID = common.getHMIAppId() }
    }
  end
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate", unpack(expData))
  :Times(2)
end

function common.serviceResponseFunc(pServiceId, pStreamingFunc)
  common.serviceResponseWithACKandNACK(pServiceId, pStreamingFunc)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential_expired.pem", true })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("Start Video Service protected", common.startServiceWithOnServiceUpdate, { 11, 0, 1 })
runner.Step("Start Audio Service protected", common.startServiceWithOnServiceUpdate, { 10, 0, 1 })
runner.Step("Start RPC Service protected", common.startServiceWithOnServiceUpdate, { 7, 0, 1 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
