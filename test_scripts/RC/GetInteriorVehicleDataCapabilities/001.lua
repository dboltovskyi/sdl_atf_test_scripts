---------------------------------------------------------------------------------------------------
-- RPC: GetInteriorVehicleDataCapabilities
-- Script: 001
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local runner = require('user_modules/script_runner')

--[[ Local Functions ]]
local function step1(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
		zone = commonRC.getInteriorZone(),
		moduleTypes = { "CLIMATE" }
	})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
		appID = self.applications["Test Application"],
		zone = commonRC.getInteriorZone(),
		moduleTypes = { "CLIMATE" }
	})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
				interiorVehicleDataCapabilities = {
					{
						moduleZone = commonRC.getInteriorZone(),
						moduleType = "CLIMATE"
					}
				}
			})
	end)

	EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
end

local function step2(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
		zone = commonRC.getInteriorZone(),
		moduleTypes = { "RADIO" }
	})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
		appID = self.applications["Test Application"],
		zone = commonRC.getInteriorZone(),
		moduleTypes = { "RADIO" }
	})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
				interiorVehicleDataCapabilities = {
					{
						moduleZone = commonRC.getInteriorZone(),
						moduleType = "RADIO"
					}
				}
			})
	end)

	EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })
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
