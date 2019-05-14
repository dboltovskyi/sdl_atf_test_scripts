---------------------------------------------------------------------------------------------------
-- Proposal:
-- https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0207-rpc-message-protection.md

-- Description:
-- Verify the value for `requireEncryption` in OnPermissionsChange at top and functional group levels after
-- app registration

-- Precondition:
-- 1) PT contains data for encryption_required parameters for app and function_group (Base-4)
-- In case:
-- 1) App registered
-- SDL does:
-- 1) send BasicCommunication.OnAppRegistered to HMI
-- 2) send OnPermissionsChange to mobile app with appropriate values of encryption_required parameters
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Security/RPCMessageProtection/common')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local states = {
  [1] = { app = true,  fg = true  },
  [2] = { app = true,  fg = false },
  [3] = { app = true,  fg = nil   },
  [4] = { app = false, fg = true  },
  [5] = { app = false, fg = false },
  [6] = { app = false, fg = nil   },
  [7] = { app = nil,   fg = true  },
  [8] = { app = nil,   fg = false },
  [9] = { app = nil,   fg = nil   }
}

local failedTCs = { }

--[[ Local Functions ]]
local function updatePreloadedPT(pAppPolicy, pFuncGroup)
  local function pPTUpdateFunc(pTbl)
    local pt = pTbl.policy_table
    local levels = { "NONE", "BACKGROUND", "FULL", "LIMITED" }
    pt.functional_groupings["FG0"] = {
      rpcs = {
        OnPermissionsChange = { hmi_levels = levels },
        AddCommand = { hmi_levels = levels }
      }
    }

    pt.app_policies["default"].groups = { "FG0" }
    pTbl.policy_table.app_policies["default"].encryption_required = pAppPolicy
    pt.functional_groupings["FG0"].encryption_required = pFuncGroup
  end
  common.preloadedPTUpdate(pPTUpdateFunc)
end

local function checkOnPermissionsChange(pExpApp, pExpRPCs, pActPayload, pTC)
  local msg = ""
  local isNewMsg = true
  if pActPayload.requireEncryption ~= pExpApp then
    msg = msg .. "Expected 'requireEncryption' on a Top level " .. "'" .. tostring(pExpApp) .. "'"
      .. ", actual " .. "'" .. tostring(pActPayload.requireEncryption) .. "'\n"
  end
  for _, v in pairs(pActPayload.permissionItem) do
    if v.requireEncryption ~= pExpRPCs and isNewMsg == true then
      msg = msg .. "Expected 'requireEncryption' on an Item level for '" .. v.rpcName .. "': "
        .. "'" .. tostring(pExpRPCs) .. "'"
        .. ", actual " .. "'" .. tostring(v.requireEncryption) .. "'\n"
      isNewMsg = false
    end
  end
  if string.len(msg) > 0 then
    if pTC then failedTCs[pTC] = msg end
    return false, string.sub(msg, 1, -2)
  end
  return true
end

local function registerApp(pAppNew, pFGNew, pTC)
  common.getMobileSession():StartService(7)
  :Do(function()
      local cid = common.getMobileSession():SendRPC("RegisterAppInterface", common.getConfigAppParams())
      common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered")
      common.getMobileSession():ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          common.getMobileSession():ExpectNotification("OnPermissionsChange")
          :ValidIf(function(e, data)
              if e.occurences == 1 then
                local expApp, expFG = common.getExp(pAppNew, pFGNew)
                return checkOnPermissionsChange(expApp, expFG, data.payload, pTC)
              end
              return true
            end)
        end)
    end)
end

--[[ Scenario ]]
for n, tc in common.spairs(states) do
  runner.Title("TC[" .. string.format("%03d", n) .. "/".. string.format("%03d", #states) .. "] set "
    .. "' (App:" .. tostring(tc.app) .. ",FG0:" .. tostring(tc.fg) .. ")")
  runner.Title("Preconditions")
  runner.Step("Clean environment", common.preconditions)
  runner.Step("Preloaded update", updatePreloadedPT, { tc.app, tc.fg })
  runner.Step("Start SDL, init HMI", common.start)

  runner.Title("Test")
  runner.Step("Register App", registerApp, { tc.app, tc.fg, n })

  runner.Title("Postconditions")
  runner.Step("Clean sessions", common.cleanSessions)
  runner.Step("Stop SDL, restore SDL settings", common.postconditions)
end

runner.Step("Print failed TCs", common.printFailedTCs, { failedTCs })
