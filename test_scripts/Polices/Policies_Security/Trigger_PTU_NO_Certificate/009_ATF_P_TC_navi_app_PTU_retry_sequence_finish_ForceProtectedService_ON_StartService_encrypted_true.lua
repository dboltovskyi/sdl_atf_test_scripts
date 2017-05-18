---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [PTU] [GENIVI] PolicyTableUpdate is failed by any reason and "ForceProtectedService"=ON at .ini file
-- [PTU] [GENIVI] SDL must start PTU for navi app right after app successfully registration
--
-- Description:
-- In case SDL starts PolicyTableUpdate in case of no "certificate" at "module_config" section at LocalPT
-- and PolicyTableUpdate is failed by any reason even after retry strategy (please see related req-s HTTP flow and Proprietary flow)
-- and "ForceProtectedService" is ON(0x07, 0x0A, 0x0B, 0x0F) at .ini file
-- and app sends StartService (<any_serviceType>, encypted=true) to SDL
-- SDL must respond StartService (NACK) to this mobile app
--
-- 1. Used preconditions:
-- Navi app exists in LP, no certificate in module_config
--
-- 2. Performed steps
-- 2.1 Register and activate navi application.
-- 2.2 Wait PTU retry sequence to elapse.
-- 2.3 Send Audio service.
-- 2.4 Send Video service.
-- 2.5 Send RPC service.
-- 2.6 Send Hybrid service.
--
-- Expected result:
-- 1. SDL should trigger PTU: SDL.OnStatusUpdate(UPDATE_NEEDED)
-- 2. SDL invalidates PTU
-- 3. SDL should return StartServiceNACK to Audio
-- 4. SDL should return StartServiceNACK to Video
-- 5. SDL should return StartServiceNACK to RPC
-- 6. SDL should return StartServiceNACK to Hybrid
---------------------------------------------------------------------------------------------

--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.application1.registerAppInterfaceParams.appHMIType = {"NAVIGATION"}
--TODO(istoimenova): Should be removed when issue: "ATF does not stop HB timers by closing session and connection" is fixed
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require('user_modules/shared_testcases/commonSteps')
local commonTestCases = require('user_modules/shared_testcases/commonTestCases')
local commonPreconditions = require('user_modules/shared_testcases/commonPreconditions')
local testCasesForPolicyCeritificates = require('user_modules/shared_testcases/testCasesForPolicyCeritificates')
local mobile_session = require('mobile_session')
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

--[[ General Precondition before ATF start ]]
commonPreconditions:BackupFile("smartDeviceLink.ini")
commonFunctions:write_parameter_to_smart_device_link_ini("ForceProtectedService", "0x07, 0x0A, 0x0B, 0x0F")
testCasesForPolicyCeritificates.update_preloaded_pt(config.application1.registerAppInterfaceParams.appID, false, seconds_between_retries, timeout_after_x_seconds)
testCasesForPolicyCeritificates.create_ptu_certificate_exist(nil, true)
commonSteps:DeletePolicyTable()
commonSteps:DeleteLogsFiles()

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
  testCasesForPolicyCeritificates.StartService_encryption(self, 7)
end

function Test:Precondition_RAI_PTU_Trigger()
  local CorIdRegister = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)

  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config.application1.registerAppInterfaceParams.appName }})
  :Do(function(_,data) self.applications[config.application1.registerAppInterfaceParams.appName] = data.params.application.appID end)

  EXPECT_RESPONSE(CorIdRegister, { success = true, resultCode = "SUCCESS" })
  EXPECT_NOTIFICATION("OnHMIStatus", { systemContext = "MAIN", hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE"})

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", {status = "UPDATE_NEEDED"}, {status = "UPDATING"}):Times(2)
end

function Test:Precondition_ActivateApp()
  commonSteps:ActivateAppInSpecificLevel(self, self.applications[config.application1.registerAppInterfaceParams.appName])
  EXPECT_NOTIFICATION("OnHMIStatus", {systemContext = "MAIN", hmiLevel = "FULL"})
end

function Test.Precondition_PolicyTableUpdate_retry_sequence_elapse()
  print("Wait retry sequence to elapse: " .. total_time_wait .. "ms")

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"})
  :Times(11)
  :Timeout(total_time_wait)
  :Do(function(exp, data)
      print("[" .. atf_logger.formated_time(true) .. "] " .. "SDL->HMI: SDL.OnStatusUpdate()" .. ": " .. exp.occurences .. ": " .. data.params.status)
    end)

  commonTestCases:DelayedExp(total_time_wait)
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:TestStep_Audio_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1
  local msg = {
    serviceType = 10,
    frameInfo = 1,
    frameType = 0,
    rpcCorrelationId = self.mobileSession.correlationId,
    encryption = true
  }
  testCasesForPolicyCeritificates.start_service_NACK(self, msg, 10,"Audio")
end

function Test:TestStep_Video_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1
  local msg = {
    serviceType = 11,
    frameInfo = 1,
    frameType = 0,
    rpcCorrelationId = self.mobileSession.correlationId,
    encryption = true
  }
  testCasesForPolicyCeritificates.start_service_NACK(self, msg, 11,"Video")
end

function Test:TestStep_RPC_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = 7,
    frameInfo = 1,
    frameType = 0,
    rpcCorrelationId = self.mobileSession.correlationId,
    encryption = true
  }
  testCasesForPolicyCeritificates.start_service_NACK(self, msg, 7,"RPC")
end

function Test:TestStep_Hybrid_NACK()
  self.mobileSession.correlationId = self.mobileSession.correlationId + 1

  local msg = {
    serviceType = 15,
    frameInfo = 1,
    frameType = 0,
    rpcCorrelationId = self.mobileSession.correlationId,
    encryption = true
  }
  testCasesForPolicyCeritificates.start_service_NACK(self, msg, 15,"Hybrid")
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
