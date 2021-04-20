---------------------------------------------------------------------------------------------------
-- User story: https://github.com/SmartDeviceLink/sdl_core/issues/1178
--
-- Description:
-- Core sends an OnAppInterfaceUnregistered notification when UnregisterAppInterface is sent from Mobile
--
-- Preconditions:
-- 1) Clear environment
-- 2) SDL, HMI, Mobile session started
-- 3) Registered app
-- 4) Activated app
--
-- Steps: 
-- 1) Send "UnregisterAppInterface" mobile RPC
--   
-- Postconditions:
-- Stop SDL
--
-- Expected:
-- 1) "onAppInterfaceUnregistered" notification was NOT recieved by mobile
-- 2) "UnregisterAppInterface" response was recieved by mobile with resultCode = "SUCCESS"
-- 3) "OnAppUnregistered" was recieved by HMI with unexpectedDisconnect = false 
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('user_modules/sequences/actions')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function unregisterAppInterface()
	local cid = common.getMobileSession():SendRPC("UnregisterAppInterface", { })
	common.getMobileSession():ExpectNotification("OnAppInterfaceUnregistered", { })
	:Times(0)
	common.getMobileSession():ExpectResponse(cid, 
		{ success = true, resultCode = "SUCCESS" }
	)
	common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppUnregistered", 
		{ appID = common.getHMIAppId(), unexpectedDisconnect = false}
	)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register app", common.registerApp)
runner.Step("Activate app", common.activateApp)

runner.Title("Test")
runner.Step("Unregister App Interface", unregisterAppInterface)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
