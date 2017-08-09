---------------------------------------------------------------------------------------------------
-- RC common module
---------------------------------------------------------------------------------------------------
--[[ General configuration parameters ]]
config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.defaultProtocolVersion = 2
config.ValidateSchema = false
config.application1.registerAppInterfaceParams.appHMIType = { "REMOTE_CONTROL" }
config.application2.registerAppInterfaceParams.appHMIType = { "REMOTE_CONTROL" }

--[[ Required Shared libraries ]]
local commonFunctions = require("user_modules/shared_testcases/commonFunctions")
local commonSteps = require("user_modules/shared_testcases/commonSteps")
local commonTestCases = require("user_modules/shared_testcases/commonTestCases")
local mobile_session = require("mobile_session")
local json = require("modules/json")

--[[ Local Variables ]]
local ptu_table = {}
local hmiAppIds = {}

local commonRC = {}

commonRC.timeout = 2000

local function initHMI(self)
  local exp_waiter = commonFunctions:createMultipleExpectationsWaiter(self, "HMI initialization")
  local function registerComponent(name, subscriptions)
    local rid = self.hmiConnection:SendRequest("MB.registerComponent", { componentName = name })
    local exp = EXPECT_HMIRESPONSE(rid)
    exp_waiter:AddExpectation(exp)
    if subscriptions then
      for _, s in ipairs(subscriptions) do
        exp:Do(function()
            rid = self.hmiConnection:SendRequest("MB.subscribeTo", { propertyName = s })
            exp = EXPECT_HMIRESPONSE(rid)
            exp_waiter:AddExpectation(exp)
          end)
      end
    end
  end

  local web_socket_connected_event = EXPECT_HMIEVENT(events.connectedEvent, "Connected websocket")
  :Do(function()
      registerComponent("Buttons", {"Buttons.OnButtonSubscription"})
      registerComponent("TTS")
      registerComponent("VR")
      registerComponent("BasicCommunication", {
          "BasicCommunication.OnPutFile",
          "SDL.OnStatusUpdate",
          "SDL.OnAppPermissionChanged",
          "BasicCommunication.OnSDLPersistenceComplete",
          "BasicCommunication.OnFileRemoved",
          "BasicCommunication.OnAppRegistered",
          "BasicCommunication.OnAppUnregistered",
          "BasicCommunication.PlayTone",
          "BasicCommunication.OnSDLClose",
          "SDL.OnSDLConsentNeeded",
          "BasicCommunication.OnResumeAudioSource"
        })
      registerComponent("UI", {
          "UI.OnRecordStart"
        })
      registerComponent("VehicleInfo")
      registerComponent("RC")
      registerComponent("Navigation", {
          "Navigation.OnAudioDataStreaming",
          "Navigation.OnVideoDataStreaming"
        })
    end)
  exp_waiter:AddExpectation(web_socket_connected_event)

  self.hmiConnection:Connect()
  return exp_waiter.expectation
end

