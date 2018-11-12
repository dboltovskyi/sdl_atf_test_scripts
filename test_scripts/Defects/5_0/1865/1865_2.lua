---------------------------------------------------------------------------------------------------
-- Issue: https://github.com/SmartDeviceLink/sdl_core/issues/2353
--
-- Steps:
-- 1. HMI sends request (response, notification) with fake parameters that SDL should transfer to mobile.
--
-- Expected:
-- 1. validate received response
-- 2. cut off fake parameters
-- 3. transfer this request (response or notification) to mobile app
---------------------------------------------------------------------------------------------------
-- [[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('user_modules/sequences/actions')

-- [[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Functions ]]
local function subscribeVehicleData()
  local cid = common.getMobileSession():SendRPC("SubscribeVehicleData", { speed = true })
  common.getHMIConnection():ExpectRequest("VehicleInfo.SubscribeVehicleData", { speed = true })
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS")
    end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS"})
end

local function getVehicleData()
  local cid = common.getMobileSession():SendRPC("GetVehicleData", { speed = true })
  common.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { speed = true })
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { speed = 111, fake = "fake" })
    end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS", speed = 111 })
  :ValidIf(function(_, data)
      if data.payload.fake then
        return false, "Fake parameter is transferred to Mobile"
      end
      return true
    end)
end

local function onVehicleData()
  common.getHMIConnection():SendNotification("VehicleInfo.OnVehicleData", { speed = 123, fake = "fake" })
  common.getMobileSession():ExpectNotification("OnVehicleData", { speed = 123 })
  :ValidIf(function(_, data)
      if data.payload.fake then
        return false, "Fake parameter is transferred to Mobile"
      end
      return true
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("Register App", common.registerApp)
runner.Step("PTU", common.policyTableUpdate)
runner.Step("Activate App", common.activateApp)
runner.Step("SubscribeVehicleData", subscribeVehicleData)

-- [[ Test ]]
runner.Title("Test")
runner.Step("GetVehicleData", getVehicleData)
runner.Step("OnVehicleData", onVehicleData)

-- [[ Postconditions ]]
runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
