---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0190-resumption-data-error-handling.md
--
-- Description:
-- Check way points data resumption is failed for 1st app and succeeded for 2nd app
-- in case if HMI responds with error to 1st request related to the 1st app
-- and success to 2nd request related to the 2nd app
-- (2nd app re-registers before 1st response is sent by HMI scenario)
--
-- In case:
-- 1. App1 and App2 subscribed to WayPoints
-- 2. Unexpected disconnect and reconnect are performed
-- 3. App1 re-registers with actual HashId
-- SDL does:
--  - start resumption process for App1
--  - send Navi.SubscribeWayPoints request related to App1 to HMI
-- 4. App2 re-registers with actual HashId
-- 5. HMI responds with <erroneous> resultCode
-- SDL does:
--  - not send revert Navi.UnsubscribeWayPoints request to HMI
--  - not restore subscription for App1 and responds RAI_Response(success=true,resultCode=RESUME_FAILED) to App1
--  - continues resumption for App2 and send Navi.SubscribeWayPoints request related to App2 to HMI
-- 6. HMI responds with <successful> resultCode
-- SDL does:
--  - restore subscription for App2 and responds RAI_Response(success=true,resultCode=SUCCESS) to App2
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
runner.Step("Add for app1 subscribeWayPoints", common.subscribeWayPoints)
runner.Step("Add for app2 subscribeWayPoints", common.subscribeWayPoints, { 2, 0 })
runner.Step("Unexpected disconnect", common.unexpectedDisconnect)
runner.Step("Connect mobile", common.connectMobile)
runner.Step("openRPCserviceForApp1", common.openRPCservice, { 1 })
runner.Step("openRPCserviceForApp2", common.openRPCservice, { 2 })
runner.Step("Reregister Apps resumption", common.reRegisterAppsCustom_SameRPC,
  { common.timeToRegApp2.BEFORE_ERRONEOUS_RESPONSE, "subscribeWayPoints" })
runner.Step("Check subscriptions for WayPoints", common.sendOnWayPointChange, { false, true })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