local function initHMI_onReady(self)
  local exp_waiter = commonFunctions:createMultipleExpectationsWaiter(module, "HMI on ready")
  local function ExpectRequest(name, mandatory, params)
    local event = events.Event()
    event.level = 2
    event.matches = function(self, data)
      return data.method == name
    end
    local exp = EXPECT_HMIEVENT(event, name)
    :Times(mandatory and 1 or AnyNumber())
    :Do(function(_, data)
        xmlReporter.AddMessage("hmi_connection","SendResponse",
          {
            ["methodName"] = tostring(name),
            ["mandatory"] = mandatory ,
            ["params"]= params
          })
        self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", params)
      end)
    if (mandatory) then
     exp_waiter:AddExpectation(exp)
    end
   return exp
  end

  local function ExpectNotification(name, mandatory)
    xmlReporter.AddMessage(debug.getinfo(1, "n").name, tostring(name))
    local event = events.Event()
    event.level = 2
    event.matches = function(self, data) return data.method == name end
    local exp = EXPECT_HMIEVENT(event, name)
    :Times(mandatory and 1 or AnyNumber())
    exp_waiter:AddExpectation(exp)
    return exp
  end

  ExpectRequest("BasicCommunication.MixingAudioSupported",
    true,
    { attenuatedSupported = true })
  ExpectRequest("BasicCommunication.GetSystemInfo", false,
    {
      ccpu_version = "ccpu_version",
      language = "EN-US",
      wersCountryCode = "wersCountryCode"
    })
  ExpectRequest("UI.GetLanguage", true, { language = "EN-US" })
  ExpectRequest("VR.GetLanguage", true, { language = "EN-US" })
  ExpectRequest("TTS.GetLanguage", true, { language = "EN-US" })
  ExpectRequest("UI.ChangeRegistration", false, { }):Pin()
  ExpectRequest("TTS.SetGlobalProperties", false, { }):Pin()
  ExpectRequest("BasicCommunication.UpdateDeviceList", false, { }):Pin()
  ExpectRequest("VR.ChangeRegistration", false, { }):Pin()
  ExpectRequest("TTS.ChangeRegistration", false, { }):Pin()
  ExpectRequest("VR.GetSupportedLanguages", true, {
      languages = {
        "EN-US","ES-MX","FR-CA","DE-DE","ES-ES","EN-GB","RU-RU",
        "TR-TR","PL-PL","FR-FR","IT-IT","SV-SE","PT-PT","NL-NL",
        "ZH-TW","JA-JP","AR-SA","KO-KR","PT-BR","CS-CZ","DA-DK",
        "NO-NO","NL-BE","EL-GR","HU-HU","FI-FI","SK-SK" }
    })
  ExpectRequest("TTS.GetSupportedLanguages", true, {
      languages = {
        "EN-US","ES-MX","FR-CA","DE-DE","ES-ES","EN-GB","RU-RU",
        "TR-TR","PL-PL","FR-FR","IT-IT","SV-SE","PT-PT","NL-NL",
        "ZH-TW","JA-JP","AR-SA","KO-KR","PT-BR","CS-CZ","DA-DK",
        "NO-NO","NL-BE","EL-GR","HU-HU","FI-FI","SK-SK" }
    })
  ExpectRequest("UI.GetSupportedLanguages", true, {
      languages = {
        "EN-US","ES-MX","FR-CA","DE-DE","ES-ES","EN-GB","RU-RU",
        "TR-TR","PL-PL","FR-FR","IT-IT","SV-SE","PT-PT","NL-NL",
        "ZH-TW","JA-JP","AR-SA","KO-KR","PT-BR","CS-CZ","DA-DK",
        "NO-NO","NL-BE","EL-GR","HU-HU","FI-FI","SK-SK" }
    })
  ExpectRequest("VehicleInfo.GetVehicleType", true, {
      vehicleType =
      {
        make = "Ford",
        model = "Fiesta",
        modelYear = "2013",
        trim = "SE"
      }
    })
  ExpectRequest("VehicleInfo.GetVehicleData", true, { vin = "52-452-52-752" })

  local function button_capability(name, shortPressAvailable, longPressAvailable, upDownAvailable)
    return
    {
      name = name,
      shortPressAvailable = shortPressAvailable == nil and true or shortPressAvailable,
      longPressAvailable = longPressAvailable == nil and true or longPressAvailable,
      upDownAvailable = upDownAvailable == nil and true or upDownAvailable
    }
  end

  local buttons_capabilities =
  {
    capabilities =
    {
      button_capability("PRESET_0"),
      button_capability("PRESET_1"),
      button_capability("PRESET_2"),
      button_capability("PRESET_3"),
      button_capability("PRESET_4"),
      button_capability("PRESET_5"),
      button_capability("PRESET_6"),
      button_capability("PRESET_7"),
      button_capability("PRESET_8"),
      button_capability("PRESET_9"),
      button_capability("OK", true, false, true),
      button_capability("SEEKLEFT"),
      button_capability("SEEKRIGHT"),
      button_capability("TUNEUP"),
      button_capability("TUNEDOWN")
    },
    presetBankCapabilities = { onScreenPresetsAvailable = true }
  }
  ExpectRequest("Buttons.GetCapabilities", true, buttons_capabilities)
  ExpectRequest("VR.GetCapabilities", true, { vrCapabilities = { "TEXT" } })
  ExpectRequest("TTS.GetCapabilities", true, {
      speechCapabilities = { "TEXT", "PRE_RECORDED" },
      prerecordedSpeechCapabilities =
      {
        "HELP_JINGLE",
        "INITIAL_JINGLE",
        "LISTEN_JINGLE",
        "POSITIVE_JINGLE",
        "NEGATIVE_JINGLE"
      }
    })

  local function text_field(name, characterSet, width, rows)
    return
    {
      name = name,
      characterSet = characterSet or "TYPE2SET",
      width = width or 500,
      rows = rows or 1
    }
  end
  local function image_field(name, width, height)
    return
    {
      name = name,
      imageTypeSupported =
      {
        "GRAPHIC_BMP",
        "GRAPHIC_JPEG",
        "GRAPHIC_PNG"
      },
      imageResolution =
      {
        resolutionWidth = width or 64,
        resolutionHeight = height or 64
      }
    }

  end

  ExpectRequest("UI.GetCapabilities", true, {
      displayCapabilities =
      {
        displayType = "GEN2_8_DMA",
        textFields =
        {
          text_field("mainField1"),
          text_field("mainField2"),
          text_field("mainField3"),
          text_field("mainField4"),
          text_field("statusBar"),
          text_field("mediaClock"),
          text_field("mediaTrack"),
          text_field("alertText1"),
          text_field("alertText2"),
          text_field("alertText3"),
          text_field("scrollableMessageBody"),
          text_field("initialInteractionText"),
          text_field("navigationText1"),
          text_field("navigationText2"),
          text_field("ETA"),
          text_field("totalDistance"),
          text_field("navigationText"),
          text_field("audioPassThruDisplayText1"),
          text_field("audioPassThruDisplayText2"),
          text_field("sliderHeader"),
          text_field("sliderFooter"),
          text_field("notificationText"),
          text_field("menuName"),
          text_field("secondaryText"),
          text_field("tertiaryText"),
          text_field("timeToDestination"),
          text_field("turnText"),
          text_field("menuTitle"),
          text_field("locationName"),
          text_field("locationDescription"),
          text_field("addressLines"),
          text_field("phoneNumber")
        },
        imageFields =
        {
          image_field("softButtonImage"),
          image_field("choiceImage"),
          image_field("choiceSecondaryImage"),
          image_field("vrHelpItem"),
          image_field("turnIcon"),
          image_field("menuIcon"),
          image_field("cmdIcon"),
          image_field("showConstantTBTIcon"),
          image_field("locationImage")
        },
        mediaClockFormats =
        {
          "CLOCK1",
          "CLOCK2",
          "CLOCK3",
          "CLOCKTEXT1",
          "CLOCKTEXT2",
          "CLOCKTEXT3",
          "CLOCKTEXT4"
        },
        graphicSupported = true,
        imageCapabilities = { "DYNAMIC", "STATIC" },
        templatesAvailable = { "TEMPLATE" },
        screenParams =
        {
          resolution = { resolutionWidth = 800, resolutionHeight = 480 },
          touchEventAvailable =
          {
            pressAvailable = true,
            multiTouchAvailable = true,
            doublePressAvailable = false
          }
        },
        numCustomPresetsAvailable = 10
      },
      audioPassThruCapabilities =
      {
        samplingRate = "44KHZ",
        bitsPerSample = "8_BIT",
        audioType = "PCM"
      },
      hmiZoneCapabilities = "FRONT",
      softButtonCapabilities =
      {
        {
          shortPressAvailable = true,
          longPressAvailable = true,
          upDownAvailable = true,
          imageSupported = true
        }
      }
    })

  local function getClimateControlCapabilities()
    return {
      {
        moduleName = "Climate",
        fanSpeedAvailable = true,
        desiredTemperatureAvailable = true,
        acEnableAvailable = true,
        acMaxEnableAvailable = true,
        circulateAirEnableAvailable = true,
        autoModeEnableAvailable = true,
        dualModeEnableAvailable = true,
        defrostZoneAvailable = true,
        defrostZone = {
          "FRONT", "REAR", "ALL", "NONE"
        },
        ventilationModeAvailable = true,
        ventilationMode = {
          "UPPER", "LOWER", "BOTH", "NONE"
        }
      }
    }
  end

  local function getRadioControlCapabilities()
    return {
      {
        moduleName = "Radio",
        radioEnableAvailable = true,
        radioBandAvailable = true,
        radioFrequencyAvailable = true,
        hdChannelAvailable = true,
        rdsDataAvailable = true,
        availableHDsAvailable = true,
        stateAvailable = true,
        signalStrengthAvailable = true,
        signalChangeThresholdAvailable = true
      }
    }
  end

  local function getButtonCapabilities()
    local buttons = {
      -- climate
      "AC_MAX", "AC", "RECIRCULATE", "FAN_UP", "FAN_DOWN", "TEMP_UP", "TEMP_DOWN", "DEFROST_MAX", "DEFROST", "DEFROST_REAR", "UPPER_VENT", "LOWER_VENT",
      -- radio
      "VOLUME_UP", "VOLUME_DOWN", "EJECT", "SOURCE", "SHUFFLE", "REPEAT"
    }
    local out = { }
    for _, button in pairs(buttons) do
      table.insert(out, { name = button, shortPressAvailable = true, longPressAvailable = true, upDownAvailable = true })
    end
    return out
  end

  ExpectRequest("RC.GetCapabilities", true, {
      remoteControlCapability = {
        climateControlCapabilities = getClimateControlCapabilities(),
        radioControlCapabilities = getRadioControlCapabilities(),
        buttonCapabilities = getButtonCapabilities()
      }
    })

  ExpectRequest("VR.IsReady", true, { available = true })
  ExpectRequest("TTS.IsReady", true, { available = true })
  ExpectRequest("UI.IsReady", true, { available = true })
  ExpectRequest("Navigation.IsReady", true, { available = true })
  ExpectRequest("VehicleInfo.IsReady", true, { available = true })
  ExpectRequest("RC.IsReady", true, { available = true })

  self.applications = { }
  ExpectRequest("BasicCommunication.UpdateAppList", false, { })
  :Pin()
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
      self.applications = { }
      for _, app in pairs(data.params.applications) do
        self.applications[app.appName] = app.appID
      end
    end)
  self.hmiConnection:SendNotification("BasicCommunication.OnReady")
  return exp_waiter.expectation
