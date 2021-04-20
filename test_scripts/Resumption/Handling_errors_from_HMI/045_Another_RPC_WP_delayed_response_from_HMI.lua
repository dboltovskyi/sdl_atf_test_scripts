---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0190-resumption-data-error-handling.md
--
-- Description:
-- Check way points data resumption is failed in case if HMI responds with error to non way points data request
-- and success to way points data request with some delay
--
-- In case:
-- 1. App successfully added SubMenu and is subscribed to Way Points (WP)
-- 2. Unexpected disconnect and reconnect are performed
-- 3. App re-registers with actual HashId
-- SDL does:
--  - start resumption process for App
--  - send UI.AddSubMenu, Navi.SubscribeWayPoints requests to HMI
-- 4. HMI responds with error for 'UI.AddSubMenu' request and after with success for 'Navi.SubscribeWayPoints'
-- SDL does:
--  - process responses from HMI
--  - remove already restored data
--  - send Navi.UnsubscribeWayPoints request to HMI
--  - respond RegisterAppInterfaceResponse(success=true,result_code=RESUME_FAILED) to mobile application
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Resumption/Handling_errors_from_HMI/commonResumptionErrorHandling')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function reRegisterAppsCustom_AnotherRPC()
  common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered")
  :Do(function(exp, data)
      common.log("BC.OnAppRegistered " .. exp.occurences)
      common.setHMIAppId(data.params.application.appID, exp.occurences)
      common.sendOnSCU(0, exp.occurences)
    end)

  common.getHMIConnection():ExpectRequest("UI.AddSubMenu")
  :Do(function(_, data)
      common.log(data.method)
      common.errorResponse(data, 0)
    end)

  common.getHMIConnection():ExpectRequest("Navigation.SubscribeWayPoints")
  :Do(function(_, data)
      common.log(data.method)
      common.run.runAfter(function()
        common.log(data.method .. ": SUCCESS")
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
      end, 1000)
    end)

  common.getHMIConnection():ExpectRequest("Navigation.UnsubscribeWayPoints")
  :Do(function(_, data)
      common.log(data.method)
      common.log(data.method .. ": SUCCESS")
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
    end)

  common.expOnHMIStatus(1, "FULL")

  common.reRegisterAppCustom(1, "RESUME_FAILED", 0)
end

local function sendOnWayPointChange(pIsExpApp)
  local occurences = pIsExpApp == true and 1 or 0
  local params = {
    wayPoints = {
      {
        coordinate = {
          latitudeDegrees = -90,
          longitudeDegrees = -180
        }
      }
    }
  }
  common.getHMIConnection():SendNotification("Navigation.OnWayPointChange", params)
  common.getMobileSession():ExpectNotification("OnWayPointChange", params):Times(occurences)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)

runner.Title("Test")
runner.Step("Register app1", common.registerAppWOPTU)
runner.Step("Activate app1", common.activateApp)
runner.Step("Add for app1 subscribeWayPoints", common.subscribeWayPoints)
runner.Step("Add for app1 addSubMenu", common.addSubMenu)
runner.Step("Check subscriptions for WayPoints", sendOnWayPointChange, { true })
runner.Step("Unexpected disconnect", common.unexpectedDisconnect)
runner.Step("Connect mobile", common.connectMobile)
runner.Step("openRPCserviceForApp1", common.openRPCservice, { 1 })
runner.Step("Reregister Apps resumption", reRegisterAppsCustom_AnotherRPC)
runner.Step("Check subscriptions for WayPoints", sendOnWayPointChange, { false })

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
