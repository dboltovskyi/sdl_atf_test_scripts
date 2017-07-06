---------------------------------------------------------------------------------------------------
-- RPC: GetInteriorVehicleDataCapabilities
-- Script: 001
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local runner = require('user_modules/script_runner')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')

--[[ Local Functions ]]
local function step1(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = { "CLIMATE" }
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

	EXPECT_HMICALL("RC.GetInteriorVehicleDataConsent")
	:Times(0)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "SUCCESS",
			interiorVehicleDataCapabilities = {
				{
					climateControlCapabilities = commonRC.getClimateControlCapabilities()
				}
			}
		})

	commonTestCases:DelayedExp(commonRC.timeout)
end

local function step2(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = { "RADIO" }
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications["Test Application"],
			moduleTypes = { "RADIO" }
		})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
				interiorVehicleDataCapabilities = {
					{
						radioControlCapabilities = commonRC.getRadioControlCapabilities()
					}
				}
			})
	end)

	EXPECT_HMICALL("RC.GetInteriorVehicleDataConsent")
	:Times(0)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "SUCCESS",
			interiorVehicleDataCapabilities = {
				{
					radioControlCapabilities = commonRC.getRadioControlCapabilities()
				}
			}
		})

	commonTestCases:DelayedExp(commonRC.timeout)
end

local function step3(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = { "CLIMATE", "RADIO" }
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications["Test Application"],
			moduleTypes = { "CLIMATE", "RADIO" }
		})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
				interiorVehicleDataCapabilities = {
					{
						climateControlCapabilities = commonRC.getClimateControlCapabilities(),
						radioControlCapabilities = commonRC.getRadioControlCapabilities()
					}
				}
			})
	end)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "SUCCESS",
			interiorVehicleDataCapabilities = {
				{
					climateControlCapabilities = commonRC.getClimateControlCapabilities(),
					radioControlCapabilities = commonRC.getRadioControlCapabilities()
				}
			}
		})

	commonTestCases:DelayedExp(commonRC.timeout)
end

local function step4(self)
	local cid = self.mobileSession:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = nil
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications["Test Application"],
			moduleTypes = nil
		})
	:Do(function(_, data)
			self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
				interiorVehicleDataCapabilities = {
					{
						climateControlCapabilities = commonRC.getClimateControlCapabilities(),
						radioControlCapabilities = commonRC.getRadioControlCapabilities()
					}
				}
			})
	end)

	EXPECT_RESPONSE(cid, {
			success = true,
			resultCode = "SUCCESS",
			interiorVehicleDataCapabilities = {
				{
					climateControlCapabilities = commonRC.getClimateControlCapabilities(),
					radioControlCapabilities = commonRC.getRadioControlCapabilities()
				}
			}
		})

	commonTestCases:DelayedExp(commonRC.timeout)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu)
runner.Title("Test")
runner.Step("GetInteriorVehicleDataCapabilities_CLIMATE", step1)
runner.Step("GetInteriorVehicleDataCapabilities_RADIO", step2)
runner.Step("GetInteriorVehicleDataCapabilities_CLIMATE_RADIO", step3)
runner.Step("GetInteriorVehicleDataCapabilities_absent", step4)
runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
