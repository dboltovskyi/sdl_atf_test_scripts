---------------------------------------------------------------------------------------------------
-- User story: TO ADD !!!
-- Use case: TO ADD !!!
-- Item: Use Case 1: TO ADD!!!
--
-- Requirement summary:
-- [OnVehicleData] As a mobile app is subscribed for VI parameter
-- and received notification about this parameter change from hmi
--
-- Description:
-- In case:
-- 1) If application is subscribed to get vehicle data with 'engineOilLife' parameter
-- 2) Parameter is disallowed by Policies in this notification
-- 3) Notification about changes in subscribed parameter is received from hmi
-- SDL must:
-- Ignore this notification and not send to mobile application
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
    }
  },
  turnSignal = "OFF"
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

local function checkNotificationIgnored()
  common.getHMIConnection():SendNotification("VehicleInfo." .. rpc2.name, rpc2.params)
  common.getMobileSession():ExpectNotification("OnVehicleData", rpc2.params):Times(0)
end

local function ptUpdate(pTbl)
  pTbl.policy_table.app_policies[common.getConfigAppParams().fullAppID].groups = { "Base-4", "Emergency-1" }
  local grp = pTbl.policy_table.functional_groupings["Emergency-1"]
  for _, v in pairs(grp.rpcs) do
    v.parameters = { "gps" }
  end
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
common.Step("RAI", common.registerApp, { 2 })
common.Step("PTU", common.policyTableUpdate, { ptUpdate })
common.Step("RPC " .. rpc2.name, checkNotificationIgnored)

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
