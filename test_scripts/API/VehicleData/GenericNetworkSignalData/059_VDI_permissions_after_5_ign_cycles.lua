---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0173-Read-Generic-Network-Signal-data.md
--
-- Description: Permissions for custom data from PTU after 5 ignitionOff

-- Precondition:
-- 1. Preloaded file contains VehicleDataItems for all RPC spec VD
-- 3. App is registered and activated
-- 4. PTU is performed with VehicleDataItems in update file
-- 5. VehicleData from VehicleDataItems are defined in parameters of functional group for application

-- Sequence:
-- 1. Ignition off is performed 5 times
-- 2. App is registered after ignition off
-- 4. App requests SubscribeVehicleData
--   a. SDL process SubscribeVehicleData successfully without any changes after SDL
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/API/VehicleData/GenericNetworkSignalData/commonGenericNetSignalData')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
common.writeCustomDataToGeneralArray(common.customDataTypeSample)
common.setDefaultValuesForCustomData()

local appSessionId = 1

-- [[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("App activation", common.activateApp)
runner.Step("PTU with VehicleDataItems", common.policyTableUpdateWithOnPermChange, { common.ptuFuncWithCustomData })

runner.Title("Test")
for i=1, 5 do
  runner.Step("Ignition off " .. i, common.ignitionOff)
  runner.Step("Start SDL, HMI, connect Mobile, start Session " .. i, common.start)
  runner.Step("App registration after ign_off " .. i, common.registerAppWOPTU)
  runner.Step("App activation after ign_off " .. i, common.activateApp)
  runner.Step("SubscribeVehicleData gps " .. i, common.VDsubscription,
    { appSessionId, "gps", "SubscribeVehicleData" })
  runner.Step("SubscribeVehicleData custom_vd_item1_integer " .. i, common.VDsubscription,
    { appSessionId, "custom_vd_item1_integer", "SubscribeVehicleData" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
