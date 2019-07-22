---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0173-Read-Generic-Network-Signal-data.md
--
-- Description: Permissions for custom data from preloaded after 5 ignitionOff

-- Precondition:
-- 1. Preloaded file contains VehicleDataItems for all RPC spec VD and for one custom data
-- 3. App is registered and activated
-- 4. PTU is not performed
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
local utils = require('user_modules/utils')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
common.writeCustomDataToGeneralArray(common.customDataTypeSample)
common.setDefaultValuesForCustomData()

local appSessionId = 1
local vdItem = {
  name = "custom_vd_from_preloaded",
  type = "Integer",
  key = "OEM_REF_INT_PT",
  array = false,
  mandatory = false,
  minvalue = 0,
  maxvalue = 100
}
common.VehicleDataItemsWithData["custom_vd_from_preloaded"] = vdItem
common.VehicleDataItemsWithData["custom_vd_from_preloaded"]. value = 10

--[[ Local Functions ]]
local function updatePreloadedFile()
  local ptContent, ptFile = common.getPreloadedFileAndContent()
  ptContent.policy_table.functional_groupings["DataConsent-2"].rpcs = common.null

  ptContent.policy_table.functional_groupings.GroupWithAllVehicleData = common.cloneTable(
  ptContent.policy_table.functional_groupings["Emergency-1"])

  local rpcsGroupWithAllVehicleData = ptContent.policy_table.functional_groupings.GroupWithAllVehicleData.rpcs
  rpcsGroupWithAllVehicleData.GetVehicleData.parameters = { "gps", "custom_vd_from_preloaded" }
  rpcsGroupWithAllVehicleData.OnVehicleData.parameters = { "gps", "custom_vd_from_preloaded" }
  rpcsGroupWithAllVehicleData.SubscribeVehicleData.parameters = { "gps", "custom_vd_from_preloaded" }
  rpcsGroupWithAllVehicleData.UnsubscribeVehicleData.parameters = { "gps", "custom_vd_from_preloaded" }

  ptContent.policy_table.app_policies.default.groups = {"Base-4", "GroupWithAllVehicleData" }

  table.insert(ptContent.policy_table.vehicle_data.schema_items, vdItem)
  common.tableToJsonFile(ptContent, ptFile)
end

local function getOemCustomDataType(pItemName, pCustomTypeItem)
  local dataTypes = common.customDataTypeSample
  if type(pCustomTypeItem) == "table" then
    dataTypes = { pCustomTypeItem }
  end
  for _, customDataType in ipairs(dataTypes) do
    if customDataType.name == pItemName then
      return customDataType.type
    end
  end
  if pItemName == "custom_vd_from_preloaded" then
    local type = "Integer"
    return type
  end
  utils.cprint(35, "Warning: Custom data type '" .. pItemName .. "' does not exist")
  return nil
end

function common.buildSubscribeMobileResponseItem(pHmiResponseItem, pItemName, pCustomTypeItem)
  if type(pHmiResponseItem) == "table" then
    local res = utils.cloneTable(pHmiResponseItem)
    if res.dataType == common.CUSTOM_DATA_TYPE then
      res.oemCustomDataType = getOemCustomDataType(pItemName, pCustomTypeItem)
    end
    return res
  end
  return nil
end

-- [[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("UpdatePreloadedFile", updatePreloadedFile)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("App registration", common.registerApp)
runner.Step("App activation", common.activateApp)
runner.Step("SubscribeVehicleData gps", common.VDsubscription,
  { appSessionId, "gps", "SubscribeVehicleData" })
runner.Step("SubscribeVehicleData custom_vd_from_preloaded", common.VDsubscription,
  { appSessionId, "custom_vd_from_preloaded", "SubscribeVehicleData" })
runner.Title("Test")
for i=1, 5 do
  runner.Step("Ignition off " .. i, common.ignitionOff)
  runner.Step("Start SDL, HMI, connect Mobile, start Session " .. i, common.start)
  runner.Step("App registration after ign_off " .. i, common.registerAppWOPTU)
  runner.Step("App activation after ign_off " .. i, common.activateApp)
  runner.Step("SubscribeVehicleData gps", common.VDsubscription,
    { appSessionId, "gps", "SubscribeVehicleData" })
  runner.Step("SubscribeVehicleData custom_vd_from_preloaded", common.VDsubscription,
    { appSessionId, "custom_vd_from_preloaded", "SubscribeVehicleData" })
end

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
