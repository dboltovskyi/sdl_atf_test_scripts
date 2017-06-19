---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.application1.registerAppInterfaceParams.appHMIType = {"NAVIGATION"}

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')
local mobile_session = require('mobile_session')
local testCasesForPolicyCeritificates = require('user_modules/shared_testcases/testCasesForPolicyCeritificates')
local events = require('events')
local Event = events.Event

--[[ Local Variables ]]
local serviceType = 10
local total_time_wait = 10000

--[[ Local Functions ]]
local function ptu(self)
  local SystemFilesPath = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath")
  local RequestId_GetUrls = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(RequestId_GetUrls,{result = {code = 0, method = "SDL.GetURLS"} } )
  :Do(function(_,_)
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest",
        { requestType = "PROPRIETARY", fileName = "PolicyTableUpdate"})
      EXPECT_NOTIFICATION("OnSystemRequest", {requestType = "PROPRIETARY"})
      :Do(function()
          local CorIdSystemRequest = self.mobileSession:SendRPC("SystemRequest", {requestType = "PROPRIETARY", fileName = "PolicyTableUpdate"},
          "files/ptu_certificate_exist.json")
          EXPECT_HMICALL("BasicCommunication.SystemRequest",{ requestType = "PROPRIETARY", fileName = SystemFilesPath.."/PolicyTableUpdate" })
          :Do(function(_,_data1)
              self.hmiConnection:SendResponse(_data1.id,"BasicCommunication.SystemRequest", "SUCCESS", {})
              self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = SystemFilesPath.."/PolicyTableUpdate"})
            end)
          EXPECT_RESPONSE(CorIdSystemRequest, { success = true, resultCode = "SUCCESS"})
        end)
    end)
end

local function getServiceType(id)
if id == 0 then return "CONTROL"
  elseif id == 7 then return "RPC"
  elseif id == 10 then return "PCM"
  elseif id == 11 then return "VIDEO"
  elseif id == 15 then return "BULK_DATA"
  else return tostring(id) end
end

local function getFrameInfo(id)
  if id == 0 then return "HEARTBEAT"
  elseif id == 1 then return "START_SERVICE"
  elseif id == 2 then return "START_SERVICE_ACK"
  elseif id == 3 then return "START_SERVICE_NACK"
  elseif id == 4 then return "END_SERVICE"
  elseif id == 5 then return "END_SERVICE_ACK"
  elseif id == 6 then return "END_SERVICE_NACK"
  else return tostring(id) end
end

--[[ General Precondition before ATF start ]]
commonFunctions:SDLForceStop()
commonSteps:DeletePolicyTable()
commonSteps:DeleteLogsFiles()
commonPreconditions:BackupFile("smartDeviceLink.ini")
commonFunctions:write_parameter_to_smart_device_link_ini("ForceProtectedService", "Non")
testCasesForPolicyCeritificates.update_preloaded_pt(config.application1.registerAppInterfaceParams.appID, false)

--[[ General Settings for configuration ]]
Test = require('user_modules/connecttest_resumption')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:Precondition_connectMobile()
  self:connectMobile()
end

function Test:Precondition_StartSession()
  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
  self.mobileSession:StartService(7)
end

function Test:Precondition_RAI_PTU_Trigger_PTU_SUCCESS()
  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate"):Times(3)
  :Do(function(e, d) print("SDL.OnStatusUpdate", e.occurences, d.params.status) end)
  local CorIdRegister = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config.application1.registerAppInterfaceParams.appName }})
  :Do(function(_,data)
      self.applications[config.application1.registerAppInterfaceParams.appName] = data.params.application.appID
      EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
      :Do(function(_, d2)
          self.hmiConnection:SendResponse(d2.id, d2.method, "SUCCESS", { })
          testCasesForPolicyCeritificates.create_ptu_certificate_exist(false, false) -- include_certificate, invalid_ptu
          ptu(self)
        end)
    end)

  EXPECT_RESPONSE(CorIdRegister, { success = true, resultCode = "SUCCESS" })
  EXPECT_NOTIFICATION("OnHMIStatus", { systemContext = "MAIN", hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE"})
end

function Test:Precondition_ActivateApp()
  commonSteps:ActivateAppInSpecificLevel(self, self.applications[config.application1.registerAppInterfaceParams.appName])
  EXPECT_NOTIFICATION("OnHMIStatus", {systemContext = "MAIN", hmiLevel = "FULL"})
end

function Test:Precondition_CheckStatus_UP_TO_DATE()
  local reqId = self.hmiConnection:SendRequest("SDL.GetStatusUpdate")
  EXPECT_HMIRESPONSE(reqId, { status = "UP_TO_DATE" })
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:StartSecureService()
  print("Wait: " .. total_time_wait .. "ms")

  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = serviceType,
    frameInfo = 1,
    frameType = 0,
    rpcCorrelationId = self.mobileSession.correlationId,
    encryption = true
  }
  self.mobileSession:Send(msg)

  local startserviceEvent = Event()
  startserviceEvent.matches = function(_, data) return (data.frameType == 0 and data.serviceType == serviceType) end

  self.mobileSession:ExpectEvent(startserviceEvent, "Service ".. serviceType)
  :Times(AtLeast(1))
  :Do(function(e, data)
      print("Service: " .. serviceType .. "         ", e.occurences,
        "serviceType: " .. getServiceType(data.serviceType) .. ", " ..
        "frameInfo: " .. getFrameInfo(data.frameInfo) .. ", " ..
        "encryption: " .. tostring(data.encryption))
    end)
  :ValidIf(function(e, data)
    if ((e.occurences == 1) and (data.frameInfo == 2) and (data.encryption == false))
    or ((e.occurences == 2) and (data.frameInfo == 4) and (data.encryption == false)) then
      return true
    end
    return false, "StartServiceACK, encryption: false is not received"
  end)

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
    {status = "UPDATE_NEEDED"}, {status = "UPDATING"}, {status = "UP_TO_DATE"})
  :Times(3)
  :Do(function(e, d) print("SDL.OnStatusUpdate", e.occurences, d.params.status) end)

  EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
  :Do(function(e, d)
      print("BC.PolicyUpdate   ", e.occurences)
      self.hmiConnection:SendResponse(d.id, d.method, "SUCCESS", { })
      testCasesForPolicyCeritificates.create_ptu_certificate_exist(false, false) -- include_certificate, invalid_ptu
      ptu(self)
    end)

  commonTestCases:DelayedExp(total_time_wait)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_Restore_Files()
  os.execute("rm -f files/ptu_certificate_exist.json")
  commonPreconditions:RestoreFile("smartDeviceLink.ini")
  commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
end

function Test.Postcondition_Stop()
  StopSDL()
end

return Test