end

local function getPTUFromPTS(tbl)
  tbl.policy_table.consumer_friendly_messages.messages = nil
  tbl.policy_table.device_data = nil
  tbl.policy_table.module_meta = nil
  tbl.policy_table.usage_and_error_counts = nil
  tbl.policy_table.functional_groupings["DataConsent-2"].rpcs = json.null
  tbl.policy_table.module_config.preloaded_pt = nil
  tbl.policy_table.module_config.preloaded_date = nil
end

function commonRC.getRCAppConfig()
  return {
    keep_context = false,
    steal_focus = false,
    priority = "NONE",
    default_hmi = "NONE",
    moduleType = { "RADIO", "CLIMATE" },
    groups = { "Base-4" },
    groups_primaryRC = { "Base-4", "RemoteControl" },
    AppHMIType = { "REMOTE_CONTROL" }
  }
end

local function updatePTU(tbl)
  tbl.policy_table.app_policies[config.application1.registerAppInterfaceParams.appID] = commonRC.getRCAppConfig()
  tbl.policy_table.functional_groupings["RemoteControl"].rpcs.OnInteriorVehicleData = {
    hmi_levels = { "BACKGROUND", "FULL", "LIMITED", "NONE" }
  }
end

local function jsonFileToTable(file_name)
  local f = io.open(file_name, "r")
  local content = f:read("*all")
  f:close()
  return json.decode(content)
