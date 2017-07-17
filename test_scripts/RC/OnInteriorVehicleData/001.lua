---------------------------------------------------------------------------------------------------
-- RPC: OnInteriorVehicleData
-- Script: 001
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local commonRC = require('test_scripts/RC/commonRC')
local runner = require('user_modules/script_runner')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')

--[[ Local Variables ]]
local modules = { "CLIMATE" , "RADIO" }

--[[ Local Functions ]]
local function subscriptionToModule(pModuleType, pSubscribe, self)
  local cid = self.mobileSession:SendRPC("GetInteriorVehicleData", {
      moduleDescription = {
        moduleType = pModuleType
      },
      subscribe = pSubscribe
    })

  EXPECT_HMICALL("RC.GetInteriorVehicleData", {
      appID = self.applications["Test Application"],
      moduleDescription = {
        moduleType = pModuleType
      },
      subscribe = pSubscribe
    })
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {
          moduleData = commonRC.getModuleControlData(pModuleType),
          isSubscribed = pSubscribe
        })
    end)

  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS",
      moduleData = commonRC.getModuleControlData(pModuleType),
      isSubscribed = pSubscribe
    })
end

local function isSubscribed(pModuleType, self)
  self.hmiConnection:SendNotification("RC.OnInteriorVehicleData", {
      moduleData = commonRC.getAnotherModuleControlData(pModuleType)
    })

  EXPECT_NOTIFICATION("OnInteriorVehicleData", {
      moduleData = commonRC.getAnotherModuleControlData(pModuleType)
    })
end

local function isUnsubscribed(pModuleType, self)
  self.hmiConnection:SendNotification("RC.OnInteriorVehicleData", {
      moduleData = commonRC.getAnotherModuleControlData(pModuleType)
    })

  EXPECT_NOTIFICATION("OnInteriorVehicleData", {}):Times(0)
  commonTestCases:DelayedExp(commonRC.timeout)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start)
runner.Step("RAI, PTU", commonRC.rai_ptu)

runner.Title("Test")

for _, mod in pairs(modules) do
  runner.Step("Subscribe app to " .. mod, subscriptionToModule, { mod, true })
  runner.Step("Send notification OnInteriorVehicleData " .. mod .. ". App subscribed", isSubscribed, { mod })
end

for _, mod in pairs(modules) do
  runner.Step("Unsubscribe app to " .. mod, subscriptionToModule, { mod, false })
  runner.Step("Send notification OnInteriorVehicleData " .. mod .. ". App unsubscribed", isUnsubscribed, { mod })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
