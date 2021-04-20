---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0190-resumption-data-error-handling.md
--
-- Description:
-- Check data resumption is failed for 1st app and succeeded for 2nd app for the same vehicle data
-- in case if HMI responds with error to non vehicle data request related to the 1st app
-- and success to 2nd request related to the 2nd app
-- (2nd app re-registers before 1st response is sent by HMI scenario)
--
-- In case:
-- 1. AddSubMenu related to resumption is sent by App1
-- 2. App1 and App2 are subscribed to the same Vehicle Data
-- 3. Unexpected disconnect and reconnect are performed
-- 4. App1 re-register with actual HashId
-- SDL does:
--  - start resumption process for App1
--  - send UI.AddSubMenu and VI.SubscribeVehicleData requests related to App1 to HMI
-- 5. App2 re-registers with actual HashId
-- 6. HMI responds with <erroneous> resultCode to UI.AddSubMenu and <successful> to VI.SubscribeVehicleData
-- SDL does:
--  - not send revert VI.UnsubscribeVehicleData request to HMI
--  - not restore subscription to VD for App1 and responds RAI_Response(success=true,resultCode=RESUME_FAILED) to App1
--  - restore subscription to VD for App2 and responds RAI_Response(success=true,resultCode=SUCCESS) to App2
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Resumption/Handling_errors_from_HMI/commonResumptionErrorHandling')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
runner.Step("Register app1", common.registerAppWOPTU)
runner.Step("Register app2", common.registerAppWOPTU, { 2 })
runner.Step("Activate app1", common.activateApp)
runner.Step("Activate app2", common.activateApp, { 2 })
runner.Step("Add for app1 subscribeVehicleData gps", common.subscribeVehicleData)
runner.Step("Add for app1 addSubMenu", common.addSubMenu)
runner.Step("Add for app2 subscribeVehicleData gps", common.subscribeVehicleData, { 2, nil, 0 })
runner.Step("Unexpected disconnect", common.unexpectedDisconnect)
runner.Step("Connect mobile", common.connectMobile)
runner.Step("openRPCserviceForApp1", common.openRPCservice, { 1 })
runner.Step("openRPCserviceForApp2", common.openRPCservice, { 2 })
runner.Step("Reregister Apps resumption", common.reRegisterAppsCustom_AnotherRPC,
  { common.timeToRegApp2.BEFORE_ERRONEOUS_RESPONSE, "subscribeVehicleData" })
runner.Step("Check subscriptions for gps", common.sendOnVehicleData, { "gps", false, true })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