end

local function tableToJsonFile(tbl, file_name)
  local f = io.open(file_name, "w")
  f:write(json.encode(tbl))
  f:close()
end

local function checkIfPTSIsSentAsBinary(bin_data)
  if not (bin_data ~= nil and string.len(bin_data) > 0) then
    commonFunctions:userPrint(31, "PTS was not sent to Mobile in payload of OnSystemRequest")
  end
end

local function ptu(self, ptu_update_func)
  local policy_file_name = "PolicyTableUpdate"
  local policy_file_path = commonFunctions:read_parameter_from_smart_device_link_ini("SystemFilesPath")
  local pts_file_name = commonFunctions:read_parameter_from_smart_device_link_ini("PathToSnapshot")
  local ptu_file_name = os.tmpname()
  local requestId = self.hmiConnection:SendRequest("SDL.GetURLS", { service = 7 })
  EXPECT_HMIRESPONSE(requestId)
  :Do(function()
      self.hmiConnection:SendNotification("BasicCommunication.OnSystemRequest", { requestType = "PROPRIETARY", fileName = pts_file_name })
      getPTUFromPTS(ptu_table)
      updatePTU(ptu_table)
      if ptu_update_func then
        ptu_update_func(ptu_table)
      end
      tableToJsonFile(ptu_table, ptu_file_name)
      self.mobileSession:ExpectNotification("OnSystemRequest", { requestType = "PROPRIETARY" })
      :Do(function(_, d2)
          checkIfPTSIsSentAsBinary(d2.binaryData)
          local corIdSystemRequest = self.mobileSession:SendRPC("SystemRequest", { requestType = "PROPRIETARY", fileName = policy_file_name }, ptu_file_name)
          EXPECT_HMICALL("BasicCommunication.SystemRequest")
          :Do(function(_, d3)
              self.hmiConnection:SendResponse(d3.id, "BasicCommunication.SystemRequest", "SUCCESS", { })
              self.hmiConnection:SendNotification("SDL.OnReceivedPolicyUpdate", { policyfile = policy_file_path .. "/" .. policy_file_name })
            end)
          self.mobileSession:ExpectResponse(corIdSystemRequest, { success = true, resultCode = "SUCCESS" })
        end)
    end)
  os.remove(ptu_file_name)
end

function commonRC.preconditions()
  commonFunctions:SDLForceStop()
  commonSteps:DeletePolicyTable()
  commonSteps:DeleteLogsFiles()
end

function commonRC.start(self)
  self:runSDL()
  commonFunctions:waitForSDLStart(self)
  :Do(function()
      initHMI(self)
      :Do(function()
          commonFunctions:userPrint(35, "HMI initialized")
          self:initHMI_onReady()
          :Do(function()
              commonFunctions:userPrint(35, "HMI is ready")
              self:connectMobile()
              :Do(function()
                  commonFunctions:userPrint(35, "Mobile connected")
                  self.mobileSession = mobile_session.MobileSession(self, self.mobileConnection)
                  self.mobileSession:StartService(7)
                  :Do(function()
                      commonFunctions:userPrint(35, "Session started")
                    end)
                end)
            end)
        end)
    end)
end

