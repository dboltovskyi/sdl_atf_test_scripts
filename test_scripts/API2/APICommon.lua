----------------------------------------------------------------------------------------------------
-- API Common module
----------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local mobileSession = require("mobile_session")
local json = require("modules/json")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local commonTestCases = require("user_modules/shared_testcases/commonTestCases")
local commonPreconditions = require("user_modules/shared_testcases/commonPreconditions")

--[[ Module ]] -------------------------------------------------------------------------------------
local m = {}

--[[ Constants ]] ----------------------------------------------------------------------------------
m.timeout = 2000
m.minTimeout = 500

local ptuTable = {}
local hmiAppIds = {}

-- [[ Functions ]] ---------------------------------------------------------------------------------
function m.getTableSize(pTbl)
  local out = 0
  for _ in pairs(pTbl) do
    out = out + 1
  end
  return out
end

function m.tableContains(pTbl, pValue)
  for _, v in pairs(pTbl) do
    if v == pValue then return true end
  end
  return false
end

function m.spairs(pTbl, pOrder)
  local keys = {}
  for k in pairs(pTbl) do
    keys[#keys+1] = k
  end
  if pOrder then
    table.sort(keys, function(a, b) return pOrder(pTbl, a, b) end)
  else
    table.sort(keys)
  end
  local i = 0
  return function()
    i = i + 1
    if keys[i] then
      return keys[i], pTbl[keys[i]]
    end
  end
end

local function printT(t, indent)
  indent = indent or ''
  local nextIndent
  for key, value in pairs(t) do
    if type(value) == "table" then
      nextIndent = nextIndent or (indent .. string.rep(' ', string.len(tostring(key)) + 2))
      print(indent .. "[" .. tostring(key) .. "] = {")
      -- print(nextIndent .. "{")
      printT(value, nextIndent .. string.rep(' ', 2))
      print(nextIndent .. "}")
    else
      local v = value
      if type(value) == "string" then v = "'" .. v .. "'" end
      print(indent .. "[" .. tostring(key) .. "] = " .. tostring(v) .. "")
    end
  end
end

function m.printTable(pTbl, pName)
  if not pName then pName = "" else pName = " " .. pName .. " " end
  print("---" .. pName .. string.rep("-", 27 - string.len(pName)))
  printT(pTbl)
  print(string.rep("-", 30))
end

local function checkIfPTSIsSentAsBinary(pBinData)
  if not (pBinData ~= nil and string.len(pBinData) > 0) then
    commonFunctions:userPrint(31, "PTS was not sent to Mobile in payload of OnSystemRequest")
  end
end

function m.getAppConfig()
  return {
    keep_context = false,
    steal_focus = false,
    priority = "NONE",
    default_hmi = "NONE",
    groups = { "Base-4", "APITest" }
  }
end

local function getPTUFromPTS(pTbl)
  pTbl.policy_table.consumer_friendly_messages.messages = nil
  pTbl.policy_table.device_data = nil
  pTbl.policy_table.module_meta = nil
  pTbl.policy_table.usage_and_error_counts = nil
  pTbl.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  pTbl.policy_table.module_config.preloaded_pt = nil
  pTbl.policy_table.module_config.preloaded_date = nil
end

local function jsonFileToTable(pFileName)
  local f = io.open(pFileName, "r")
  local content = f:read("*all")
  f:close()
  return json.decode(content)
end

local function tableToJsonFile(pTbl, pFileName)
  local f = io.open(pFileName, "w")
  f:write(json.encode(pTbl))
  f:close()
end

local function updatePTU()
end

local function ptu(pAppId, pPTUpdateFunc, self)
  local policy_file_name = "PolicyTableUpdate"
  local policy_file_path = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath")
  local pts_file_name = commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
  local ptu_file_name = os.tmpname()
  local requestId = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(requestId)
  :Do(function()
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
        { requestType = "PROPRIETARY", fileName = pts_file_name })
      getPTUFromPTS(ptuTable)

      updatePTU(ptuTable, pAppId)

      if pPTUpdateFunc then
        pPTUpdateFunc(ptuTable)
      end

      tableToJsonFile(ptuTable, ptu_file_name)

      local event = events.Event()
      event.matches = function(self, e) return self == e end
      EXPECT_EVENT(event, "PTU event")
      :Timeout(11000)

      local function getAppsCount()
        local count = 0
        for _ in pairs(hmiAppIds) do
          count = count + 1
        end
        return count
      end
      for id = 1, getAppsCount() do
        local currentSession = m.getMobileSession(id, self)
        currentSession:ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
        :Do(function(_, d2)
            print("App ".. id .. " was used for PTU")
            RAISE_EVENT(event, event, "PTU event")
            checkIfPTSIsSentAsBinary(d2.binaryData)
            local corIdSystemRequest = currentSession:SendRPC("SystemRequest",
              { requestType = "PROPRIETARY", fileName = policy_file_name }, ptu_file_name)
            EXPECT_HMICALL("BasicCommunication.SystemRequest")
            :Do(function(_, d3)
                self.hmiConnection:SendResponse(d3.id, "BasicCommunication.SystemRequest", "SUCCESS", { })
                self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate",
                  { policyfile = policy_file_path .. "/" .. policy_file_name })
              end)
            currentSession:ExpectResponse(corIdSystemRequest, { success = true, resultCode = "SUCCESS" })
            :Do(function()
                os.remove(ptu_file_name)
              end)
          end)
        :Times(AtMost(1))
      end
    end)
