---------------------------------------------------------------------------------------------------
-- User story: TO ADD !!!
-- Use case: TO ADD !!!
-- Item: Use Case 1: Main Flow
-- Item: Use Case: request is allowed by Policies
--
-- Requirement summary:
-- [OnVehicleData] As a hmi sends notificarion about VI paramter change
--  but mobile app is not subscribed for this parameter
--
-- Description:
-- In case:
-- 1) Hmi sends valid OnVehicleData notification to SDL
--    but mobile app is not subscribed for this parameter
-- SDL must:
-- Ignore this request and do not forward it to mobile app
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local common = require('test_scripts/API/VehicleData/commonVehicleData')

--[[ Local Variables ]]
local rpc1 = {
  name = "SubscribeVehicleData",
  params = {
    engineOilLife = true,
    fuelRange = true,
    tirePressure = true,
    electronicParkBrakeStatus = true,
    turnSignal = true
  }
}

local rpc2 = {
  name = "OnVehicleData",
  params = {
    engineOilLife = 50.3,
    fuelRange = {
      {
        type = "GASOLINE",
        range = 400.00
      }
    },
    tirePressure = {
      leftFront = {
        status = "NORMAL",
        tpms = "SYSTEM_ACTIVE",
        pressure = 35.00
      },
      rightFront = {
        status = "NORMAL",
        tpms = "SYSTEM_ACTIVE",
        pressure = 35.00
      }
    },
    electronicParkBrakeStatus = "CLOSED",
    turnSignal = "OFF"
  }
}

local rpc3 = {
  name = "UnsubscribeVehicleData",
  params = {
    engineOilLife = true,
    fuelRange = true,
    tirePressure = true,
    electronicParkBrakeStatus = true,
    turnSignal = true
  }
}

local vehicleDataResults = {
  engineOilLife = {
    dataType = "VEHICLEDATA_ENGINEOILLIFE",
    resultCode = "SUCCESS"
  },
  fuelRange = {
    dataType = "VEHICLEDATA_FUELRANGE",
    resultCode = "SUCCESS"
  },
  tirePressure = {
    dataType = "VEHICLEDATA_TIREPRESSURE",
    resultCode = "SUCCESS"
  },
  electronicParkBrakeStatus = {
    dataType = "VEHICLEDATA_ELECTRONICPARKBRAKESTATUS",
    resultCode = "SUCCESS"
  },
  turnSignal = {
    dataType = "VEHICLEDATA_TURNSIGNAL",
    resultCode = "SUCCESS"
  }
}

--[[ Local Functions ]]
local function processRPCSubscribeSuccess()
  local cid = common.getMobileSession():SendRPC(rpc1.name, rpc1.params)
  common.getHMIConnection():ExpectRequest("VehicleInfo." .. rpc1.name, rpc1.params)
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS",
        vehicleDataResults)
    end)
  local responseParams = vehicleDataResults
  responseParams.success = true
  responseParams.resultCode = "SUCCESS"
  common.getMobileSession():ExpectResponse(cid, responseParams)
end

local function processRPCUnsubscribeSuccess()
  local cid = common.getMobileSession():SendRPC(rpc3.name, rpc3.params)
  common.getHMIConnection():ExpectRequest("VehicleInfo." .. rpc3.name, rpc3.params)
  :Do(function(_, data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS",
        vehicleDataResults)
    end)
  local responseParams = vehicleDataResults
  responseParams.success = true
  responseParams.resultCode = "SUCCESS"
  common.getMobileSession():ExpectResponse(cid, responseParams)
end

local function checkNotificationSuccess()
  common.getHMIConnection():SendNotification("VehicleInfo." .. rpc2.name, rpc2.params)
  common.getMobileSession():ExpectNotification("OnVehicleData", rpc2.params)
end

local function checkNotificationIgnored()
  common.getHMIConnection():SendNotification("VehicleInfo." .. rpc2.name, rpc2.params)
  common.getMobileSession():ExpectNotification("OnVehicleData", rpc2.params):Times(0)
  common.wait()
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
common.Step("RAI", common.registerApp)
common.Step("PTU", common.policyTableUpdate, { common.ptUpdate })
common.Step("Activate App", common.activateApp)

common.Title("Test")
common.Step("RPC " .. rpc1.name, processRPCSubscribeSuccess)
common.Step("RPC " .. rpc2.name .. " forwarded to mobile", checkNotificationSuccess)
common.Step("RPC " .. rpc3.name, processRPCUnsubscribeSuccess)
common.Step("RPC " .. rpc2.name .. " not forwarded to mobile", checkNotificationIgnored)

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