function commonRC.rai_ptu(ptu_update_func, self)
  self, ptu_update_func = commonRC.getSelfAndParams(ptu_update_func, self)

  local corId = self.mobileSession:SendRPC("RegisterAppInterface", config.application1.registerAppInterfaceParams)
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config.application1.registerAppInterfaceParams.appName } })
  :Do(function(_, d1)
      hmiAppIds[config.application1.registerAppInterfaceParams.appID] = d1.params.application.appID
      EXPECT_HMINOTIFICATION("SDL.OnStatusUpdate", { status = "UPDATE_NEEDED" }, { status = "UPDATING" }, { status = "UP_TO_DATE" })
      :Times(3)
      EXPECT_HMICALL("BasicCommunication.PolicyUpdate")
      :Do(function(_, d2)
          self.hmiConnection:SendResponse(d2.id, d2.method, "SUCCESS", { })
          ptu_table = jsonFileToTable(d2.params.file)
          ptu(self, ptu_update_func)
        end)
    end)
  self.mobileSession:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
  :Do(function()
      self.mobileSession:ExpectNotification("OnHMIStatus", { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
      :Times(AtLeast(1)) -- issue with SDL --> notification is sent twice
      self.mobileSession:ExpectNotification("OnPermissionsChange")
    end)
end

function commonRC.rai_n(id, self)
  self["mobileSession" .. id] = mobile_session.MobileSession(self, self.mobileConnection)
  self["mobileSession" .. id]:StartService(7)
  :Do(function()
      local corId = self["mobileSession" .. id]:SendRPC("RegisterAppInterface", config["application" .. id].registerAppInterfaceParams)
      EXPECT_HMINOTIFICATION("BasicCommunication.OnAppRegistered", { application = { appName = config["application" .. id].registerAppInterfaceParams.appName } })
      :Do(function(_, d1)
          hmiAppIds[config["application" .. id].registerAppInterfaceParams.appID] = d1.params.application.appID
        end)
      self["mobileSession" .. id]:ExpectResponse(corId, { success = true, resultCode = "SUCCESS" })
      :Do(function()
          self["mobileSession" .. id]:ExpectNotification("OnHMIStatus", { hmiLevel = "NONE", audioStreamingState = "NOT_AUDIBLE", systemContext = "MAIN" })
          :Times(AtLeast(1)) -- issue with SDL --> notification is sent twice
          self["mobileSession" .. id]:ExpectNotification("OnPermissionsChange")
        end)
    end)
end

function commonRC.unregisterApp(pAppId, self)
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local hmiAppId = commonRC.getHMIAppId(self, pAppId)
  local cid = mobSession:SendRPC("UnregisterAppInterface",{})
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered", { appID = hmiAppId, unexpectedDisconnect = false })
  mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS"})
end

function commonRC.activate_app(pAppId, self)
  self, pAppId = commonRC.getSelfAndParams(pAppId, self)

  local pHMIAppId = hmiAppIds[config.application1.registerAppInterfaceParams.appID]
  local mobSession = self["mobileSession"]
  if pAppId and pAppId > 1 then
    mobSession = self["mobileSession" .. pAppId]
    pHMIAppId = hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
  end
  local requestId1 = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = pHMIAppId })
  EXPECT_HMIRESPONSE(requestId1)
  :Do(function(_, data1)
      if data1.result.isSDLAllowed ~= true then
        local requestId2 = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage",
          { language = "EN-US", messageCodes = { "DataConsent" } })
        EXPECT_HMIRESPONSE(requestId2)
        :Do(function()
            self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality",
              { allowed = true, source = "GUI", device = { id = config.deviceMAC, name = "127.0.0.1" } })
            EXPECT_HMICALL("BasicCommunication.ActivateApp")
            :Do(function(_, data2)
                self.hmiConnection:SendResponse(data2.id,"BasicCommunication.ActivateApp", "SUCCESS", { })
              end)
          end)
      end
    end)
  mobSession:ExpectNotification("OnHMIStatus", { hmiLevel = "FULL", audioStreamingState = "AUDIBLE", systemContext = "MAIN" })
end

function commonRC.postconditions()
  StopSDL()
end

function commonRC.getSelfAndParams(param, self)
  if not self then
    return param, nil
  end
  return self, param
end

function commonRC.getModuleControlData(module_type)
  local out = { moduleType = module_type }
  if module_type == "CLIMATE" then
    out.climateControlData = {
      fanSpeed = 50,
      currentTemperature = {
        unit = "FAHRENHEIT",
        value = 20.1
      },
      desiredTemperature = {
        unit = "CELSIUS",
        value = 10.5
      },
      acEnable = true,
      circulateAirEnable = true,
      autoModeEnable = true,
      defrostZone = "FRONT",
      dualModeEnable = true,
      acMaxEnable = true,
      ventilationMode = "BOTH"
    }
  elseif module_type == "RADIO" then
    out.radioControlData = {
      frequencyInteger = 1,
      frequencyFraction = 2,
      band = "AM",
      rdsData = {
        PS = "ps",
        RT = "rt",
        CT = "123456789012345678901234",
        PI = "pi",
        PTY = 1,
        TP = false,
        TA = true,
        REG = "US"
      },
      availableHDs = 1,
      hdChannel = 1,
      signalStrength = 5,
      signalChangeThreshold = 10,
      radioEnable = true,
      state = "ACQUIRING"
    }
  end
  return out
