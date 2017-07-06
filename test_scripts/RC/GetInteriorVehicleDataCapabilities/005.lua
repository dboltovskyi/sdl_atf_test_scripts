---------------------------------------------------------------------------------------------------
-- RPC: GetInteriorVehicleDataCapabilities
-- Script: 001
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local runner = require('user_modules/script_runner')

--[[ Local Functions ]]
local function step(self, id)
	local session = self.mobileSession
	if id == 2 then
		session = self.mobileSession2
	end
	local cid = session:SendRPC("GetInteriorVehicleDataCapabilities", {
			moduleTypes = { "CLIMATE" }
		})

	EXPECT_HMICALL("RC.GetInteriorVehicleDataCapabilities", {
			appID = self.applications[config["application" .. id].registerAppInterfaceParams.appID],
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

	session:ExpectResponse(cid, {
			success = true,
			resultCode = "SUCCESS",
			interiorVehicleDataCapabilities = {
				{
					climateControlCapabilities = commonRC.getClimateControlCapabilities()
				}
			}
		})
end

local function step1(self)
	step(self, 1)
end

local function step2(self)
	step(self, 2)
end

local function ptu_update_func(tbl)
	tbl.policy_table.app_policies[config.application2.registerAppInterfaceParams.appID] = {
      keep_context = false,
      steal_focus = false,
      priority = "NONE",
      default_hmi = "NONE",
      moduleType = { "RADIO", "CLIMATE" },
      groups = { "Base-4" },
      groups_primaryRC = { "Base-4", "RemoteControl" },
      AppHMIType = { "REMOTE_CONTROL" }
    }
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI1, PTU", commonRC.rai_ptu, { ptu_update_func })
runner.Step("RAI2, PTU", commonRC.rai2)
runner.Title("Test")
runner.Step("GetInteriorVehicleDataCapabilities_App1", step1)
runner.Step("GetInteriorVehicleDataCapabilities_App2", step2)
runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
