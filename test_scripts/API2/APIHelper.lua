----------------------------------------------------------------------------------------------------
-- API Helper module
----------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]-------------------------------------------------------------------
local cmn = require('test_scripts/API2/APICommon')
local apiLoader = require("modules/api_loader")

--[[ Module ]]--------------------------------------------------------------------------------------
local m = {}

--[[ Constants ]]-----------------------------------------------------------------------------------
m.apiType = {
  MOBILE = "mobile",
  HMI = "hmi"
}

m.eventType = {
  REQUEST = "request",
  RESPONSE = "response",
  NOTIFICATION = "notification"
}

m.rpc = {
  SendLocation = 1,
  GetWayPoints = 2
}

m.rpcHMIMap = {
  [m.rpc.SendLocation] = "Navigation.SendLocation",
  [m.rpc.GetWayPoints] = "Navigation.GetWayPoints",
}

m.dataType = {
  INTEGER = { type = "Integer", min = -2147483647, max = 2147483647 }, -- min: 2147483648
  FLOAT = { type = "Float", min = -1000000, max = 1000000 },
  DOUBLE = { type = "Double", min = -1000000000, max = 1000000000 },
  STRING = { type = "String", min = 1, max = 100 },
  BOOLEAN = { type = "Boolean" },
  ENUM = { type = "Enum" },
  STRUCT = { type = "Struct" }
}

--[[ Variables ]]-----------------------------------------------------------------------------------
local api = {
  mobile = apiLoader.init("data/MOBILE_API.xml"),
  hmi = apiLoader.init("data/HMI_API.xml")
}

local schema = {
  mobile = api.mobile.interface[next(api.mobile.interface)],
  hmi = api.hmi.interface["Common"]
}

--[[ Functions ]]-----------------------------------------------------------------------------------
local function getType(pType)
  if string.find(pType, "%.") then
    return cmn.splitString(pType, ".")[2]
  end
  return pType
end

function m.getParamsData(pAPI, pEventType, pFunctionName)
  local function buildParams(pTbl, pParams)
    for k, v in pairs(pParams) do
      pTbl[k] = cmn.cloneTable(v)
      if schema[pAPI].struct[getType(v.type)] then
        pTbl[k].data = {}
        buildParams(pTbl[k].data, schema[pAPI].struct[getType(v.type)].param)
        pTbl[k].type = m.dataType.STRUCT.type
      elseif schema[pAPI].enum[getType(v.type)] then
        pTbl[k].data = {}
        for kk in cmn.spairs(schema[pAPI].enum[getType(v.type)]) do
          table.insert(pTbl[k].data, kk)
        end
        pTbl[k].type = m.dataType.ENUM.type
      end
    end
  end

  local function getAPIParams()
    if pAPI == m.apiType.MOBILE then
      return schema.mobile.type[pEventType].functions[pFunctionName].param
    elseif pAPI == m.apiType.HMI then
      local iName = cmn.splitString(pFunctionName, ".")[1]
      local fName = cmn.splitString(pFunctionName, ".")[2]
      return api.hmi.interface[iName].type[pEventType].functions[fName].param
    end
  end

  local params = getAPIParams(pAPI)

  local out = {}
  buildParams(out, params)

  local function updateBooleanValue(pValue)
    local o = pValue
    if type(pValue) == "string" then
      if pValue == "true" then o = true
      elseif pValue == "false" then o = false
      end
    end
    return o
  end

  local function updateValues(pTbl)
    for k, v in pairs(pTbl) do
      if type(v) == "table" then
        updateValues(v)
      else
        pTbl[k] = updateBooleanValue(v)
      end
    end
  end
  updateValues(out)

  return out
end

return m