end

function commonRC.getAnotherModuleControlData(module_type)
  local out = { moduleType = module_type }
  if module_type == "CLIMATE" then
    out.climateControlData = {
      fanSpeed = 65,
      currentTemperature = {
        unit = "FAHRENHEIT",
        value = 44.3
      },
      desiredTemperature = {
        unit = "CELSIUS",
        value = 22.6
      },
      acEnable = false,
      circulateAirEnable = false,
      autoModeEnable = true,
      defrostZone = "ALL",
      dualModeEnable = true,
      acMaxEnable = false,
      ventilationMode = "UPPER"
    }
  elseif module_type == "RADIO" then
    out.radioControlData = {
      frequencyInteger = 1,
      frequencyFraction = 2,
      band = "AM",
      rdsData = {
        PS = "ps",
        RT = "rt",
        CT = "123456789012345678901234",
        PI = "pi",
        PTY = 2,
        TP = false,
        TA = true,
        REG = "US"
      },
      availableHDs = 1,
      hdChannel = 1,
      signalStrength = 5,
      signalChangeThreshold = 20,
      radioEnable = true,
      state = "ACQUIRING"
    }
  end
  return out
end

function commonRC.getButtonNameByModule(pModuleType)
  if pModuleType == "CLIMATE" then
    return "FAN_UP"
  elseif pModuleType == "RADIO" then
    return "VOLUME_UP"
  end
end

function commonRC.getReadOnlyParamsByModule(pModuleType)
  local out = { moduleType = pModuleType }
  if pModuleType == "CLIMATE" then
    out.climateControlData = {
      currentTemperature = {
        unit = "FAHRENHEIT",
        value = 32.6
      }
    }
  elseif pModuleType == "RADIO" then
    out.radioControlData = {
      rdsData = {
        PS = "ps",
        RT = "rt",
        CT = "123456789012345678901234",
        PI = "pi",
        PTY = 2,
        TP = false,
        TA = true,
        REG = "US"
      },
      availableHDs = 2,
      signalStrength = 4,
      signalChangeThreshold = 22,
      state = "MULTICAST"
    }
  end
  return out
end

function commonRC.getModuleParams(pModuleData)
  if pModuleData.moduleType == "CLIMATE" then
    if not pModuleData.climateControlData then
      pModuleData.climateControlData = { }
    end
    return pModuleData.climateControlData
  elseif pModuleData.moduleType == "RADIO" then
    if not pModuleData.radioControlData then
      pModuleData.radioControlData = { }
    end
    return pModuleData.radioControlData
  end
end

function commonRC.getSettableModuleControlData(pModuleType)
  local out = commonRC.getModuleControlData(pModuleType)
  local params_read_only = commonRC.getModuleParams(commonRC.getReadOnlyParamsByModule(pModuleType))
  for p_read_only in pairs(params_read_only) do
    commonRC.getModuleParams(out)[p_read_only] = nil
  end
  return out
end

