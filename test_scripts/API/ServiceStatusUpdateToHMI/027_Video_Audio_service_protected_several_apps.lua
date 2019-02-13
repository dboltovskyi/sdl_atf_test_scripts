---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0211-ServiceStatusUpdateToHMI.md
-- Description: Receiving of the OnStatusUpdate notification by the appropriate app by the Audio, Video services opening
-- 1) App_1 is registered with NAVIGATION appHMIType and activated.
-- 2) App_2 is registered with NAVIGATION appHMIType.
-- In case:
-- 1) Mobile app_1 requests StartService (SERVICETYPE, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (SERVICETYPE, REQUEST_RECEIVED, AppID_1) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UPDATE_NEEDED)
-- In case:
-- 2) Policy Table Update is Successful
-- SDL does:
-- 1) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 2) send BC.DecryptCertificate_Rq() and wait response from HMI BC.DecryptCertificate_Rq()(only in EXTERNAL_PROPRIETARY
--    flow)
-- 3) send OnServiceUpdate (SERVICETYPE, REQUEST_ACCEPTED, AppID_1) to HMI
-- 4) send StartServiceACK(SERVICETYPE, encryption = true) to mobile app_1
-- In case:
-- 3) App_2 activated and requests StartService (Video, encryption = true)
-- SDL does:
-- 1) send StartSream() to HMI
-- 2) send OnServiceUpdate (SERVICETYPE, REQUEST_RECEIVED, AppID_2) to HMI
-- 3) send GetSystemTime_Rq() and wait response from HMI GetSystemTime_Res()
-- 4) send OnStatusUpdate(UP_TO_DATE) if Policy Table Update is successful
-- 5) send OnServiceUpdate (SERVICETYPE, REQUEST_ACCEPTED, AppID_2) to HMI
-- 6) send StartServiceACK (SERVICETYPE, encryption = true) to mobile app_2
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ServiceStatusUpdateToHMI/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local crts = {
  [1] = "./files/Security/spt_credential.pem",
  [2] = "./files/Security/spt_credential_2.pem"
}

--[[ Local Functions ]]
function common.serviceResponseFunc(pServiceId, _, pAppId)
  common.getMobileSession(pAppId):ExpectControlMessage(pServiceId, {
    frameInfo = common.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
end

function common.policyTableUpdateFunc()
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Init SDL certificates", common.initSDLCertificates,
  { "./files/Security/client_credential.pem", true })
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

for i = 1, 2 do
  runner.Step("Set mobile certificate for app " .. i, common.setMobileCrt, { crts[i] })
  runner.Step("App " .. i .. " registration", common.registerApp, { i })
  runner.Step("PolicyTableUpdate", common.policyTableUpdate)
end

runner.Title("Test")
for i = 1, 2 do
  runner.Step("App " .. i .. " activation", common.activateApp, { i })
  runner.Step("Start Video Service app " .. i, common.startServiceWithOnServiceUpdate, { 11, 1, 1, i })
  runner.Step("Start Audio Service app " .. i, common.startServiceWithOnServiceUpdate, { 10, 0, 0, i })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
