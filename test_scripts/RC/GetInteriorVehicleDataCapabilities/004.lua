---------------------------------------------------------------------------------------------------
-- RPC: GetInteriorVehicleDataCapabilities
-- Script: 004
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local runner = require('user_modules/script_runner')

--[[ Local Functions ]]
local function step1(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = { "CLIMATE", "RADIO" }
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications["Test Application"],
			moduleTypes = { "CLIMATE", "RADIO" }
		})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "WARNINGS", {
				interiorVehicleDataCapabilities = {
					{
						climateControlCapabilities = commonRC.getClimateControlCapabilities()
					}
				},
				info = "Radio module is not available"
			})
	end)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "WARNINGS",
			interiorVehicleDataCapabilities = {
				{
					climateControlCapabilities = commonRC.getClimateControlCapabilities()
				}
			},
			info = "Radio module is not available"
		})
end

local function step2(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = { "CLIMATE", "RADIO" }
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications["Test Application"],
			moduleTypes = { "CLIMATE", "RADIO" }
		})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "WARNINGS", {
				interiorVehicleDataCapabilities = {
					{
						radioControlCapabilities = commonRC.getRadioControlCapabilities()
					}
				},
				info = "Climate module is not available"
			})
	end)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "WARNINGS",
			interiorVehicleDataCapabilities = {
				{
					radioControlCapabilities = commonRC.getRadioControlCapabilities()
				}
			},
			info = "Climate module is not available"
		})
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
