---------------------------------------------------------------------------------------------------
-- Issue:
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('user_modules/sequences/actions')
local runner = require('user_modules/script_runner')
local utils = require('user_modules/utils')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false
config.application1.registerAppInterfaceParams.appHMIType = { "MEDIA" }
config.application1.registerAppInterfaceParams.isMediaApplication = true
config.application2.registerAppInterfaceParams.appHMIType = { "DEFAULT" }
config.application2.registerAppInterfaceParams.isMediaApplication = false

--[[ Local Variables ]]
local pButName = "PLAY_PAUSE" -- SEEKLEFT

--[[ Local Functions ]]
function common.activateApp(pAppId)
  if not pAppId then pAppId = 1 end
  local cid = common.getHMIConnection():SendRequest("SDL.ActivateApp", { appID = common.getHMIAppId(pAppId) })
  common.getHMIConnection():ExpectResponse(cid)
  common.getMobileSession(pAppId):ExpectNotification("OnHMIStatus", { hmiLevel = "FULL", systemContext = "MAIN" })
  utils.wait()
end

local function subscribeButtonMediaApp(pAppId)
  local cid = common.getMobileSession(pAppId):SendRPC("SubscribeButton", { buttonName = pButName })
  common.getHMIConnection():ExpectNotification("Buttons.OnButtonSubscription",
    { appID = common.getHMIAppId(), name = pButName, isSubscribed = true })
  common.getMobileSession(pAppId):ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  common.getMobileSession(pAppId):ExpectNotification("OnHashChange")
end

local function subscribeButtonNonMediaApp(pAppId)
  local cid = common.getMobileSession(pAppId):SendRPC("SubscribeButton", { buttonName = pButName })
  common.getHMIConnection():ExpectNotification("Buttons.OnButtonSubscription")
  :Times(0)
  common.getMobileSession(pAppId):ExpectResponse(cid, { success = false, resultCode = "REJECTED" })
  common.getMobileSession(pAppId):ExpectNotification("OnHashChange")
  :Times(0)
end

local function buttonEventPress(pAppId)
  common.getHMIConnection():SendNotification("Buttons.OnButtonEvent",
    { appID = common.getHMIAppId(pAppId), name = pButName, mode = "BUTTONDOWN" })
  common.getHMIConnection():SendNotification("Buttons.OnButtonEvent",
    { appID = common.getHMIAppId(pAppId), name = pButName, mode = "BUTTONUP" })
  common.getHMIConnection():SendNotification("Buttons.OnButtonPress",
    { appID = common.getHMIAppId(pAppId), name = pButName, mode = "SHORT" })
end

local function onButtonPressMediaApp(pAppId)
  buttonEventPress(pAppId)
  common.getMobileSession(pAppId):ExpectNotification("OnButtonEvent",
    { buttonName = pButName, buttonEventMode = "BUTTONDOWN" },
    { buttonName = pButName, buttonEventMode = "BUTTONUP" })
  :Times(2)
  common.getMobileSession(pAppId):ExpectNotification("OnButtonPress",
    { buttonName = pButName, buttonPressMode = "SHORT" })
end

local function onButtonPressNonMediaApp(pAppId)
  buttonEventPress(pAppId)
  common.getMobileSession(pAppId):ExpectNotification("OnButtonEvent")
  :Times(0)
  common.getMobileSession(pAppId):ExpectNotification("OnButtonPress")
  :Times(0)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile", common.start)

runner.Title("Test")

runner.Step("Register App 1", common.registerApp, { 1 })
runner.Step("Activate App 1", common.activateApp, { 1 })
runner.Step("Subscribe button Media app", subscribeButtonMediaApp, { 1 })
runner.Step("OnButtonPress Media app", onButtonPressMediaApp, { 1 })

runner.Step("Register App 2", common.registerApp, { 2 })
runner.Step("Activate App 2", common.activateApp, { 2 })
runner.Step("Subscribe button Non-Media app", subscribeButtonNonMediaApp, { 2 })
runner.Step("OnButtonPress Non-Media app", onButtonPressNonMediaApp, { 2 })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
