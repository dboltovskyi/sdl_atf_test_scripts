---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local actions = require("user_modules/sequences/actions")
local security = require("user_modules/sequences/security")
local utils = require("user_modules/utils")
local test = require("user_modules/dummy_connecttest")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')

--[[ General configuration parameters ]]
config.SecurityProtocol = "DTLS"
config.application1.registerAppInterfaceParams.appName = "server"
config.application1.registerAppInterfaceParams.appID = "SPT"

--[[ Module ]]
local m = actions

m.frameInfo = security.frameInfo
m.readFile = utils.readFile

--[[ Functions ]]
local function getSystemTimeValue()
  local dd = os.date("*t")
  return {
    millisecond = 0,
    second = dd.sec,
    minute = dd.min,
    hour = dd.hour,
    day = dd.day,
    month = dd.month,
    year = dd.year,
    tz_hour = 2,
    tz_minute = 0
  }
end

local function registerGetSystemTimeResponse()
  actions.getHMIConnection():ExpectRequest("BasicCommunication.GetSystemTime")
  :Do(function(_, data)
      actions.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { systemTime = getSystemTimeValue() })
    end)
  :Pin()
  :Times(AnyNumber())
end

function m.allowSDL()
  actions.getHMIConnection():SendNotification("SDL.OnAllowSDLFunctionality", {
    allowed = true,
    source = "GUI",
    device = {
      id = utils.getDeviceMAC(),
      name = utils.getDeviceName()
    }
  })
end

function m.start()
  test:runSDL()
  commonFunctions:waitForSDLStart(test)
  :Do(function()
      test:initHMI()
      :Do(function()
          local rid = actions.getHMIConnection():SendRequest("MB.subscribeTo", {
            propertyName = "BasicCommunication.OnSystemTimeReady" })
          actions.getHMIConnection():ExpectResponse(rid)
          :Do(function()
              utils.cprint(35, "HMI initialized")
              test:initHMI_onReady()
              :Do(function()
                  utils.cprint(35, "HMI is ready")
                  actions.getHMIConnection():SendNotification("BasicCommunication.OnSystemTimeReady")
                  registerGetSystemTimeResponse()
                  test:connectMobile()
                  :Do(function()
                      utils.cprint(35, "Mobile connected")
                      m.allowSDL()
                    end)
                end)
            end)
        end)
    end)
end

function m.sendAddCommandProtected()
  local params = {
    cmdID = 1,
    menuParams = {
      position = 1,
      menuName = "Command_1"
    }
  }
  local cid = m.getMobileSession():SendEncryptedRPC("AddCommand", params)
  m.getHMIConnection():ExpectRequest("UI.AddCommand", params)
  :Do(function(_, data)
      m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
    end)
  m.getMobileSession():ExpectEncryptedResponse(cid, { success = true, resultCode = "SUCCESS" })
  m.getMobileSession():ExpectEncryptedNotification("OnHashChange")
end

function m.activateAppProtected()
  local rid = m.getHMIConnection():SendRequest("SDL.ActivateApp", { appID = m.getHMIAppId() })
  m.getHMIConnection():ExpectResponse(rid)
  m.getMobileSession():ExpectEncryptedNotification("OnHMIStatus", {
    hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
end

local function saveFile(pContent, pFileName)
  local f = io.open(pFileName, "w")
  f:write(pContent)
  f:close()
end

local function getAllCrtsFromPEM(pCrtsFileName)
  local crts = utils.readFile(pCrtsFileName)
  local o = {}
  local i = 1
  local s = crts:find("-----BEGIN RSA PRIVATE KEY-----", i, true)
  local _, e = crts:find("-----END RSA PRIVATE KEY-----", i, true)
  o.key = crts:sub(s, e) .. "\n"
  for _, v in pairs({ "crt", "rootCA", "issuingCA" }) do
    i = e
    s = crts:find("-----BEGIN CERTIFICATE-----", i, true)
    _, e = crts:find("-----END CERTIFICATE-----", i, true)
    o[v] = crts:sub(s, e) .. "\n"
  end
  return o
end

local function createCrtHashes()
  local sdlBin = commonPreconditions:GetPathToSDL()
  os.execute("cd " .. sdlBin .. " && c_rehash .")
end

local function updateSDLIniFile()
  m.setSDLIniParameter("KeyPath", "module_key.pem")
  m.setSDLIniParameter("CertificatePath", "module_crt.pem")
end

function m.initSDLCertificates(pCrtsFileName, pIsModuleCrtDefined)
  if pIsModuleCrtDefined == nil then pIsModuleCrtDefined = true end
  local allCrts = getAllCrtsFromPEM(pCrtsFileName)
  local sdlBin = commonPreconditions:GetPathToSDL()
  saveFile(allCrts.rootCA, sdlBin .. "rootCA.pem")
  saveFile(allCrts.issuingCA, sdlBin .. "issuingCA.pem")
  createCrtHashes()
  if pIsModuleCrtDefined then
    saveFile(allCrts.key, sdlBin .. "module_key.pem")
    saveFile(allCrts.crt, sdlBin .. "module_crt.pem")
  end
  updateSDLIniFile()
end

function m.cleanUpCertificates()
  local sdlBin = commonPreconditions:GetPathToSDL()
  os.execute("cd " .. sdlBin .. " && find . -type l -exec rm -f {} \\;")
  os.execute("cd " .. sdlBin .. " && rm -rf *.pem")
end

local preconditionsOrig = m.preconditions
local postconditionsOrig = m.postconditions

function m.preconditions()
  preconditionsOrig()
  m.cleanUpCertificates()
end

function m.postconditions()
  postconditionsOrig()
  m.cleanUpCertificates()
end

function m.policyTableUpdateSuccess(pPTUpdateFunc)
  local function expNotificationFunc()
    m.getHMIConnection():ExpectRequest("BasicCommunication.DecryptCertificate")
    :Do(function(_, d)
        m.getHMIConnection():SendResponse(d.id, d.method, "SUCCESS", { })
      end)
    :Times(AnyNumber())
    m.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
  end
  m.getHMIConnection():ExpectRequest("BasicCommunication.PolicyUpdate")
  :Do(function(e, d)
      if e.occurences == 1 then
        m.getHMIConnection():SendResponse(d.id, d.method, "SUCCESS", { })
        m.setPTUTable(utils.jsonFileToTable(d.params.file))
        m.policyTableUpdate(pPTUpdateFunc, expNotificationFunc)
      end
    end)
end

return m
