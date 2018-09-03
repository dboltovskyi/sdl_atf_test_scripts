---------------------------------------------------------------------------------------------
-- Requirement summary:
-- [INI file] [PolicyTableUpdate] PTS snapshot storage on a file system
--
-- Check creation of PT snapshot
-- 1. Used preconditions:
-- Do not start default SDL
-- 2. Performed steps:
-- Set correct PathToSnapshot path in INI file
-- Start SDL
-- Initiate PT snapshot creation
--
-- Expected result:
-- SDL must store the PT snapshot as a JSON file which filename and filepath are defined in "PathToSnapshot" parameter of smartDeviceLink.ini file.
---------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
Test = require('connecttest')
local config = require('config')
require('user_modules/AppTypes')
config.defaultProtocolVersion = 2

--[[ Required Shared libraries ]]
local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')
local commonSteps = require ('user_modules/shared_testcases/commonSteps')
require('cardinalities')
local mobile_session = require('mobile_session')
local utils = require ('user_modules/utils')

--[[ Local Variables ]]
local POLICY_SNAPSHOT_FILE_NAME = "sdl_mega_snapshot.json"
local SYSTEM_FILES_PATH = "/tmp" -- /tmp/fs/mp/images/ivsu_cache
local oldPathToPtSnapshot
local oldNameOfPtSnapshot

local TestData = {
  path = config.pathToSDL .. "TestData",
  isExist = false,
  init = function(self)
    if not self.isExist then
      os.execute("mkdir ".. self.path)
      os.execute("echo 'List test data files files:' > " .. self.path .. "/index.txt")
      self.isExist = true
    end
  end,
  store = function(self, message, pathToFile, fileName)
    if self.isExist then
      local dataToWrite = message

      if pathToFile and fileName then
        os.execute(table.concat({"cp ", pathToFile, " ", self.path, "/", fileName}))
        dataToWrite = table.concat({dataToWrite, " File: ", fileName})
      end

      dataToWrite = dataToWrite .. "\n"
      local file = io.open(self.path .. "/index.txt", "a+")
      file:write(dataToWrite)
      file:close()
    end
  end,
  delete = function(self)
    if self.isExist then
      os.execute("rm -r -f " .. self.path)
      self.isExist = false
    end
  end,
  info = function(self)
    if self.isExist then
      commonFunctions:userPrint(35, "All test data generated by this test were stored to folder: " .. self.path)
    else
      commonFunctions:userPrint(35, "No test data were stored" )
    end
  end
}

--[[ Local Functions ]]

local function setValueInSdlIni(parameterName, parameterValue)
  local sdlIniFileName = config.pathToSDL .. "smartDeviceLink.ini"
  local oldParameterValue
  local file = assert(io.open(sdlIniFileName, "r"))
  if file then
    local fileContent = file:read("*a")
    file:close()
    oldParameterValue = string.match(fileContent, parameterName .. "%s*=%s*(%S+)")
    if oldParameterValue then
      fileContent = string.gsub(fileContent, parameterName .. "%s*=%s*%S+", parameterName .. " = " .. parameterValue)
    else
      local lastCharOfFile = string.sub(fileContent, string.len(fileContent))
      if lastCharOfFile == "\n" then
        lastCharOfFile = ""
      else
        lastCharOfFile = "\n"
      end
      fileContent = table.concat({fileContent, lastCharOfFile, parameterName, " = ", parameterValue, "\n"})
      oldParameterValue = nil
    end
    file = assert(io.open(sdlIniFileName, "w"))
    if file then
      file:write(fileContent)
      file:close()
      return true, oldParameterValue
    else
      return false
    end
  else
    return false
  end
end

function Test.changePtsPathInSdlIni(newPath, parameterName)
  local result, oldPath = setValueInSdlIni(parameterName, newPath)
  if not result then
    commonFunctions:userPrint(31, "Test can't change SDL .ini file")
  end
  return oldPath
end

local function getAbsolutePath(path)
  if path:match("^%./") then
    return config.pathToSDL .. path:match("^%./(.+)")
  end
  if path:match("^/") then
    return path
  end
  return config.pathToSDL .. path
end

