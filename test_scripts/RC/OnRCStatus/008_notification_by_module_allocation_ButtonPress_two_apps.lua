---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- [SDL_RC] TBD
--
-- Description: SDL shall send OnRCStatus notifications to rc registered apps
-- by allocation module via ButtonPress
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonOnRCStatus = require('test_scripts/RC/OnRCStatus/commonOnRCStatus')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local freeModules = commonOnRCStatus.getModules()
local allocatedModules = {}

local BPstructs = {
	CLIMATE = {
		moduleType = "CLIMATE",
		buttonName = "AC",
		buttonPressMode = "SHORT"
	},
	RADIO = {
		moduleType = "RADIO",
		buttonName = "VOLUME_UP",
		buttonPressMode = "LONG"
	}
}

--[[ Local Functions ]]
local function ButtonPress(pButVal)
	local pModuleStatus = commonOnRCStatus.SetModuleStatus(freeModules, allocatedModules, pButVal.moduleType)
	local cid = commonOnRCStatus.getMobileSession(1):SendRPC("ButtonPress",	pButVal)
	pButVal.appID = commonOnRCStatus.getHMIAppId()
	EXPECT_HMICALL("Buttons.ButtonPress", pButVal)
	:Do(function(_, data)
		commonOnRCStatus.getHMIconnection():SendResponse(data.id, data.method, "SUCCESS", {})
	end)
	commonOnRCStatus.getMobileSession(1):ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
	commonOnRCStatus.getMobileSession(1):ExpectNotification("OnRCStatus", pModuleStatus)
	commonOnRCStatus.getMobileSession(2):ExpectNotification("OnRCStatus", pModuleStatus)
	EXPECT_HMINOTIFICATION("RC.OnRCStatus", pModuleStatus)
	:Times(2)
	:ValidIf(commonOnRCStatus.validateHMIAppIds)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonOnRCStatus.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonOnRCStatus.start)
runner.Step("RAI, PTU", commonOnRCStatus.RegisterRCapplication)
runner.Step("Activate App", commonOnRCStatus.ActivateApp)
runner.Step("RAI, PTU for second app", commonOnRCStatus.RegisterRCapplication, { 2 })

runner.Title("Test")
for mod, _ in pairs(BPstructs) do
	runner.Step("ButtonPress " .. mod, ButtonPress, { BPstructs[mod] })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonOnRCStatus.postconditions)