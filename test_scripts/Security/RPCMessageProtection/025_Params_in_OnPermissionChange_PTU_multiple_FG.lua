---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md

-- Description:
-- Verify the value for `requireEncryption` in OnPermissionsChange at top and functional group levels after PTU
-- in case if `requireEncryption` values has been changed in multiple existing groups

-- Sequence:
-- 1) Define initial values of requireEncryption flags for app and particular functional group in preloaded file
-- 2) Start SDL, HMI, connect mobile, register app
-- 3) Perform PTU and set new values for requireEncryption flags at top and functional group levels
-- in existing functional groups
-- 4) Check which values are sent by SDL in OnPermissionsChange notification
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Security/RPCMessageProtection/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local states = {
  [1] = { fg1 = true,  fg2 = true },
  [2] = { fg1 = true,  fg2 = false },
  [3] = { fg1 = true,  fg2 = nil },
  [4] = { fg1 = false, fg2 = true },
  [5] = { fg1 = false, fg2 = false },
  [6] = { fg1 = false, fg2 = nil },
  [7] = { fg1 = nil,   fg2 = true },
  [8] = { fg1 = nil,   fg2 = false },
  [9] = { fg1 = nil,   fg2 = nil }
}

local transitions = common.getTransitions(states)

-- transitions = { [001] = { from = 6, to = 1 } }

local failedTCs = { }

--[[ Local Functions ]]
local function getExpValue(pFG1, pFG2)
  local _, fg1 = common.getExp(nil, pFG1)
  local _, fg2 = common.getExp(nil, pFG2)
  if fg1 == true or fg2 == true then return true end
  return nil
end

local function getNotifQty(pPreFG1, pPreFG2, pNewFG1, pNewFG2)
  local expPre = getExpValue(pPreFG1, pPreFG2)
  local expNew = getExpValue(pNewFG1, pNewFG2)
  if expPre == expNew then
    common.cprint(35, string.format("OnPermissionsChange is not expected"))
    return 0
  end
  return 1
end

local function checkOnPermissionsChange(pExp, pActPayload, pTC)
  local msg = ""
  local isNewMsg = true
  for _, v in pairs(pActPayload.permissionItem) do
    if v.requireEncryption ~= pExp and isNewMsg == true  then
      msg = msg .. "   Expected 'requireEncryption' on an Item level for '" .. v.rpcName .. "': "
        .. "'" .. tostring(pExp) .. "'" .. ", actual " .. "'" .. tostring(v.requireEncryption) .. "'\n"
      isNewMsg = false
    end
  end
  if string.len(msg) > 0 then
    if pTC then failedTCs[pTC] = msg end
    return false, string.sub(msg, 1, -2)
  end
  return true
end

local function updatePreloadedPT(pFG1, pFG2)
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
    local fgData = {
      rpcs = {
        AddCommand = { hmi_levels = levels }
      }
    }
    pt.functional_groupings["FG1"] = common.cloneTable(fgData)
    pt.functional_groupings["FG2"] = common.cloneTable(fgData)
    pt.functional_groupings["FG1"].encryption_required = pFG1
    pt.functional_groupings["FG2"].encryption_required = pFG2

    pt.app_policies["default"].groups = { "FG0", "FG1", "FG2" }
    pt.app_policies["default"].encryption_required = nil
  end
  common.preloadedPTUpdate(pPTUpdateFunc)
end

local function policyTableUpdate(pPreFG1, pPreFG2, pNewFG1, pNewFG2, pTC)
  local function ptUpdate(pTbl)
    local pt = pTbl.policy_table
    pt.app_policies["spt"].groups = { "FG0", "FG1", "FG2" }
    pt.functional_groupings["FG1"].encryption_required = pNewFG1
    pt.functional_groupings["FG2"].encryption_required = pNewFG2
  end
  local function expNotificationFunc()
    local notifQty = getNotifQty(pPreFG1, pPreFG2, pNewFG1, pNewFG2)
    common.defaultExpNotificationFunc()
    common.getMobileSession():ExpectNotification("OnPermissionsChange")
    :ValidIf(function(e, data)
        if e.occurences == 1 and notifQty ~= 0 then
          local exp = getExpValue(pNewFG1, pNewFG2)
          local act = data.payload
          return checkOnPermissionsChange(exp, act, pTC)
        end
        return true
      end)
    :Times(notifQty)
  end
  common.policyTableUpdate(ptUpdate, expNotificationFunc)
  common.wait(1000)
end

--[[ Scenario ]]
for n, tr in common.spairs(transitions) do
  runner.Title("TC[" .. string.format("%03d", n) .. "/".. string.format("%03d", #transitions) .. "] update "
    .. "from '" .. tr.from .. "' (App:nil,FG1:" .. tostring(states[tr.from].fg1)
    .. ",FG2:" .. tostring(states[tr.from].fg2) .. ") "
    .. "to '" .. tr.to .. "' (App:nil,FG1:" .. tostring(states[tr.to].fg1)
    .. ",FG2:" .. tostring(states[tr.to].fg2) .. ")")
  runner.Title("Preconditions")
  runner.Step("Clean environment", common.preconditions)
  runner.Step("Preloaded update", updatePreloadedPT, { states[tr.from].fg1, states[tr.from].fg2 })
  runner.Step("Start SDL, init HMI", common.start)

  runner.Title("Test")
  runner.Step("Register App", common.registerApp)
  runner.Step("Policy Table Update", policyTableUpdate,
    { states[tr.from].fg1, states[tr.from].fg2, states[tr.to].fg1, states[tr.to].fg2, n })

  runner.Title("Postconditions")
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL, restore SDL settings", common.postconditions)
end

runner.Step("Print failed TCs", common.printFailedTCs, { failedTCs })
