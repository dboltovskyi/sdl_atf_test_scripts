--This script contains common functions that are used in CRQs:
-- [GENIVI] SDL must retrieve the value of 'menuIcon' and 'menuTitle' parameters from .ini file
--How to use:
  --1. local testCasesForMenuIconMenuTitleParameters = require('user_modules/shared_testcases/testCasesForMenuIconMenuTitleParameters')

local commonFunctions = require ('user_modules/shared_testcases/commonFunctions')

local testCasesForMenuIconMenuTitleParameters = {}

--[[@ReadCmdLine: returns output in console as result of specific shell command.
--! @parameters:
--! @cmd - shell command
--! @raw - single raw of command
--]]
function testCasesForMenuIconMenuTitleParameters:ReadCmdLine(cmd,raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

--[[@UpdateINI - update INI file according to specified parameter
--! @parameters:
--! @type_path: absolute, relative, empty
--]]
function testCasesForMenuIconMenuTitleParameters:UpdateINI(type_path)
	local icon_to_check = "default_icon.png"
	local empty_menuIcon
	local absolute_path = self:ReadCmdLine("pwd")

  if type_path == nil then type_path = "relative" end
  local menuIcon = commonFunctions:read_parameter_from_smart_device_link_ini("menuIcon")

  -- By default the value of "menuIcon" must be empty and will be assigned as relative value
  if ( (type_path ~= "empty") and (menuIcon == "") ) then
    menuIcon = "default_icon.png"
  end

  if not menuIcon then
    empty_menuIcon = true
    print ("\27[31m ERROR: menuIcon is not found in smartDeviceLink.ini. \27[0m " )

  else

		icon_to_check = menuIcon
		absolute_path = absolute_path .."/SDL_bin/".. menuIcon

		if (type_path == "absolute") then
			icon_to_check = absolute_path
			commonFunctions:write_parameter_to_smart_device_link_ini("menuIcon", icon_to_check)
    elseif (type_path == "empty") then
      commonFunctions:write_parameter_to_smart_device_link_ini("menuIcon", "")
    end

  end

  return empty_menuIcon, icon_to_check, absolute_path
end

--[[@CheckINI_menuTitle - read from INI file menuTitle
--! @parameters: NO
--]]
function testCasesForMenuIconMenuTitleParameters:CheckINI_menuTitle()
  local result = true
  local menuTitle = commonFunctions:read_parameter_from_smart_device_link_ini("menuTitle")

  if not menuTitle then
    print ("\27[31m ERROR: menuTitle is not found in smartDeviceLink.ini \27[0m " )
    result = false
  else
    if (menuTitle ~= "MENU") then
      print ("\27[31m ERROR: menuTitle is not equal to MENU in smartDeviceLink.ini \27[0m " )
      result = false
    end
  end

  return result
end

function testCasesForMenuIconMenuTitleParameters:ActivateAppDiffPolicyFlag(self, app_name, device_ID)
  local ServerAddress = "127.0.0.1"--commonSteps:get_data_from_SDL_ini("ServerAddress")

  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications[app_name]})

  EXPECT_HMIRESPONSE(RequestId)
  :Do(function(_,data)
		if(data.result.isSDLAllowed == false) then
	    local RequestId1 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})
	    --hmi side: expect SDL.GetUserFriendlyMessage message response
	    EXPECT_HMIRESPONSE( RequestId1, {result = {code = 0, method = "SDL.GetUserFriendlyMessage"}})
	    :Do(function(_,_)
	      self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
	        {allowed = true, source = "GUI"})
	    end)
		  EXPECT_HMICALL("BasicCommunication.ActivateApp"):Times(AtLeast(1))
	    :DoOnce(function() self.hmiConnection:SendResponse(data.id,"BasicCommunication.ActivateApp", "SUCCESS", {}) end)
	  end

  end)

  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"})
end

return testCasesForMenuIconMenuTitleParameters
