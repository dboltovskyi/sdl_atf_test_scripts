---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [PTU] [GENIVI] PolicyTableUpdate is failed by any reason and "ForceProtectedService"=OFF at .ini file
-- [PTU] [GENIVI] SDL must start PTU for navi app right after app successfully registration
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
-- Navi app exists in LP, no certificate in module_config
-- Register and activate navi application.
-- -> SDL should trigger PTU: SDL.OnStatusUpdate(UPDATE_NEEDED)
--
-- 2. Performed steps
-- 2.1 Wait PTU retry sequence to finish
-- 2.2 Send Hybrid service.
--
-- Expected result:
-- 1. SDL sends SDL.OnStatusUpdate(UPDATE_NEEDED)
-- 2. SDL should return StartServiceACK, encrypt = false to Hybrid
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

--[[ Local variables ]]
local time_wait = (60 + 61 + 62 + 62 + 62 + 62)*1000

--[[ General Precondition before ATF start ]]
commonPreconditions:BackupFile("smartDeviceLink.ini")
commonFunctions:write_parameter_to_smart_device_link_ini("ForceProtectedService", "Non")
testCasesForPolicyCeritificates.update_preloaded_pt(config.application1.registerAppInterfaceParams.appID, false, {1,1,1,1,1})
testCasesForPolicyCeritificates.create_ptu_certificate_exist(false, true)
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
  self.mobileSession:StartService(7)
end

function Test:Precondition_PTU_Trigger()
  local CorIdRegister = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)

  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config.application1.registerAppInterfaceParams.appName }})
  :Do(function(_,data) self.applications[config.application1.registerAppInterfaceParams.appName] = data.params.application.appID end)

  EXPECT_RESPONSE(CorIdRegister, { success = true, resultCode = "SUCCESS" })
  EXPECT_NOTIFICATION("OnHMIStatus", { systemContext = "MAIN", hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE"})

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", {status="UPDATE_NEEDED"}, {status = "UPDATING"}):Times(2)
end

function Test:Precondition_ActivateApp()
  commonSteps:ActivateAppInSpecificLevel(self, self.applications[config.application1.registerAppInterfaceParams.appName])
  EXPECT_NOTIFICATION("OnHMIStatus", {systemContext = "MAIN", hmiLevel = "FULL"})
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test.TestStep_PolicyTableUpdate_retry_sequence_elapse()
  print("Wait retry sequence to elapse")

  EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate",
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"}, {status = "UPDATING"},
    {status="UPDATE_NEEDED"})
  :Times(9)
  :Timeout(time_wait)
  :Do(function(exp, data) print("exp: ".. exp.occurences) print("data = "..data.params.status)end)

  commonTestCases:DelayedExp(time_wait)
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
  self.mobileSession:Send(msg)

  local startserviceEvent = Event()
  startserviceEvent.matches =
  function(_, data)
    return ( data.frameType == 0 and data.serviceType == 15)
  end

  self.mobileSession:ExpectEvent(startserviceEvent, "Service 15: StartServiceNACK")
  :ValidIf(function(_, data)
      if data.frameInfo == 2 then
        commonFunctions:printError("Service 15: StartService ACK is received")
        return false
      elseif data.frameInfo == 3 then
        print("Service 15: StartService NACK is received")
        return true
      else
        commonFunctions:printError("Service 15: StartServiceACK/NACK is not received at all.")
        return false
      end
    end)

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
