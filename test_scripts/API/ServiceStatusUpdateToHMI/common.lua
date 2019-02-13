---------------------------------------------------------------------------------------------------
-- Common module
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require("test_scripts/Security/SSLHandshakeFlow/common")
local utils = require("user_modules/utils")
local test = require("user_modules/dummy_connecttest")
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local constants = require("protocol_handler/ford_protocol_constants")
local atf_logger = require("atf_logger")

--[[ General configuration parameters ]]
config.SecurityProtocol = "DTLS"
config.application1.registerAppInterfaceParams.appName = "server"
config.application1.registerAppInterfaceParams.fullAppID = "spt"
config.application1.registerAppInterfaceParams.appHMIType = { "NAVIGATION" }
config.application2.registerAppInterfaceParams.appName = "server2"
config.application2.registerAppInterfaceParams.fullAppID = "spt2"
config.application2.registerAppInterfaceParams.appHMIType = { "NAVIGATION" }

--[[ Module ]]
local m = common

--[[ Proxy Functions ]]
m.wait = utils.wait
m.const = constants
m.pt = utils.printTable
m.cprint = utils.cprint

--[[ Common Functions ]]
function common.failTestCase(pReason)
  test:FailTestCase(pReason)
end

function m.sendGetSystemTimeResponse(pId, pMethod)
  local st = {
    millisecond = 100,
    second = 30,
    minute = 29,
    hour = 15,
    day = 20,
    month = 3,
    year = 2018,
    tz_hour = -3,
    tz_minute = 10
  }
  m.getHMIConnection():SendResponse(pId, pMethod, "SUCCESS", { systemTime = st })
end

function m.start()
  test:runSDL()
  commonFunctions:waitForSDLStart(test)
  :Do(function()
      utils.cprint(35, "SDL started")
      test:initHMI()
      :Do(function()
          utils.cprint(35, "HMI initialized")
          test:initHMI_onReady()
          :Do(function()
              utils.cprint(35, "HMI is ready")
              m.getHMIConnection():SendNotification("BasicCommunication.OnSystemTimeReady")
              test:connectMobile()
              :Do(function()
                  utils.cprint(35, "Mobile connected")
                  m.allowSDL()
                end)
            end)
        end)
    end)
end

function m.ptUpdate(pTbl)
  local filePath = "./files/Security/client_credential.pem"
  local crt = utils.readFile(filePath)
  pTbl.policy_table.module_config.certificate = crt
end

local preconditionsOrig = common.preconditions
function m.preconditions(pForceProtectedServices)
  preconditionsOrig()
  if not pForceProtectedServices then pForceProtectedServices = "Non" end
  local ForceUnprotectedService = "Non"
  m.setSDLIniParameter("ForceProtectedService", pForceProtectedServices)
  m.setSDLIniParameter("ForceUnprotectedService", ForceUnprotectedService)
end

local postconditionsOrig = common.postconditions
function m.postconditions()
  postconditionsOrig()
  m.restoreSDLIniParameters()
end

function m.decryptCertificateRes(pId, pMethod)
  m.getHMIConnection():SendResponse(pId, pMethod, "SUCCESS", { })
end

function m.policyTableUpdateSuccess(pPTUpdateFunc)
  local function expNotificationFunc()
    m.getHMIConnection():ExpectRequest("BasicCommunication.DecryptCertificate")
    :Do(function(_, data)
        m.decryptCertificateRes(data.id, data.method)
      end)
    :Times(AtMost(1))
    m.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData", { odometer = true })
  end
  m.getHMIConnection():ExpectRequest("BasicCommunication.PolicyUpdate")
  :Do(function(e, data)
      if e.occurences == 1 then
        m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
        m.policyTableUpdate(pPTUpdateFunc, expNotificationFunc)
      end
    end)
end

function m.policyTableUpdateUnsuccess()
  local pPTUpdateFunc = function(pTbl)
    pTbl.policy_table.app_policies = nil
  end
  local expNotificationFunc = function()
    common.getHMIConnection():ExpectRequest("VehicleInfo.GetVehicleData")
    :Times(0)
    common.getHMIConnection():ExpectRequest("BasicCommunication.DecryptCertificate")
    :Times(0)
  end
  common.getHMIConnection():ExpectRequest("BasicCommunication.PolicyUpdate")
  :Do(function(e, data)
      if e.occurences == 1 then
        common.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", { })
        common.policyTableUpdate(pPTUpdateFunc, expNotificationFunc)
      end
    end)
  :Times(AtLeast(1))
end

function m.onServiceUpdateFunc(pServiceTypeValue, pAppId)
  m.getHMIConnection():ExpectNotification("BasicCommunication.OnServiceUpdate",
    { serviceEvent = "REQUEST_RECEIVED", serviceType = pServiceTypeValue, appID = m.getHMIAppId(pAppId) },
    { serviceEvent = "REQUEST_ACCEPTED", serviceType = pServiceTypeValue, appID = m.getHMIAppId(pAppId) })
  :Times(2)
