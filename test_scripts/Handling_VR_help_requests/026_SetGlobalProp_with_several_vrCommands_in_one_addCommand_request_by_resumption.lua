---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0122-New_rules_for_providing_VRHelpItems_VRHelpTitle.md
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary: TBD
--
-- Description:
-- In case:
-- 1. Command1 command with a few synonyms is added
-- 2. Perform reconnect
-- 3. SDL resumes commands
-- SDL does:
-- 3. send SetGlobalProperties with constructed the vrHelp and helpPrompt parameters using 1st synonym
-- by command resumption
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Handling_VR_help_requests/commonVRhelp')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local AddCommandParams = common.getAddCommandParams(1)
AddCommandParams.vrCommands = { "Command1_1", "Command2_1", "Command3_1" }

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerAppWOPTU)
runner.Step("Pin OnHashChange", common.pinOnHashChange)
runner.Step("App activation", common.activateApp)

runner.Title("Test")
runner.Step("AddCommand with several vrCommand", common.addCommandWithSetGP, { nil, AddCommandParams })
runner.Step("App reconnect", common.reconnect)
runner.Step("App resumption", common.registrationWithResumption,
  { 1, common.resumptionLevelFull, common.resumptionDataAddCommands })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