function Test.checkPtsFile()
  local file = io.open(getAbsolutePath(SYSTEM_FILES_PATH .. "/" .. POLICY_SNAPSHOT_FILE_NAME), "r")
  if file then
    file:close()
    return true
  else
    return false
  end
end

--[[ Preconditions ]]
commonFunctions:newTestCasesGroup("Preconditions")

function Test:StopSDL_precondition()
  TestData:init()
  StopSDL(self)
end

function Test:Precondition_StartSDL()
  TestData:store("Store original INI ", config.pathToSDL .. "smartDeviceLink.ini", "original_smartDeviceLink.ini")
  oldNameOfPtSnapshot = self.changePtsPathInSdlIni(POLICY_SNAPSHOT_FILE_NAME, "PathToSnapshot")
  oldPathToPtSnapshot = self.changePtsPathInSdlIni(SYSTEM_FILES_PATH, "SystemFilesPath")
  TestData:store("Store INI before start SDL", config.pathToSDL .. "smartDeviceLink.ini", "new_smartDeviceLink.ini")
  StartSDL(config.pathToSDL, true)
end

function Test:Precondition_InitHMIandMobileApp()
  self:initHMI()
  self:initHMI_onReady()
  self:connectMobile()
  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
  self.mobileSession:StartService(7)
end

function Test:Precondition_ActivateApp()

  local CorIdRAI = self.mobileSession:SendRPC("RegisterAppInterface",
    {
      syncMsgVersion =
      {
        majorVersion = 3,
        minorVersion = 0
      },
      appName = "SPT",
      isMediaApplication = true,
      languageDesired = "EN-US",
      hmiDisplayLanguageDesired = "EN-US",
      appID = "1234567",
      deviceInfo =
      {
        os = "Android",
        carrier = "Megafon",
        firmwareRev = "Name: Linux, Version: 3.4.0-perf",
        osVersion = "4.4.2",
        maxNumberRFCOMMPorts = 1
      }
    })
  EXPECT_RESPONSE(CorIdRAI, { success = true, resultCode = "SUCCESS"})
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered",
    {
      application =
      {
        appName = "SPT",
        policyAppID = "1234567",
        isMediaApplication = true,
        hmiDisplayLanguageDesired = "EN-US",
        deviceInfo =
        {
          name = utils.getDeviceName(),
          id = utils.getDeviceMAC(),
          transportType = "WIFI",
          isSDLAllowed = false
        }
      }
    })
  :Do(function(_,data)
      self.applications["SPT"] = data.params.application.appID
      local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", {appID = self.applications["SPT"]})
      EXPECT_HMIRESPONSE(RequestId, { result = {
            code = 0,
            isSDLAllowed = false},
          method = "SDL.ActivateApp"})
      :Do(function(_,_)
          local RequestId2 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})
          EXPECT_HMIRESPONSE(RequestId2,{result = {code = 0, method = "SDL.GetUserFriendlyMessage"}})
          :Do(function(_,_)
              self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality", {allowed = true, source = "GUI"})
              EXPECT_HMICALL("BasicCommunication.ActivateApp"):Times(AtLeast(1))
              :DoOnce(function(_,data2)
                  self.hmiConnection:SendResponse(data2.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
                end)
            end)
        end)
    end)
end

function Test.Precondition_WaitForSnapshot()
  os.execute("sleep 3")
end

--[[ Test ]]
commonFunctions:newTestCasesGroup("Test")

function Test:Test()
  if not self:checkPtsFile() then
    self:FailTestCase("PT snapshot wasn't created")
  end
end

--[[ Postconditions ]]
commonFunctions:newTestCasesGroup("Postconditions")

function Test:Postcondition()
  commonSteps:DeletePolicyTable(self)
  self.changePtsPathInSdlIni(oldNameOfPtSnapshot, "PathToSnapshot")
  self.changePtsPathInSdlIni(oldPathToPtSnapshot, "SystemFilesPath")
  TestData:store("Store INI at the end of test", config.pathToSDL .. "smartDeviceLink.ini", "restored_smartDeviceLink.ini")
  TestData:info()
end

function Test.Postcondition_StopSDL()
  StopSDL()
end

return Test
