---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [PTU] [GENIVI] PolicyTableUpdate is failed by any reason and "ForceProtectedService"=OFF at .ini file
-- [PTU] [GENIVI] SDL must start PTU for any app except navi right after app successfully request to start first secure service
--
-- Description:
-- In case SDL starts PolicyTableUpdate in case of no "certificate" at "module_config" section at LocalPT
-- and PolicyTableUpdate is failed by any reason even after retry strategy
-- and "ForceProtectedService" is OFF at .ini file
-- and app sends StartService (<any_serviceType>, encypted=true) to SDL
-- SDL must respond StartService (ACK, encrypted=false) to this mobile app
--
-- 1. Used preconditions:
-- ForceProtectedService is set to OFF in .ini file
-- Communication app exists in LP, no certificate in module_config
-- Register and activate application.
-- Send StartService(serviceType = 7 (RPC))
-- -> SDL should trigger PTU: SDL.OnStatusUpdate(UPDATE_NEEDED)
-- -> SDL should not respond to StartService_request
--
-- 2. Performed steps
-- Wait PTU retry sequence to elapse.
--
-- Expected result:
-- SDL must respond StartServiceNACK
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.application1.registerAppInterfaceParams.appHMIType = {"COMMUNICATION"}
--TODO(istoimenova): Should be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForPolicyCeritificates = require('user_modules/shared_testcases/testCasesForPolicyCeritificates')
local events = require('events')
local Event = events.Event
local atf_logger = require("atf_logger")

--[[ Local variables ]]
local timeout_after_x_seconds = 15
local seconds_between_retries = {1, 1, 1, 1, 1}

local time_wait = {}
time_wait[0] = timeout_after_x_seconds -- 15
time_wait[1] = timeout_after_x_seconds + seconds_between_retries[1] -- 15 + 1 = 16
time_wait[2] = timeout_after_x_seconds + seconds_between_retries[2] + time_wait[1] -- 15 + 1 + 16 = 32
time_wait[3] = timeout_after_x_seconds + seconds_between_retries[3] + time_wait[2] -- 15 + 1 + 32 = 48
time_wait[4] = timeout_after_x_seconds + seconds_between_retries[4] + time_wait[3] -- 15 + 1 + 48 = 64
time_wait[5] = timeout_after_x_seconds + seconds_between_retries[5] + time_wait[4] -- 15 + 1 + 64 = 80

local total_time_wait = (time_wait[0] + time_wait[1] + time_wait[2] + time_wait[3] + time_wait[4] + time_wait[5]) * 1000 + 10000

local time_ptu_finish = 0

--[[ General Precondition before ATF start ]]
commonPreconditions:BackupFile("smartDeviceLink.ini")
commonFunctions:write_parameter_to_smart_device_link_ini("ForceProtectedService", "Non")
testCasesForPolicyCeritificates.update_preloaded_pt(config.application1.registerAppInterfaceParams.appID, false, seconds_between_retries, timeout_after_x_seconds)
testCasesForPolicyCeritificates.create_ptu_certificate_exist(false, true)
commonSteps:DeletePolicyTable()
commonSteps:DeleteLogsFiles()

--[[ General Settings for configuration ]]
Test = require('connecttest')
require('user_modules/AppTypes')

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:Precondition_ActivateApp()
  commonSteps:ActivateAppInSpecificLevel(self, self.applications[config.application1.registerAppInterfaceParams.appName])
  EXPECT_NOTIFICATION("OnHMIStatus", {systemContext = "MAIN", hmiLevel = "FULL"})
end

function Test:Precondition_First_StartService()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = 7,
    frameType = 0,
    frameInfo = 1,
    encryption = true,
    rpcCorrelationId = self.mobileSession.correlationId
  }

  self.mobileSession:Send(msg)

  local startserviceEvent = Event()
  startserviceEvent.matches =
  function(_, data)
    return ( (data.serviceType == 7) and (data.frameInfo == 2 or data.frameInfo == 3) )
  end

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", { status = "UPDATE_NEEDED" }, { status = "UPDATING" }):Times(2)
  EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
  :Do(function(_,data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
    end)

  self.mobileSession:ExpectEvent(startserviceEvent, "Service 7: RPC"):Times(0)

  commonTestCases:DelayedExp(10000)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_PolicyTableUpdate_retry_sequence_finish()
  print("Wait retry sequence to elapse: " .. total_time_wait .. "ms")

  local startserviceEvent = Event()
  startserviceEvent.matches =
  function(_, data)
    return ( (data.serviceType == 7) and (data.frameInfo == 2 or data.frameInfo == 3) )
  end

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
    {status = "UPDATE_NEEDED"}, {status = "UPDATING"},
    {status = "UPDATE_NEEDED"}, {status = "UPDATING"},
    {status = "UPDATE_NEEDED"}, {status = "UPDATING"},
    {status = "UPDATE_NEEDED"}, {status = "UPDATING"},
    {status = "UPDATE_NEEDED"}, {status = "UPDATING"},
    {status = "UPDATE_NEEDED"})
  :Times(11)
  :Timeout(total_time_wait)
  :Do(function(exp, data)
      print("[" .. atf_logger.formated_time(true) .. "] " .. "SDL->HMI: SDL.OnStatusUpdate()" .. ": " .. exp.occurences .. ": " .. data.params.status)
      if(exp.occurences == 11) then
        time_ptu_finish = timestamp()
        print("time_ptu_finish = "..tostring(time_ptu_finish))
      end
    end)

  self.mobileSession:ExpectEvent(startserviceEvent, "Service 7: StartServiceNACK")
  :ValidIf(function(_, data)
      local function verify_time_response()
        if (time_ptu_finish == 0) then
          commonFunctions:printError("Response of Service 7 is received before PTU retry sequence finish")
          return false
        else
          return true
        end
      end

      if data.frameInfo == 3 then
        local result = verify_time_response()
        print("Service 7: StartServiceNACK")
        return result
      elseif data.frameInfo == 2 then
        verify_time_response()
        commonFunctions:printError("Service 7: StartService ACK is received")
        return false
      else
        commonFunctions:printError("Service 7: StartServiceACK/NACK is not received at all.")
        return false
      end
    end)
  :Timeout(total_time_wait)
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test.Postcondition_Restore_files()
  os.execute( " rm -f files/ptu_certificate_exist.json" )
  commonPreconditions:RestoreFile("smartDeviceLink.ini")
  commonPreconditions:RestoreFile("sdl_preloaded_pt.json")
end

function Test.Postcondition_Stop()
  StopSDL()
end

return Test