end

function m.policyTableUpdateFunc()
  m.getHMIConnection():ExpectNotification("SDL.OnStatusUpdate",
    { status = "UPDATE_NEEDED" }, { status = "UPDATING" }, { status = "UP_TO_DATE" })
  :Times(3)

  m.policyTableUpdateSuccess(m.ptUpdate)
end

function m.serviceResponseFunc(pServiceId, pStreamingFunc, pAppId)
  m.getMobileSession(pAppId):ExpectControlMessage(pServiceId, {
    frameInfo = m.frameInfo.START_SERVICE_ACK,
    encryption = true
  })
  :Do(function(_, data)
    if data.frameInfo == m.frameInfo.START_SERVICE_ACK and
    (data.serviceType == 10 or data.serviceType == 11) then
      pStreamingFunc(pAppId)
    end
  end)
end

function m.startServiceFunc(pServiceId, pAppId)
  m.getMobileSession(pAppId):StartSecureService(pServiceId)
end

local function startVideoStream()
  m.getHMIConnection():ExpectRequest("Navigation.StartStream")
  :Do(function(_, data)
    m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
  end)
end

local function startAudioStream()
  m.getHMIConnection():ExpectRequest("Navigation.StartAudioStream")
  :Do(function(_, data)
    m.getHMIConnection():SendResponse(data.id, data.method, "SUCCESS", {})
  end)
end

local function startVideoStreaming(pAppId)
  m.getMobileSession(pAppId):StartStreaming(11, "files/SampleVideo_5mb.mp4")
  m.getHMIConnection():ExpectNotification("Navigation.OnVideoDataStreaming", { available = true })
  m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus")
  :Times(0)
end

local function startAudioStreaming(pAppId)
  m.getMobileSession(pAppId):StartStreaming(10, "files/Kalimba2.mp3")
  m.getHMIConnection():ExpectNotification("Navigation.OnAudioDataStreaming", { available = true })
  m.getMobileSession(pAppId):ExpectNotification("OnHMIStatus")
  :Times(0)
end

m.serviceData = {
  [7] = {
    forceCode = "Non",
    serviceType = "RPC",
    startStreamFunc = function() end,
    streamingFunc = function() end
  },
  [10] = {
    forceCode = "0x0A",
    serviceType = "AUDIO",
    startStreamFunc = startAudioStream,
    streamingFunc = startAudioStreaming
  },
  [11] = {
    forceCode = "0x0B",
    serviceType = "VIDEO",
    startStreamFunc = startVideoStream,
    streamingFunc = startVideoStreaming
  }
}

function m.startServiceWithOnServiceUpdate(pServiceId, pHandShakeExpeTimes, pGSTExpTimes, pAppId)
  if not pAppId then pAppId = 1 end

  m.startServiceFunc(pServiceId, pAppId)

  m.getHMIConnection():ExpectRequest("BasicCommunication.GetSystemTime")
  :Do(function(_, data)
      m.sendGetSystemTimeResponse(data.id, data.method)
    end)
  :Times(pGSTExpTimes)

  m.serviceData[pServiceId].startStreamFunc()

  m.onServiceUpdateFunc(m.serviceData[pServiceId].serviceType, pAppId)

  m.policyTableUpdateFunc()

  m.getMobileSession(pAppId):ExpectHandshakeMessage()
  :Times(pHandShakeExpeTimes)

  m.serviceResponseFunc(pServiceId, m.serviceData[pServiceId].streamingFunc, pAppId)
end

function common.serviceResponseWithACKandNACK(pServiceId, pStreamingFunc, pTimeout)
  if not pTimeout then pTimeout = 10000 end
  if pServiceId ~= 7 then
    common.getMobileSession():ExpectControlMessage(pServiceId, {
      frameInfo = common.frameInfo.START_SERVICE_ACK,
      encryption = false
    })
    :Timeout(pTimeout)
    :Do(function(_, data)
      if data.frameInfo == common.frameInfo.START_SERVICE_ACK then
        pStreamingFunc()
      end
    end)
  else
    common.getMobileSession():ExpectControlMessage(pServiceId, {
      frameInfo = common.frameInfo.START_SERVICE_NACK,
      encryption = false
    })
    :Timeout(pTimeout)
  end
end

function m.setMobileCrt(pCrtFile)
  for _, v in pairs({"serverCertificatePath", "serverPrivateKeyPath", "serverCAChainCertPath" }) do
    config[v] = pCrtFile
  end
end

function m.log(...)
  local str = "[" .. atf_logger.formated_time(true) .. "]"
  for i, p in pairs({...}) do
    local delimiter = "\t"
    if i == 1 then delimiter = " " end
    str = str .. delimiter .. p
  end
  utils.cprint(35, str)
end

return m
