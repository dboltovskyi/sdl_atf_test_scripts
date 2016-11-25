---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [SubscribeVehicleData] General ResultCode and the individual result codes for a part of parameters disallowed by Policies
--
-- Description:
-- SDL must:
-- - transfer the allowed params of SubscribeVehicleData to HMI
-- - get the response with <general_result_code_from_HMI> and allowed parameters with their correponding individual-result-codes from HMI
-- - respond to mobile application with "ResultCode: <general-result-code_from_HMI>, success: <applicable flag>"
-- + "info" parameter(listing the params disallowed by policies and the information about allowed params processing)
-- + allowed parameters and their correponding individual result codes got from HMI and all disallowed parameters
-- with the individual resultCode of DISALLOWED for NOT-allowed params of SubscribeVehicleData
-- In case:
-- - SubscribeVehicleData is allowed by policies with less than supported by protocol parameters
-- - AND the app assigned with such policies requests SubscribeVehicleData with one and-or more allowed params
-- and with one and-or more NOT-allowed params
--
-- Preconditions:
-- 1. Application with <appID> is registered on SDL.
-- 2. Specific permissions are assigned for <appID> with SubscribeVehicleData
-- Steps:
-- 1. Send SubscribeVehicleData RPC App -> SDL
-- 2. Verify status of response
--
-- Expected result:
-- SDL -> App:
-- General: success: true, resultCode: SUCCESS
-- Individual:
-- - for allowed: dataType: <parameter>, resultCode: SUCCESS
-- - for disallowed: dataType: <parameter>, resultCode: DISALLOWED
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

--[[ Required Shared libraries ]]
local testCasesForPolicyAppIdManagament = require("user_modules/shared_testcases/testCasesForPolicyAppIdManagament")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local testCasesForBuildingSDLPolicyFlag = require('user_modules/shared_testcases/testCasesForBuildingSDLPolicyFlag')

--[[ General Precondition before ATF start ]]
testCasesForBuildingSDLPolicyFlag:CheckPolicyFlagAfterBuild("EXTERNAL_PROPRIETARY")
commonFunctions:SDLForceStop()
commonSteps:DeleteLogsFileAndPolicyTable()

--[[ General Settings for configuration ]]
Test = require("connecttest")
require("user_modules/AppTypes")

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:UpdatePolicy()
  testCasesForPolicyAppIdManagament:updatePolicyTable(self, "files/jsons/Policies/App_Permissions/ptu_017.json")
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")
function Test:Test()
  local corId = self.mobileSession:SendRPC("SubscribeVehicleData",
    {
      speed = true,
      rpm = true,
      fuelLevel = true,
      fuelLevel_State = true,
      instantFuelConsumption = true,
    })
  EXPECT_HMICALL("VehicleInfo.SubscribeVehicleData",
    {
      speed = true,
      rpm = true,
      fuelLevel = true
    })
  :Do(function(_, d)
      self.hmiConnection:SendResponse(d.id, d.method, "SUCCESS",
        {
          speed = {dataType = "VEHICLEDATA_SPEED", resultCode = "SUCCESS"},
          rpm = {dataType = "VEHICLEDATA_RPM", resultCode = "SUCCESS"},
          fuelLevel = {dataType = "VEHICLEDATA_FUELLEVEL", resultCode = "SUCCESS"},
        })
    end)
  self.mobileSession:ExpectResponse(corId,
    {
      success = true,
      resultCode = "SUCCESS",
      speed = { dataType = "VEHICLEDATA_SPEED", resultCode = "SUCCESS" },
      rpm = { dataType = "VEHICLEDATA_RPM", resultCode = "SUCCESS" },
      fuelLevel = { dataType = "VEHICLEDATA_FUELLEVEL", resultCode = "SUCCESS" },
      fuelLevel_State = { dataType = "VEHICLEDATA_FUELLEVEL_STATE", resultCode = "DISALLOWED" },
      instantFuelConsumption = { dataType = "VEHICLEDATA_FUELCONSUMPTION", resultCode = "DISALLOWED" },
      info = "'fuelLevel_State', 'instantFuelConsumption' disallowed by policies."
    })
end

return Test
