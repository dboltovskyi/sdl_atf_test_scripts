---------------------------------------------------------------------------------------------------
-- RPC: GetInteriorVehicleDataCapabilities
-- Script: 003
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local runner = require('user_modules/script_runner')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')

--[[ General configuration parameters ]]
config.application1.registerAppInterfaceParams.appHMIType = { "DEFAULT" }

--[[ Local Functions ]]
local function step1(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
		zone = commonRC.getInteriorZone(),
		moduleTypes = { "CLIMATE" }
	})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities")
	:Times(0)

	EXPECT_RESPONSE(cid, { success = false, resultCode = "DISALLOWED" })

	commonTestCases:DelayedExp(5000)
end

local function step2(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
		zone = commonRC.getInteriorZone(),
		moduleTypes = { "RADIO" }
	})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities")
	:Times(0)

	EXPECT_RESPONSE(cid, { success = false, resultCode = "DISALLOWED" })

	commonTestCases:DelayedExp(5000)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu)
runner.Title("Test")
runner.Step("GetInteriorVehicleDataCapabilities_CLIMATE", step1)
runner.Step("GetInteriorVehicleDataCapabilities_RADIO", step2)
runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
