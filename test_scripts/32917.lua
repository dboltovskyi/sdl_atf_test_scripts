---------------------------------------------------------------------------------------------------
--
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('user_modules/sequences/actions')
local utils = require("user_modules/utils")
local hmi_values = require('user_modules/hmi_values')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local grp = {
  [1] = { name = "Location-1", consentPrompt = "Location" },
  [2] = { name = "Dummy-1", consentPrompt = "Dummy" }
}

--[[ Local Functions ]]
function utils.getDeviceName()
  return config.mobileHost
end

local function getHMIValues()
  local params = hmi_values.getDefaultHMITable()
  params.RC = nil
  return params
end

local function ptUpdate(pTbl)
  local fg = pTbl.policy_table.functional_groupings
  fg[grp[2].name] = utils.cloneTable(fg[grp[1].name])
  fg[grp[2].name].user_consent_prompt = grp[2].consentPrompt
  fg[grp[2].name].rpcs.GetVehicleData.parameters = { "aaa" }
  pTbl.policy_table.app_policies[common.getConfigAppParams().appID].groups = { "Base-4", grp[1].name, grp[2].name }
end

local function getGroupId(pData, pGrpName)
  for i = 1, #pData.result.allowedFunctions do
    if(pData.result.allowedFunctions[i].name == pGrpName) then
      return pData.result.allowedFunctions[i].id
    end
  end
end

local function getListOfPermissions()
  local rid = common.getHMIConnection():SendRequest("SDL.GetListOfPermissions")
  common.getHMIConnection():ExpectResponse(rid)
  :Do(function(_,data)
      for i = 1, #grp do
        grp[i].id = getGroupId(data, grp[i].consentPrompt)
        print("Grp " .. i .. " Id: ", tostring(grp[i].id))
      end
    end)
end

local function consentGroup(pGrpId)
  common.getHMIConnection():SendNotification("SDL.OnAppPermissionConsent", {
      appID = common.getHMIAppId,
      source = "GUI",
      consentedFunctions = {{ name = grp[pGrpId].consentPrompt, id = grp[pGrpId].id, allowed = true }}
    })
  common.getMobileSession():ExpectNotification("OnPermissionsChange")
  :Do(function(_, data)
      -- utils.printTable(data)
    end)
end

local function getVD()
  local cid = common.getMobileSession():SendRPC("GetVehicleData", { speed = true })
  common.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData")
  :Do(function(_,data)
      common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { speed = 1.11 })
    end)
  common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
  :Do(function(_, data)
      utils.printTable(data.payload)
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start, { getHMIValues() })
runner.Step("Register App", common.registerApp)
runner.Step("Activate App", common.activateApp)
runner.Step("PolicyTableUpdate", common.policyTableUpdate, { ptUpdate })

runner.Title("Test")
runner.Step("Send GetListOfPermissions", getListOfPermissions)
runner.Step("Consent Group 1", consentGroup, { 1 })
runner.Step("Consent Group 2", consentGroup, { 2 })
runner.Step("Send GetVehicleData", getVD)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
