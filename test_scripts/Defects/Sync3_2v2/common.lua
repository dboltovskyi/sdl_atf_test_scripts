---------------------------------------------------------------------------------------------------
-- Issue 32917
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('user_modules/sequences/actions')
local utils = require("user_modules/utils")
local hmi_values = require('user_modules/hmi_values')

local m = common

function utils.getDeviceName()
  return config.mobileHost
end

function m.getHMIValues()
  local params = hmi_values.getDefaultHMITable()
  params.RC = nil
  return params
end

local ptuOrig = common.policyTableUpdate

function m.policyTableUpdate(pTC)
  local dfltGrpData = {
    rpcs = {
      GetVehicleData = {
        hmi_levels = { "BACKGROUND", "FULL", "LIMITED" }
      }
    }
  }
  local function ptUpdate(pTbl)
    local fg = pTbl.policy_table.functional_groupings
    for i = 1, #pTC.grp do
      fg[pTC.grp[i].name] = utils.cloneTable(dfltGrpData)
      fg[pTC.grp[i].name].user_consent_prompt = pTC.grp[i].prompt
      fg[pTC.grp[i].name].rpcs.GetVehicleData.parameters = pTC.grp[i].params
    end
    pTbl.policy_table.app_policies[common.getConfigAppParams().appID].groups = { "Base-4", pTC.grp[1].name, pTC.grp[2].name }
  end
  ptuOrig(ptUpdate)
end

local function getGroupId(pData, pGrpName)
  for i = 1, #pData.result.allowedFunctions do
    if(pData.result.allowedFunctions[i].name == pGrpName) then
      return pData.result.allowedFunctions[i].id
    end
  end
end

function m.getListOfPermissions(pTC)
  local rid = common.getHMIConnection():SendRequest("SDL.GetListOfPermissions")
  common.getHMIConnection():ExpectResponse(rid)
  :Do(function(_,data)
      for i = 1, #pTC.grp do
        pTC.grp[i].id = getGroupId(data, pTC.grp[i].prompt)
        print("Grp " .. i .. " Id: ", tostring(pTC.grp[i].id))
      end
    end)
end

local function consentGroupsByAFewMsg(pTC)
  for i = 1, #pTC.grp do
    common.getHMIConnection():SendNotification("SDL.OnAppPermissionConsent", {
        appID = common.getHMIAppId,
        source = "GUI",
        consentedFunctions = {{ name = pTC.grp[i].prompt, id = pTC.grp[i].id, allowed = true }}
      })
  end
  common.getMobileSession():ExpectNotification("OnPermissionsChange")
  :Times(#pTC.grp)
end

local function consentGroupsBySingleMsg(pTC)
  local consentedFunctions = {}
  for i = 1, #pTC.grp do
    table.insert(consentedFunctions, { name = pTC.grp[i].prompt, id = pTC.grp[i].id, allowed = true })
  end
  common.getHMIConnection():SendNotification("SDL.OnAppPermissionConsent", {
      appID = common.getHMIAppId,
      source = "GUI",
      consentedFunctions = consentedFunctions
    })
  common.getMobileSession():ExpectNotification("OnPermissionsChange")
end

function m.consentGroups(pTC)
  consentGroupsByAFewMsg(pTC)
end

function m.getVD(pTC)
  local cid = common.getMobileSession():SendRPC("GetVehicleData", { speed = true })
  if pTC.success == true then
    common.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData")
    :Do(function(_,data)
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { speed = 1.11 })
      end)
  end
  common.getMobileSession():ExpectResponse(cid, { success = pTC.success, resultCode = pTC.resultCode })
  :Do(function(_, data)
      utils.printTable(data.payload)
    end)
end

return m
