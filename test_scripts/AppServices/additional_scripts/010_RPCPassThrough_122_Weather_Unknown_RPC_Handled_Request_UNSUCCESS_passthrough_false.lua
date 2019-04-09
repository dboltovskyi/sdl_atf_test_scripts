---------------------------------------------------------------------------------------------------
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local runner = require('user_modules/script_runner')
local common = require('test_scripts/AppServices/commonAppServices')
local json = require("modules/json")
local constants = require("protocol_handler/ford_protocol_constants")
local events = require("events")

--[[ Test Configuration ]]
runner.testSettings.isSelfIncluded = false

--[[ Local variables ]]
local manifest = {
  serviceName = common.getConfigAppParams(1).appName,
  serviceType = "WEATHER",
  handledRPCs = { 2000 },
  allowAppConsumers = true,
  rpcSpecVersion = common.getConfigAppParams(1).syncMsgVersion,
  weatherServiceManifest = {}
}

local unsuccessResponse = {
  success = false,
  resultCode = "UNSUPPORTED_REQUEST",
  info = "Module does not recognize this function id"
}

local rpcRequest = {
  id = 2000,
  params = {
    param1 = true
  }
}

--[[ Local functions ]]
local function PTUfunc(tbl)
  --Add permissions for app1
  local pt_entry = common.getAppServiceProducerConfig(1, "WEATHER")
  -- pt_entry.app_services.WEATHER = { handled_rpcs = {{ function_id = 1234 }} }
  tbl.policy_table.app_policies[common.getConfigAppParams(1).fullAppID] = pt_entry
  --Add permissions for app2
  pt_entry = common.getAppServiceConsumerConfig(2)
  pt_entry.allow_unknown_rpc_passthrough = false
  tbl.policy_table.app_policies[common.getConfigAppParams(2).fullAppID] = pt_entry
end

local function RPCPassThruTest()
  local mobSession = common.getMobileSession(1)

  function mobSession:ExpectRequest(pFuncId, pParams)
    local requestEvent = events.Event()
    requestEvent.matches = function(_, data)
      return data.rpcFunctionId == pFuncId
        and data.sessionId == self.SessionId.get()
        and data.rpcType == constants.BINARY_RPC_TYPE.REQUEST
    end
    local ret = self:ExpectEvent(requestEvent, "FuncId: " .. pFuncId .. " request")
    ret:ValidIf(function(_, data)
        return compareValues(pParams, data.payload, "payload")
      end)
    return ret
  end

  function mobSession:SendResponse(pFuncId, pCorrId, pParams)
    local msg = {
      encryption = false,
      serviceType = constants.SERVICE_TYPE.RPC,
      frameInfo = 0,
      rpcType = constants.BINARY_RPC_TYPE.RESPONSE,
      rpcFunctionId = pFuncId,
      rpcCorrelationId = pCorrId,
      payload = json.encode(pParams)
    }
    self:Send(msg)
  end

  mobSession = common.getMobileSession(2)
  function mobSession:SendRPC(pFunIc, pParams)
    self.CorrelationId.set(self.CorrelationId.get() + 1)
    local correlationId = self.CorrelationId.get()
    local msg = {
      encryption = false,
      frameType = 0x01,
      serviceType = 0x07,
      frameInfo = 0x0,
      rpcType = 0x0,
      rpcFunctionId = pFunIc,
      rpcCorrelationId = correlationId,
      payload = json.encode(pParams)
    }
    self:Send(msg)
    return correlationId
  end

  function mobSession:ExpectResponse(pCorrId, pParams)
    local requestEvent = events.Event()
    requestEvent.matches = function(_, data)
      return data.rpcCorrelationId == pCorrId
        and data.sessionId == self.SessionId.get()
        and data.rpcType == constants.BINARY_RPC_TYPE.RESPONSE
    end
    local ret = self:ExpectEvent(requestEvent, "Response to " .. pCorrId)
    ret:ValidIf(function(_, data)
        return compareValues(pParams, data.payload, "payload")
      end)
    return ret
  end

  local hmiConn = common.getHMIConnection()
  function hmiConn:ExpectAny()
    local event = events.Event()
    event.matches = function(_, data)
      if data.method == "BasicCommunication.UpdateAppList" then return false end
      return true
    end
    return self:ExpectEvent(event, "Any event")
  end

  local cid = common.getMobileSession(2):SendRPC(rpcRequest.id, rpcRequest.params)

  common.getMobileSession(1):ExpectRequest(rpcRequest.id, rpcRequest.params)
  :Times(0)

  -- Core will NOT handle the RPC
  common.getHMIConnection():ExpectAny()
  :Times(0)

  common.getMobileSession(2):ExpectResponse(cid, unsuccessResponse)
end

--[[ Scenario ]]
runner.Title("Preconditions")
runner.Step("Set config.ValidateSchema = false", common.setValidateSchema, { false })
runner.Step("Clean environment", common.preconditions)
runner.Step("Start SDL, HMI, connect Mobile, start Session", common.start)
runner.Step("RAI App 1", common.registerApp)
runner.Step("PTU", common.policyTableUpdate, { PTUfunc })
runner.Step("PublishAppService", common.publishMobileAppService, { manifest, 1 })
runner.Step("RAI App 2", common.registerAppWOPTU, { 2 })

runner.Title("Test")
runner.Step("RPCPassThroughTest_UNSUCCESS", RPCPassThruTest)

runner.Title("Postconditions")
runner.Step("Stop SDL", common.postconditions)
