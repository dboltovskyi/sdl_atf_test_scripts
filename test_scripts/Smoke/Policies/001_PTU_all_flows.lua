---------------------------------------------------------------------------------------------
-- Script verifies PTU sequence
-- Supported PROPRIETARY, EXTERNAL_PROPRIETARY and HTTP flows
---------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/Smoke/commonSmoke')

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local Variables ]]
local flowType = {
  PROPRIETARY = 1,
  EXTERNAL_PROPRIETARY = 2,
  HTTP = 3
}

--[[ Local Functions ]]
function common.start()
  local event = common.createEvent()
  common.cprintTable(35, common.SDL.buildOptions)
  common.init.SDL()
  :Do(function()
      common.init.HMI()
      :Do(function()
          common.init.HMI_onReady()
          :Do(function()
              common.init.connectMobile()
              :Do(function()
                  common.getHMIConnection():RaiseEvent(event, "Start event")
                end)
            end)
        end)
    end)
  return common.getHMIConnection():ExpectEvent(event, "Start event")
end

local function log(...)
  common.log(...)
end

local function getPTUFromPTS(pPTS)
  pPTS.policy_table.consumer_friendly_messages.messages = nil
  pPTS.policy_table.device_data = nil
  pPTS.policy_table.module_meta = nil
  pPTS.policy_table.usage_and_error_counts = nil
  pPTS.policy_table.functional_groupings["DataConsent-2"].rpcs = common.json.null
  pPTS.policy_table.module_config.preloaded_pt = nil
  pPTS.policy_table.module_config.preloaded_date = nil
  pPTS.policy_table.app_policies[common.getConfigAppParams().fullAppID] = {
    keep_context = false,
    steal_focus = false,
    priority = "NONE",
    default_hmi = "NONE"
  }
  pPTS.policy_table.app_policies[common.getConfigAppParams().fullAppID]["groups"] = { "Base-4", "Base-6" }
end

local function checkIfPTSIsSentAsBinary(pBinData, pFlow)
  local pt = nil
  if pBinData ~= nil and string.len(pBinData) > 0 then
    if flowType[pFlow] == flowType.PROPRIETARY then
      pt = common.json.decode(pBinData).HTTPRequest.body
    elseif flowType[pFlow] == flowType.EXTERNAL_PROPRIETARY or flowType[pFlow] == flowType.HTTP then
      pt = pBinData
    end
    pt = common.json.decode(pt)
  end
  if pt == nil or not pt.policy_table then
    common.failTestCase("PTS was not sent to Mobile as binary data in payload of OnSystemRequest")
  end
end

local function ptuProprietary(pPTUTable, pFlow)
  local pts_file_name = common.readParameterFromSDLINI("SystemFilesPath") .. "/"
    .. common.readParameterFromSDLINI("PathToSnapshot")
  local ptu_file_name = os.tmpname()
  local requestId = common.getHMIConnection():SendRequest("SDL.GetURLS", { service = 7 })
  log("HMI->SDL: RQ: SDL.GetURLS")
  common.getHMIConnection():ExpectResponse(requestId)
  :Do(function()
      log("SDL->HMI: RS: SDL.GetURLS")
      common.getHMIConnection():SendNotification("BasicCommunication.OnSystemRequest",
        { requestType = "PROPRIETARY", fileName = pts_file_name })
      log("HMI->SDL: N: BC.OnSystemRequest")
      getPTUFromPTS(pPTUTable)
      common.tableToJsonFile(pPTUTable, ptu_file_name)
      common.getMobileSession():ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
      :Do(function(_, d)
          checkIfPTSIsSentAsBinary(d.binaryData, pFlow)
          log("SDL->MOB: N: OnSystemRequest")
          local corIdSystemRequest = common.getMobileSession():SendRPC("SystemRequest",
            { requestType = "PROPRIETARY" }, ptu_file_name)
          log("MOB->SDL: RQ: SystemRequest")
          EXPECT_HMICALL("BasicCommunication.SystemRequest")
          :Do(function(_, dd)
              log("SDL->HMI: RQ: BC.SystemRequest")
              common.getHMIConnection():SendResponse(dd.id, dd.method, "SUCCESS", { })
              log("HMI->SDL: RS: SUCCESS: BC.SystemRequest")
              common.getHMIConnection():SendNotification("SDL.OnReceivedPolicyUpdate",
                { policyfile = dd.params.fileName })
              log("HMI->SDL: N: SDL.OnReceivedPolicyUpdate")
            end)
          common.getMobileSession():ExpectResponse(corIdSystemRequest, { success = true, resultCode = "SUCCESS"})
          :Do(function() os.remove(ptu_file_name) end)
          log("SDL->MOB: RS: SUCCESS: SystemRequest")
        end)
    end)
