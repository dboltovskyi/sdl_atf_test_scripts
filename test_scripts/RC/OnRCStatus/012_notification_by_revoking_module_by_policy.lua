---------------------------------------------------------------------------------------------------
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary:
-- [SDL_RC] TBD
--
-- Description: SDL shall send OnRCStatus notifications to registered mobile application and to the HMI by
-- policy update, allocated module is revoked in update
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonOnRCStatus = require('test_scripts/RC/OnRCStatus/commonOnRCStatus')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local freeModules = commonOnRCStatus.getModules()
local allocatedModules = { }

--[[ Local Functions ]]
local function PTUfunc(tbl)
  local appId1 = config.application1.registerAppInterfaceParams.appID
  tbl.policy_table.app_policies[appId1] = commonOnRCStatus.getRCAppConfig()
  tbl.policy_table.app_policies[appId1].moduleType = { "RADIO" }
  local appId2 = config.application2.registerAppInterfaceParams.appID
  tbl.policy_table.app_policies[appId2] = commonOnRCStatus.getRCAppConfig()
end

local function AlocateModule(pModuleType)
  local ModulesStatus = commonOnRCStatus.SetModuleStatus(freeModules, allocatedModules, pModuleType)
  commonOnRCStatus.rpcAllowed(pModuleType, 1, "SetInteriorVehicleData")
  commonOnRCStatus.getMobileSession(1):ExpectNotification("OnRCStatus", ModulesStatus)
  EXPECT_HMINOTIFICATION("RC.OnRCStatus", ModulesStatus)
  :ValidIf(commonOnRCStatus.validateHMIAppIds)
end

local function RegistrationAppWithRevokingModule()
  commonOnRCStatus.rai_ptu_n(PTUfunc, 2)
  local NotifParamsRegister = {
    freeModules = commonOnRCStatus.ModulesArray(freeModules),
    allocatedModules = commonOnRCStatus.ModulesArray(allocatedModules)
  }
  local NotifParamsRevoke = {
    freeModules = commonOnRCStatus.ModulesArray(commonOnRCStatus.getModules()),
    allocatedModules = { }
  }
  commonOnRCStatus.getMobileSession(2):ExpectNotification("OnRCStatus", NotifParamsRegister, NotifParamsRevoke)
  :Times(2)
  commonOnRCStatus.getMobileSession(1):ExpectNotification("OnRCStatus", NotifParamsRegister, NotifParamsRevoke)
  :Times(2)
  EXPECT_HMINOTIFICATION("RC.OnRCStatus", NotifParamsRegister, NotifParamsRevoke)
  :Times(4)
  :ValidIf(commonOnRCStatus.validateHMIAppIds)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonOnRCStatus.preconditions, { 1 })
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonOnRCStatus.start)
runner.Step("First app registration", commonOnRCStatus.RegisterRCapplication)
runner.Step("Activate first app", commonOnRCStatus.ActivateApp)
runner.Step("Allocating module CLIMATE", AlocateModule, { "CLIMATE" })

runner.Title("Test")
runner.Step("OnRCStatus by PTU with revoking of allocated module", RegistrationAppWithRevokingModule)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonOnRCStatus.postconditions)