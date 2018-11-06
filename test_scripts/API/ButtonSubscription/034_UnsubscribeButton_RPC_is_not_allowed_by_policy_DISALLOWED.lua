---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0192-button_subscription_response_from_hmi.md
-- User story: TBD
-- Use case: TBD
--
-- Requirement summary: TBD
--
-- Description:
-- In case:
-- 1) UnsubscribeButton RPC is not allowed by policy
-- 2) Mobile app requests UnsubscribeButton
-- SDL does:
-- 1) Respond UnsubscribeButton(DISALLOWED) to mobile app
-- 2) Not send OnHashChange with updated hashId to mobile app
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/ButtonSubscription/common_buttonSubscription')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local variable ]]
local errorCode = "DISALLOWED"
local buttonName = "PRESET_1"

--[[ Local Functions ]]
local function pTUpdateFunc(pTbl)
    pTbl.policy_table.functional_groupings["Base-4"].rpcs.UnsubscribeButton = nil
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("PTU", common.policyTableUpdate, { pTUpdateFunc })
runner.Step("App activation", common.activateApp)
runner.Step("SubscribeButton " .. buttonName, common.rpcSuccess, { 1, "SubscribeButton", buttonName })
runner.Step("On Button Press " .. buttonName, common.buttonPress, { 1, buttonName })

runner.Title("Test")
runner.Step("UnsubscribeButton on " .. buttonName .. " button, Disalloved",
    common.rpcUnsuccess, { 1, "UnsubscribeButton", buttonName, errorCode })
runner.Step("Button  " .. buttonName .. " still subscribed", common.buttonPress, { 1, buttonName })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