end

local function ptuHttp(pPTUTable)
  local policy_file_name = "PolicyTableUpdate"
  local ptu_file_name = os.tmpname()
  getPTUFromPTS(pPTUTable)
  common.tableToJsonFile(pPTUTable, ptu_file_name)
  local corId = common.getMobileSession():SendRPC("SystemRequest",
    { requestType = "HTTP", fileName = policy_file_name }, ptu_file_name)
  log("MOB->SDL: RQ: SystemRequest")
  common.getMobileSession():ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
  :Do(function()
      log("SDL->MOB: RS: SUCCESS: SystemRequest")
    end)
  os.remove(ptu_file_name)
end

local function expOnStatusUpdate()
  common.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate",
    { status = "UPDATE_NEEDED" }, { status = "UPDATING" }, {status = "UP_TO_DATE" })
  :Do(function(_, d)
      log("SDL->HMI: N: SDL.OnStatusUpdate", d.params.status)
    end)
  :Times(3)
end

local function failInCaseIncorrectPTU(pRequestName)
  common.failTestCase(pRequestName .. " was sent more than once (PTU update was incorrect)")
end

local function raiPTU()
  expOnStatusUpdate()
  common.init.allowSDL()
  :Do(function()
      common.createMobileSession()
      common.getMobileSession():StartService(7)
      :Do(function()
          local corId = common.getMobileSession():SendRPC("RegisterAppInterface", common.getConfigAppParams())
          log("MOB->SDL: RQ: RegisterAppInterface")
          common.getHMIConnection():ExpectNotification("BasicCommunication.OnAppRegistered")
          :Do(function()
              log("SDL->HMI: N: BC.OnAppRegistered")
              if common.SDL.buildOptions.extendedPolicy == "PROPRIETARY"
              or common.SDL.buildOptions.extendedPolicy == "EXTERNAL_PROPRIETARY" then
                common.getHMIConnection():ExpectRequest("BasicCommunication.PolicyUpdate")
                :Do(function(e, d)
                    if e.occurences == 1 then -- SDL send BC.PolicyUpdate more than once if PTU update was incorrect
                      log("SDL->HMI: RQ: BC.PolicyUpdate")
                      local ptu_table = common.jsonFileToTable(d.params.file)
                      common.getHMIConnection():SendResponse(d.id, d.method, "SUCCESS", { })
                      log("HMI->SDL: RS: BC.PolicyUpdate")
                      ptuProprietary(ptu_table, common.SDL.buildOptions.extendedPolicy)
                    else
                      failInCaseIncorrectPTU("BC.PolicyUpdate")
                    end
                  end)
              elseif common.SDL.buildOptions.extendedPolicy == "HTTP" then
                common.getMobileSession():ExpectNotification("OnSystemRequest")
                :Do(function(e, d)
                    log("SDL->MOB: N: OnSystemRequest", e.occurences, d.payload.requestType)
                    if d.payload.requestType == "HTTP" then
                      if e.occurences <= 2 then -- SDL send OnSystemRequest more than once if PTU update was incorrect
                        checkIfPTSIsSentAsBinary(d.binaryData, common.SDL.buildOptions.extendedPolicy)
                        if d.binaryData then
                          local ptu_table = common.json.decode(d.binaryData)
                          ptuHttp(ptu_table)
                        end
                      else
                        failInCaseIncorrectPTU("OnSystemRequest")
                      end
                    end
                  end)
                :Times(2)
              end
            end)
          common.getMobileSession():ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
          :Do(function()
              log("SDL->MOB: RS: RegisterAppInterface")
              common.getMobileSession():ExpectNotification("OnHMIStatus",
                { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
              :Do(function(_, d)
                  log("SDL->MOB: N: OnHMIStatus", d.payload.hmiLevel)
                end)
              common.getMobileSession():ExpectNotification("OnPermissionsChange")
              :Do(function()
                  log("SDL->MOB: N: OnPermissionsChange")
                end)
              :Times(2)
            end)
        end)
    end)
end

local function checkPTUStatus()
  local reqId = common.getHMIConnection():SendRequest("SDL.GetStatusUpdate")
  log("HMI->SDL: RQ: SDL.GetStatusUpdate")
  common.getHMIConnection():ExpectResponse(reqId, { result = { status = "UP_TO_DATE" }})
  :Do(function(_, d)
      log("HMI->SDL: RS: SDL.GetStatusUpdate", tostring(d.result.status))
    end)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile", common.start)

runner.Title("Test")
runner.Step("Register App and Policy Table Update", raiPTU)
runner.Step("Check Status", checkPTUStatus)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