-- RC RPCs structure
local rcRPCs = {
  GetInteriorVehicleData = {
    appEventName = "GetInteriorVehicleData",
    hmiEventName = "RC.GetInteriorVehicleData",
    requestParams = function(pModuleType, pSubscribe)
      return {
        moduleType = pModuleType,
        subscribe = pSubscribe
      }
    end,
    hmiRequestParams = function(pModuleType, pAppId, pSubscribe, self)
      return {
        appID = commonRC.getHMIAppId(self, pAppId),
        moduleType = pModuleType,
        subscribe = pSubscribe
      }
    end,
    hmiResponseParams = function(pModuleType, pSubscribe)
      return {
        moduleData = commonRC.getModuleControlData(pModuleType),
        isSubscribed = pSubscribe
      }
    end,
    responseParams = function(success, resultCode, pModuleType, pSubscribe)
      return {
        success = success,
        resultCode = resultCode,
        moduleData = commonRC.getModuleControlData(pModuleType),
        isSubscribed = pSubscribe
      }
    end
  },
  SetInteriorVehicleData = {
    appEventName = "SetInteriorVehicleData",
    hmiEventName = "RC.SetInteriorVehicleData",
    requestParams = function(pModuleType)
      return {
        moduleData = commonRC.getSettableModuleControlData(pModuleType)
      }
    end,
    hmiRequestParams = function(pModuleType, pAppId, self)
      return {
        appID = commonRC.getHMIAppId(self, pAppId),
        moduleData = commonRC.getSettableModuleControlData(pModuleType)
      }
    end,
    hmiResponseParams = function(pModuleType)
      return {
        moduleData = commonRC.getSettableModuleControlData(pModuleType)
      }
    end
  },
  ButtonPress = {
    appEventName = "ButtonPress",
    hmiEventName = "Buttons.ButtonPress",
    requestParams = function(pModuleType)
      return {
        moduleType = pModuleType,
        buttonName = commonRC.getButtonNameByModule(pModuleType),
        buttonPressMode = "SHORT"
      }
    end,
    hmiRequestParams = function(pModuleType, pAppId, self)
      return {
        appID = commonRC.getHMIAppId(self, pAppId),
        moduleType = pModuleType,
        buttonName = commonRC.getButtonNameByModule(pModuleType),
        buttonPressMode = "SHORT"
      }
    end,
    hmiResponseParams = function()
      return {}
    end
  },
  GetInteriorVehicleDataConsent = {
    hmiEventName = "RC.GetInteriorVehicleDataConsent",
    hmiRequestParams = function(pModuleType, pAppId, self)
      return {
        appID = commonRC.getHMIAppId(self, pAppId),
        moduleType = pModuleType
      }
    end,
    hmiResponseParams = function(pAllowed)
      return {
        allowed = pAllowed
      }
    end,
  },
  OnInteriorVehicleData = {
    appEventName = "OnInteriorVehicleData",
    hmiEventName = "RC.OnInteriorVehicleData",
    hmiResponseParams = function(pModuleType)
      return {
        moduleData = commonRC.getAnotherModuleControlData(pModuleType)
      }
    end,
    responseParams = function(pModuleType)
      return {
        moduleData = commonRC.getAnotherModuleControlData(pModuleType)
      }
    end
  },
  OnRemoteControlSettings = {
    hmiEventName = "RC.OnRemoteControlSettings",
    hmiResponseParams = function(pAllowed, pAccessMode)
      return {
        allowed = pAllowed,
        accessMode = pAccessMode
      }
    end
  }
}

function commonRC.getAppEventName(pRPC)
  return rcRPCs[pRPC].appEventName
end

function commonRC.getHMIEventName(pRPC)
  return rcRPCs[pRPC].hmiEventName
end

function commonRC.getAppRequestParams(pRPC, ...)
  return rcRPCs[pRPC].requestParams(...)
end

function commonRC.getAppResponseParams(pRPC, ...)
  return rcRPCs[pRPC].responseParams(...)
end

function commonRC.getHMIRequestParams(pRPC, ...)
  return rcRPCs[pRPC].hmiRequestParams(...)
end

function commonRC.getHMIResponseParams(pRPC, ...)
  return rcRPCs[pRPC].hmiResponseParams(...)
end

function commonRC.subscribeToModule(pModuleType, pAppId, self)
  self, pAppId = commonRC.getSelfAndParams(pAppId, self)
  local rpc = "GetInteriorVehicleData"
  local subscribe = true
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local cid = mobSession:SendRPC(commonRC.getAppEventName(rpc), commonRC.getAppRequestParams(rpc, pModuleType, subscribe))
  EXPECT_HMICALL(commonRC.getHMIEventName(rpc), commonRC.getHMIRequestParams(rpc, pModuleType, pAppId, subscribe, self))
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", commonRC.getHMIResponseParams(rpc, pModuleType, subscribe))
    end)
  mobSession:ExpectResponse(cid, commonRC.getAppResponseParams(rpc, true, "SUCCESS", pModuleType, subscribe))
end

function commonRC.unSubscribeToModule(pModuleType, pAppId, self)
  self, pAppId = commonRC.getSelfAndParams(pAppId, self)
  local rpc = "GetInteriorVehicleData"
  local subscribe = false
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local cid = mobSession:SendRPC(commonRC.getAppEventName(rpc), commonRC.getAppRequestParams(rpc, pModuleType, subscribe))
  EXPECT_HMICALL(commonRC.getHMIEventName(rpc), commonRC.getHMIRequestParams(rpc, pModuleType, pAppId, subscribe, self))
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", commonRC.getHMIResponseParams(rpc, pModuleType, subscribe))
    end)
  mobSession:ExpectResponse(cid, commonRC.getAppResponseParams(rpc, true, "SUCCESS", pModuleType, subscribe))
end

function commonRC.isSubscribed(pModuleType, pAppId, self)
  self, pAppId = commonRC.getSelfAndParams(pAppId, self)
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local rpc = "OnInteriorVehicleData"
  self.hmiConnection:SendNotification(commonRC.getHMIEventName(rpc), commonRC.getHMIResponseParams(rpc, pModuleType))
  mobSession:ExpectNotification(commonRC.getAppEventName(rpc), commonRC.getAppResponseParams(rpc, pModuleType))
end

