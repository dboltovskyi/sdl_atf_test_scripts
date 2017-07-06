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
			moduleTypes = { "CLIMATE", "RADIO" }
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications["Test Application"],
			moduleTypes = { "CLIMATE" }
		})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
				interiorVehicleDataCapabilities = {
					{
						climateControlCapabilities = commonRC.getClimateControlCapabilities()
					}
				}
			})
	end)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "SUCCESS",
			interiorVehicleDataCapabilities = {
				{
					climateControlCapabilities = commonRC.getClimateControlCapabilities()
				}
			}
		})
end

local function step2(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = nil
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications["Test Application"],
			moduleTypes = { "CLIMATE" }
		})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
				interiorVehicleDataCapabilities = {
					{
						climateControlCapabilities = commonRC.getClimateControlCapabilities()
					}
				}
			})
	end)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "SUCCESS",
			interiorVehicleDataCapabilities = {
				{
					climateControlCapabilities = commonRC.getClimateControlCapabilities()
				}
			}
		})
end

local function ptu_update_func(tbl)
	tbl.policy_table.app_policies[config.application1.registerAppInterfaceParams.appID].moduleType = { "CLIMATE" }
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu, { ptu_update_func })
runner.Title("Test")
runner.Step("GetInteriorVehicleDataCapabilities_CLIMATE_both", step1)
runner.Step("GetInteriorVehicleDataCapabilities_CLIMATE_absent", step2)
runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
