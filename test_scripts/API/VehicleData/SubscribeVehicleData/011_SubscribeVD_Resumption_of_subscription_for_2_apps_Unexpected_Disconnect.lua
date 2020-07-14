---------------------------------------------------------------------------------------------------
-- Description: Check that SDL resumes the subscription for <vd_param> parameter for two Apps
-- after unexpected disconnect
--
-- Precondition:
-- 1) Two apps are registered and activated
-- 2) Apps are subscribed to <vd_param> parameter data
-- 3) Unexpected disconnect and reconnect are performed
--
-- In case:
-- 1) App_1 registers with actual hashID
-- SDL does:
--  a) start data resumption for app
--  b) start to resume the subscription and sends VI.SubscribeVehicleData request to HMI
--  c) after success response from HMI SDL resumes the subscription
-- 2) App_2 registers with actual hashID
-- SDL does:
--  a) start data resumption for app
--  b) resume the subscription internally and not send VI.SubscribeVehicleData request to HMI
-- 3) HMI sends OnVehicleData notification with <vd_param> parameter
-- SDL does:
--  a) resend OnVehicleData notification to both mobile apps
--------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/API/VehicleData/common')

--[[ Local Variables ]]
local appId1 = 1
local appId2 = 2
local isExpectedSubscribeVDonHMI = true
local notExpectedSubscribeVDonHMI = false
local isExpected = 1

--[[ Scenario ]]
for param in common.spairs(common.getVDParams(true)) do
  common.Title("VD parameter: " .. param)
  common.Title("Preconditions")
  common.Step("Clean environment", common.preconditions)
  common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
  common.Step("Register App1", common.registerAppWOPTU, { appId1 })
  common.Step("Register App2", common.registerAppWOPTU, { appId2 })
  common.Step("App1 subscribes to VD param", common.processSubscriptionRPC,
    { common.rpc.sub, param, appId1, isExpectedSubscribeVDonHMI })
  common.Step("App2 subscribes to VD param", common.processSubscriptionRPC,
    { common.rpc.sub, param, appId2, notExpectedSubscribeVDonHMI })

  common.Title("Test")
  common.Step("Unexpected disconnect", common.unexpectedDisconnect, { param })
  common.Step("Connect mobile", common.connectMobile)
  common.Step("Re-register App1 resumption data", common.registerAppWithResumption,
    { param, appId1, isExpectedSubscribeVDonHMI })
  common.Step("Re-register App2 resumption data", common.registerAppWithResumption,
    { param, appId2, notExpectedSubscribeVDonHMI })
  common.Step("OnVehicleData with VD param for both apps", common.sendOnVehicleData,
    { param, isExpected })

  common.Title("Postconditions")
  common.Step("Stop SDL", common.postconditions)
end