end

function m.preconditions()
  commonFunctions:SDLForceStop()
  commonSteps:DeletePolicyTable()
  commonSteps:DeleteLogsFiles()
end

function m.activateApp(pAppId, self)
  self, pAppId = m.getSelfAndParams(pAppId, self)
  if not pAppId then pAppId = 1 end
  local pHMIAppId = hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
  local mobSession = m.getMobileSession(pAppId, self)
  local requestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = pHMIAppId })
  EXPECT_HMIRESPONSE(requestId)
  mobSession:ExpectNotification("OnHMIStatus",
    { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
  commonTestCases:DelayedExp(m.minTimeout)
end

function m.getSelfAndParams(...)
  local out = { }
  local selfIdx = nil
  for i,v in pairs({...}) do
    if type(v) == "table" and v.isTest then
      table.insert(out, v)
      selfIdx = i
      break
    end
  end
  local idx = 2
  for i = 1, table.maxn({...}) do
    if i ~= selfIdx then
      out[idx] = ({...})[i]
      idx = idx + 1
    end
  end
  return table.unpack(out, 1, table.maxn(out))
end

function m.getHMIAppId(pAppId)
  if not pAppId then pAppId = 1 end
  return hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
end

function m.getMobileSession(pAppId, self)
  if not pAppId then pAppId = 1 end
  return self["mobileSession" .. pAppId]
end

function m.getMobileAppId(pAppId)
  if not pAppId then pAppId = 1 end
  return config["application" .. pAppId].registerAppInterfaceParams.appID
end

function m.postconditions()
  StopSDL()
end

function m.registerAppWithPTU(pAppId, pPTUpdateFunc, self)
  self, pAppId, pPTUpdateFunc = m.getSelfAndParams(pAppId, pPTUpdateFunc, self)
  if not pAppId then pAppId = 1 end
  self["mobileSession" .. pAppId] = mobileSession.MobileSession(self, self.mobileConnection)
  self["mobileSession" .. pAppId]:StartService(7)
  :Do(function()
      local corId = self["mobileSession" .. pAppId]:SendRPC("RegisterAppInterface",
        config["application" .. pAppId].registerAppInterfaceParams)
      EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered",
        { application = { appName = config["application" .. pAppId].registerAppInterfaceParams.appName } })
      :Do(function(_, d1)
          hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID] = d1.params.application.appID
          EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
            { status = "UPDATE_NEEDED" }, { status = "UPDATING" }, { status = "UP_TO_DATE" })
          :Times(3)
          EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
          :Do(function(_, d2)
              self.hmiConnection:SendResponse(d2.id, d2.method, "SUCCESS", { })
              ptuTable = jsonFileToTable(d2.params.file)
              ptu(pAppId, pPTUpdateFunc, self)
            end)
        end)
      self["mobileSession" .. pAppId]:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          self["mobileSession" .. pAppId]:ExpectNotification("OnHMIStatus",
            { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
          :Times(1)
          self["mobileSession" .. pAppId]:ExpectNotification("OnPermissionsChange")
          :Times(AtLeast(1)) -- TODO: Change to exact 1 occurence when SDL issue is fixed
        end)
    end)
end

local function allowSDL(self)
  self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
    { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = "127.0.0.1" } })
end

function m.start(pHMIParams, self)
  self, pHMIParams = m.getSelfAndParams(pHMIParams, self)
  self:runSDL()
  commonFunctions:waitForSDLStart(self)
  :Do(function()
      self:initHMI(self)
      :Do(function()
          commonFunctions:userPrint(35, "HMI initialized")
          self:initHMI_onReady(pHMIParams)
          :Do(function()
              commonFunctions:userPrint(35, "HMI is ready")
              self:connectMobile()
              :Do(function()
                  commonFunctions:userPrint(35, "Mobile connected")
                  allowSDL(self)
                end)
            end)
        end)
    end)
end

function m.cloneTable(pTbl)
  if pTbl == nil then
    return {}
  end
  local copy = {}
  for k, v in pairs(pTbl) do
    if type(v) == 'table' then
      v = m.cloneTable(v)
    end
  copy[k] = v
  end
  return copy
end

function m.splitString(pStr, pDelimiter)
  local result = {}
  for match in (pStr .. pDelimiter):gmatch("(.-)%" .. pDelimiter) do
    table.insert(result, match)
  end
  return result
end

function m.cloneTable(pTbl)
  if pTbl == nil then
    return {}
  end
  local copy = {}
  for k, v in pairs(pTbl) do
    if type(v) == 'table' then
      v = m.cloneTable(v)
    end
  copy[k] = v
  end
  return copy
end

function m.Delay()
  commonTestCases:DelayedExp(m.minTimeout)
end

function m.putFile(pParams, self)
  local mobSession = m.getMobileSession(1, self);
  local cid = mobSession:SendRPC("PutFile", pParams.requestParams, pParams.filePath)
  mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS"})
end

function m.getPathToSDL()
  return commonPreconditions.GetPathToSDL()
end

function m.getKeyByValue(pTbl, pValue)
  for k, v in pairs(pTbl) do
    if v == pValue then return k end
  end
end

return m