function commonRC.isUnsubscribed(pModuleType, pAppId, self)
  self, pAppId = commonRC.getSelfAndParams(pAppId, self)
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local rpc = "OnInteriorVehicleData"
  self.hmiConnection:SendNotification(commonRC.getHMIEventName(rpc), commonRC.getHMIResponseParams(rpc, pModuleType))
  mobSession:ExpectNotification(commonRC.getAppEventName(rpc), {}):Times(0)
  commonTestCases:DelayedExp(commonRC.timeout)
end

function commonRC.getHMIAppId(self, pAppId)
  if not pAppId then
    pAppId = 1
  end
  return hmiAppIds[config["application" .. pAppId].registerAppInterfaceParams.appID]
end

function commonRC.getMobileSession(self, pAppId)
  if pAppId and pAppId > 1 then
    return self["mobileSession" .. pAppId]
  end
  return self["mobileSession"]
end

function commonRC.defineRAMode(pAllowed, pAccessMode, self)
  self, pAccessMode = commonRC.getSelfAndParams(pAccessMode, self)
  local rpc = "OnRemoteControlSettings"
  self.hmiConnection:SendNotification(commonRC.getHMIEventName(rpc), commonRC.getHMIResponseParams(rpc, pAllowed, pAccessMode))
end

function commonRC.rpcDenied(pModuleType, pAppId, pRPC, pResultCode, self)
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local cid = mobSession:SendRPC(commonRC.getAppEventName(pRPC), commonRC.getAppRequestParams(pRPC, pModuleType))
  EXPECT_HMICALL(commonRC.getHMIEventName(pRPC), {}):Times(0)
  mobSession:ExpectResponse(cid, { success = false, resultCode = pResultCode })
  commonTestCases:DelayedExp(commonRC.timeout)
end

function commonRC.rpcAllowed(pModuleType, pAppId, pRPC, self)
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local cid = mobSession:SendRPC(commonRC.getAppEventName(pRPC), commonRC.getAppRequestParams(pRPC, pModuleType))
  EXPECT_HMICALL(commonRC.getHMIEventName(pRPC), commonRC.getHMIRequestParams(pRPC, pModuleType, pAppId, self))
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", commonRC.getHMIResponseParams(pRPC, pModuleType))
    end)
  mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

function commonRC.rpcAllowedWithConsent(pModuleType, pAppId, pRPC, self)
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local cid = mobSession:SendRPC(commonRC.getAppEventName(pRPC), commonRC.getAppRequestParams(pRPC, pModuleType))
  local consentRPC = "GetInteriorVehicleDataConsent"
  EXPECT_HMICALL(commonRC.getHMIEventName(consentRPC), commonRC.getHMIRequestParams(consentRPC, pModuleType, pAppId, self))
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", commonRC.getHMIResponseParams(consentRPC, true))
      EXPECT_HMICALL(commonRC.getHMIEventName(pRPC), commonRC.getHMIRequestParams(pRPC, pModuleType, pAppId, self))
      :Do(function(_, data2)
          self.hmiConnection:SendResponse(data2.id, data2.method, "SUCCESS", commonRC.getHMIResponseParams(pRPC, pModuleType))
        end)
    end)
  mobSession:ExpectResponse(cid, { success = true, resultCode = "SUCCESS" })
end

function commonRC.rpcRejectWithConsent(pModuleType, pAppId, pRPC, self)
  local info = "The resource is in use and the driver disallows this remote control RPC"
  local consentRPC = "GetInteriorVehicleDataConsent"
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local cid = mobSession:SendRPC(commonRC.getAppEventName(pRPC), commonRC.getAppRequestParams(pRPC, pModuleType))
  EXPECT_HMICALL(commonRC.getHMIEventName(consentRPC), commonRC.getHMIRequestParams(consentRPC, pModuleType, pAppId, self))
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", commonRC.getHMIResponseParams(consentRPC, false))
      EXPECT_HMICALL(commonRC.getHMIEventName(pRPC)):Times(0)
    end)
  mobSession:ExpectResponse(cid, { success = false, resultCode = "REJECTED", info = info })
  commonTestCases:DelayedExp(commonRC.timeout)
end

function commonRC.rpcRejectWithoutConsent(pModuleType, pAppId, pRPC, self)
  local mobSession = commonRC.getMobileSession(self, pAppId)
  local cid = mobSession:SendRPC(commonRC.getAppEventName(pRPC), commonRC.getAppRequestParams(pRPC, pModuleType))
  EXPECT_HMICALL(commonRC.getHMIEventName("GetInteriorVehicleDataConsent")):Times(0)
  EXPECT_HMICALL(commonRC.getHMIEventName(pRPC)):Times(0)
  mobSession:ExpectResponse(cid, { success = false, resultCode = "REJECTED" })
  commonTestCases:DelayedExp(commonRC.timeout)
end

return commonRC
