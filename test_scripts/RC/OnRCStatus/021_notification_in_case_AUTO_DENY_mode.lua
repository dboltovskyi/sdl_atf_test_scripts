---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- [SDL_RC] TBD
--
-- Description: SDL shall not send OnRCStatus notifications to rc registered apps and to HMI
-- in case HMI responds with IN_USE result code to allocation request from second app
-- because of HMI access mode is AUTO_DENY
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonOnRCStatus = require('test_scripts/RC/OnRCStatus/commonOnRCStatus')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local freeModules = commonOnRCStatus.getModules()
local allocatedModules = {}

--[[ Local Functions ]]
local function AlocateModule(pModuleType)
  local ModulesStatus = commonOnRCStatus.SetModuleStatus(freeModules, allocatedModules, pModuleType)
  commonOnRCStatus.rpcAllowed(pModuleType, 1, "SetInteriorVehicleData")
  commonOnRCStatus.getMobileSession(1):ExpectNotification("OnRCStatus", ModulesStatus)
  commonOnRCStatus.getMobileSession(2):ExpectNotification("OnRCStatus", ModulesStatus)
  EXPECT_HMINOTIFICATION("RC.OnRCStatus", ModulesStatus)
  :Times(2)
  :ValidIf(commonOnRCStatus.validateHMIAppIds)
end

local function AllocateModuleFromSecondApp(pModuleType)
  local cid = commonOnRCStatus.getMobileSession(2):SendRPC("SetInteriorVehicleData",
    { moduleData = commonOnRCStatus.getSettableModuleControlData(pModuleType) })
  EXPECT_HMICALL("RC.SetInteriorVehicleData")
  :Times(0)
  commonOnRCStatus.getMobileSession(2):ExpectResponse(cid, { success = false, resultCode = "IN_USE" })
  commonOnRCStatus.getMobileSession(2):ExpectNotification("OnRCStatus")
  :Times(0)
  commonOnRCStatus.getMobileSession(1):ExpectNotification("OnRCStatus")
  :Times(0)
  EXPECT_HMINOTIFICATION("RC.OnRCStatus")
  :Times(0)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonOnRCStatus.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonOnRCStatus.start)
runner.Step("Set AccessMode AUTO_DENY", commonOnRCStatus.defineRAMode, { true, "AUTO_DENY" })
runner.Step("RAI, PTU App1", commonOnRCStatus.RegisterRCapplication, { 1 })
runner.Step("RAI, PTU App2", commonOnRCStatus.RegisterRCapplication, { 2 })
runner.Step("Activate App1", commonOnRCStatus.ActivateApp, { 1 })

runner.Title("Test")
runner.Step("Allocation of module by App1", AlocateModule, { "CLIMATE" })
runner.Step("Activate App2", commonOnRCStatus.ActivateApp, { 2 })
runner.Step("Rejected allocation of module by App2", AllocateModuleFromSecondApp, { "CLIMATE" })

runner.Title("Postconditions")
runner.Step("Stop SDL", commonOnRCStatus.postconditions)