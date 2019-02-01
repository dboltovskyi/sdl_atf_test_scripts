---------------------------------------------------------------------------------------------------
-- Proposal: https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0213-rc-radio-climate-parameter-update.md
-- Description:
-- Preconditions:
-- 1) Prepare testing HMI_capabilities.json file where parameter (climateEnableAvailable": false )
-- SDL did not received remoteControlCapability from HMI
-- In case:
-- 1) Mobile app sends GetSystemCapability (REMOTE_CONTROL) request to SDL
-- SDL must:
-- 1) use default capabiltites stored in the HMI_capabilities.json file and
-- 2) sends GetSystemCapability response with ( "climateControlCapabilities": { "climateEnableAvailable": false },
--    "resultCode": SUCCESS ) to Mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local commonRC = require('test_scripts/RC/commonRC')
local hmi_values = require('user_modules/hmi_values')
local utils = require("user_modules/utils")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local path_to_file = commonPreconditions:GetPathToSDL() .. "hmi_capabilities.json"
local defaulValue = utils.jsonFileToTable(path_to_file)

--[[ Local Functions ]]
local function getHMIParams()
  local params = hmi_values.getDefaultHMITable()
  params.RC.GetCapabilities = {{{}}}
  return params
end

local function updateDefaultHMIcapabilities()
  defaulValue.UI.systemCapabilities.remoteControlCapability.climateControlCapabilities[1].climateEnableAvailable = false
  utils.tableToJsonFile(defaulValue, path_to_file)
end

local function rpcSuccess()
  local cid = commonRC.getMobileSession():SendRPC("GetSystemCapability", { systemCapabilityType = "REMOTE_CONTROL" })
  commonRC.getMobileSession():ExpectResponse(cid, {
    success = true,
    resultCode = "SUCCESS",
    systemCapability = {
      remoteControlCapability = {
        climateControlCapabilities = defaulValue.climateControlCapabilities,
        radioControlCapabilities = defaulValue.radioControlCapabilities,
        audioControlCapabilities = defaulValue.audioControlCapabilities,
        hmiSettingsControlCapabilities = defaulValue.hmiSettingsControlCapabilities,
        lightControlCapabilities = defaulValue.lightControlCapabilities,
        buttonCapabilities = defaulValue.buttonCapabilities
      }
    }
  })
  :ValidIf(function()
    if defaulValue.UI.systemCapabilities.remoteControlCapability.climateControlCapabilities[1].climateEnableAvailable == false then
      return true
    else
      return false, "Parameter climateEnableAvailable is not updating"
    end
  end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Backup HMI capabilities file", commonRC.backupHMICapabilities)
runner.Step("Clean environment", commonRC.preconditions)
runner.Step("Update default hmi capabilities", updateDefaultHMIcapabilities)
runner.Step("Start SDL, HMI, connect Mobile, start Session", commonRC.start, { getHMIParams() })
runner.Step("RAI", commonRC.registerAppWOPTU)
runner.Step("Activate App", commonRC.activateApp)

runner.Title("Test")
runner.Step("GetSystemCapability_SUCCESS", rpcSuccess)

runner.Title("Postconditions")
runner.Step("Stop SDL", commonRC.postconditions)
runner.Step("Restore HMI capabilities file", commonRC.restoreHMICapabilities)
