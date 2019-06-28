---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md

-- Description:
-- Verify the value for `requireEncryption` in OnPermissionsChange at top and functional group levels after PTU
-- in case if a new group is assigned with specific `requireEncryption` values

-- Sequence:
-- 1) Define initial values of requireEncryption flags for app and particular functional group in preloaded file
-- 2) Start SDL, HMI, connect mobile, register app
-- 3) Perform PTU and set new values for requireEncryption flags at top and functional group levels
-- by assigning new functional group
-- 4) Check which values are sent by SDL in OnPermissionsChange notification
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Security/RPCMessageProtection/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local states = {
  [1] = { app = true,  fg = true },
  [2] = { app = true,  fg = false },
  [3] = { app = true,  fg = nil },
  [4] = { app = false, fg = true },
  [5] = { app = false, fg = false },
  [6] = { app = false, fg = nil },
  [7] = { app = nil,   fg = true },
  [8] = { app = nil,   fg = false },
  [9] = { app = nil,   fg = nil }
}

local transitions = common.getTransitions(states, 21, 40)

-- transitions = { [001] = { from = 1, to = 1 } }

local failedTCs = { }

--[[ Local Functions ]]
local function updatePreloadedPT(pAppPolicy, pFuncGroup)
  local function pPTUpdateFunc(pTbl)
    local pt = pTbl.policy_table
    local levels = { "NONE", "BACKGROUND", "FULL", "LIMITED" }
    pt.functional_groupings["FG0"] = {
      rpcs = {
        OnPermissionsChange = { hmi_levels = levels },
        OnSystemRequest = { hmi_levels = levels },
        SystemRequest = { hmi_levels = levels },
        OnHMIStatus = { hmi_levels = levels }
      }
    }

    pt.app_policies["default"].groups = { "FG0" }
    pTbl.policy_table.app_policies["default"].encryption_required = pAppPolicy
    pt.functional_groupings["FG0"].encryption_required = pFuncGroup
  end
  common.preloadedPTUpdate(pPTUpdateFunc)
end

local function checkOnPermissionsChange(pExpApp, pExpRPC, pActPayload, pTC)
  local msg = ""
  local isNewMsg1 = true
  local isNewMsg2 = true
  if pActPayload.requireEncryption ~= pExpApp then
    msg = msg .. "Expected 'requireEncryption' on a Top level " .. "'" .. tostring(pExpApp) .. "'"
      .. ", actual " .. "'" .. tostring(pActPayload.requireEncryption) .. "'\n"
  end
  for _, v in pairs(pActPayload.permissionItem) do
    if v.rpcName == "AddCommand" or v.rpcName == "OnPermissionsChange" then
      if v.requireEncryption ~= pExpRPC and isNewMsg1 == true then
        msg = msg .. "Expected 'requireEncryption' on an Item level for '" .. v.rpcName .. "': "
          .. "'" .. tostring(pExpRPC) .. "'"
          .. ", actual " .. "'" .. tostring(v.requireEncryption) .. "'\n"
        isNewMsg1 = false
      end
    else if isNewMsg2 == true then
      msg = msg .. "Expected only 'AddCommand' and 'OnPermissionsChange' as a permissionItems, actual "
        .. "'" .. v.rpcName .. "'\n"
        isNewMsg2 = false
      end
    end
  end
  if string.len(msg) > 0 then
    if pTC then failedTCs[pTC] = msg end
    return false, string.sub(msg, 1, -2)
  end
  return true
end

local function policyTableUpdate(pAppOld, pFGOld, pAppNew, pFGNew, pTC)
  local function ptUpdate(pTbl)
    local pt = pTbl.policy_table
    local levels = { "NONE", "BACKGROUND", "FULL", "LIMITED" }
    pt.functional_groupings["FG1"] = {
      rpcs = {
        AddCommand = { hmi_levels = levels },
        OnPermissionsChange = { hmi_levels = levels }
      }
    }

    pt.app_policies["spt"].groups = { "FG1" }
    pt.app_policies["spt"].encryption_required = pAppNew
    pt.functional_groupings["FG1"].encryption_required = pFGNew
  end
  local function expNotificationFunc()
    common.defaultExpNotificationFunc()
    common.getMobileSession():ExpectNotification("OnPermissionsChange")
    :ValidIf(function(e, data)
        if e.occurences == 1 then
          local expApp, expFG = common.getExp(pAppNew, pFGNew)
          return checkOnPermissionsChange(expApp, expFG, data.payload, pTC)
        end
        return true
      end)
  end
  common.policyTableUpdate(ptUpdate, expNotificationFunc)
  common.wait(1000)
end

--[[ Scenario ]]
for n, tr in common.spairs(transitions) do
  runner.Title("TC[" .. string.format("%03d", n) .. "/".. string.format("%03d", #transitions) .. "] update "
    .. "from '" .. tr.from .. "' (App:" .. tostring(states[tr.from].app)
    .. ",FG0:" .. tostring(states[tr.from].fg) .. ") "
    .. "to '" .. tr.to .. "' (App:" .. tostring(states[tr.to].app)
    .. ",FG1:" .. tostring(states[tr.to].fg) .. ")")
  runner.Title("Preconditions")
  runner.Step("Clean environment", common.preconditions)
  runner.Step("Preloaded update", updatePreloadedPT, { states[tr.from].app, states[tr.from].fg })
  runner.Step("Start SDL, init HMI", common.start)

  runner.Title("Test")
  runner.Step("Register App", common.registerApp)
  runner.Step("Policy Table Update", policyTableUpdate,
    { states[tr.from].app, states[tr.from].fg, states[tr.to].app, states[tr.to].fg, n })

  runner.Title("Postconditions")
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL, restore SDL settings", common.postconditions)
end

runner.Step("Print failed TCs", common.printFailedTCs, { failedTCs })
