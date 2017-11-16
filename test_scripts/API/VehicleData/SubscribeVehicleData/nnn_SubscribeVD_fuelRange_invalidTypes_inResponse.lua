---------------------------------------------------------------------------------------------------
-- User story: TO ADD !!!
-- Use case: TO ADD !!!
--
-- Requirement summary:
-- [SubscribeVehicleData] As a mobile app wants to send a request to subscribe for specified parameter
--
-- Description:
-- In case:
-- 1) mobile application sends valid SubscribeVehicleData
-- 2) HMI responds to SDL with invalid types of fuelRange parametrs
-- SDL must:
-- Responds INVALID_DATA, success:false to mobile application
---------------------------------------------------------------------------------------------------

--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/VehicleData/commonVehicleData')
local commonTestCases = require("user_modules/shared_testcases/commonTestCases")
local fuelRangeValues = {
  invalidDataType = { dataType = 5, resultCode = "SUCCESS" },
  invalidResultCode = { dataType = "VEHICLEDATA_FUELRANGE", resultCode = 5.5 },
  invalidFuelRangeType = "string"
}

--[[ Local Functions ]]
local function SubscribeVDinvalidParamType(responseParams, self)
  local cid = self.mobileSession1:SendRPC("SubscribeVehicleData", { fuelRange = true })
  EXPECT_HMICALL("VehicleInfo.SubscribeVehicleData", { fuelRange = true })
  :Do(function(_,data)
    self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS",
    { fuelRange = responseParams })
  end)
  self.mobileSession1:ExpectResponse(cid, { success = false, resultCode = "INVALID_DATA" })
  commonTestCases:DelayedExp(common.timeout)
end

local function OnVD(self)
  self.hmiConnection:SendNotification("VehicleInfo.OnVehicleData", { fuelRange = {{ type = "DIESEL", range = 45.5 }}})
  self.mobileSession1:ExpectNotification("OnVehicleData", { })
  :Times(0)
  commonTestCases:DelayedExp(common.timeout)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI with PTU", common.registerAppWithPTU)
runner.Step("Activate App", common.activateApp)

runner.Title("Test")
for k, value in pairs(fuelRangeValues) do
  runner.Step("SubscribeVehicleData_fuelRange_" .. k, SubscribeVDinvalidParamType, { value })
  runner.Step("App_is_not_subcribed_still", OnVD)
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
