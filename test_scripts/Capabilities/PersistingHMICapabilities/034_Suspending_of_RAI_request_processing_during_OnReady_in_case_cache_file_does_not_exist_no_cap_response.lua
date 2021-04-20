---------------------------------------------------------------------------------------------------
-- Proposal:https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0249-Persisting-HMI-Capabilities-specific-to-headunit.md
--
-- Check that SDL suspends of RAI request processing from mobile app in case mobile device connected during OnReady
--  communication, HMI does not send all HMI Capabilities
--  (VR/TTS/RC/UI/Buttons.GetCapabilities/,VR/TTS/UI.GetSupportedLanguages/GetLanguage, VehicleInfo.GetVehicleType)
--  response due to timeout. HMI capabilities cache file (hmi_capabilities_cache.json) doesn't exist
--  on file system and ccpu_version matches with received ccpu_version from HMI
--
-- Preconditions:
-- 1  Value of HMICapabilitiesCacheFile parameter is defined (hmi_capabilities_cache.json) in smartDeviceLink.ini file
-- 2. HMI capabilities cache file doesn't exist on file system
-- 3. SDL and HMI are started
-- 4. Local ccpu_version matches with received ccpu_version from HMI
-- Sequence:
-- 1. Mobile is connected just after HMI sends OnReady notification to SDL.
-- Mobile sends RegisterAppInterface request to SDL
--  a. SDL suspends of RAI request processing from mobile
-- 2. HMI does not sends all HMI capabilities (VR/TTS/RC/UI etc) to SDL
--  a. SDL sends RegisterAppInterface response with corresponding capabilities (stored in hmi_capabilities_cache.json)
--   to Mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Capabilities/PersistingHMICapabilities/common')

--[[ Local Variables ]]
local appSessionId = 1
local ccpuVersion = "cppu_version_1"
local delayRaiResponse = 10000
local hmiCapabilities = common.getHMICapabilitiesFromFile()

--[[ Local Functions ]]
local capRaiResponse = {
  buttonCapabilities = hmiCapabilities.Buttons.capabilities,
  vehicleType = hmiCapabilities.VehicleInfo.vehicleType,
  audioPassThruCapabilities = hmiCapabilities.UI.audioPassThruCapabilities,
  hmiDisplayLanguage =  hmiCapabilities.UI.language,
  language = hmiCapabilities.VR.language, -- or TTS.language
  pcmStreamCapabilities = hmiCapabilities.UI.pcmStreamCapabilities,
  hmiZoneCapabilities = { hmiCapabilities.UI.hmiZoneCapabilities },
  softButtonCapabilities = hmiCapabilities.UI.softButtonCapabilities,
  displayCapabilities = common.buildDisplayCapForMobileExp(hmiCapabilities.UI.displayCapabilities),
  vrCapabilities = hmiCapabilities.VR.vrCapabilities,
  speechCapabilities = hmiCapabilities.TTS.speechCapabilities,
  prerecordedSpeech = hmiCapabilities.TTS.prerecordedSpeechCapabilities
}

local function getHMIParamsWithOutResponse(pVersion)
  local hmiValues = common.getHMIParamsWithOutResponse()
  hmiValues.BasicCommunication.GetSystemInfo = {
    params = {
      ccpu_version = pVersion,
      language = "EN-US",
      wersCountryCode = "wersCountryCode"
    }
  }
  return hmiValues
end

--[[ Scenario ]]
common.Title("Preconditions")
common.Step("Clean environment", common.preconditions)
common.Step("Update HMI capabilities", common.updateHMICapabilitiesFile, { true })
common.Step("Start SDL, HMI, connect mobile", common.start, { getHMIParamsWithOutResponse(ccpuVersion) })
common.Step("Check that capabilities file doesn't exist", common.checkIfCapabilityCacheFileExists, { false })
common.Step("Ignition off", common.ignitionOff)

common.Title("Test")
common.Step("Start SDL, HMI", common.startWoBothHMIonReadyAndMobile)
common.Step("Connect mobile and check suspending App registration", common.connectMobileAndRegisterAppSuspend,
  { appSessionId, capRaiResponse, getHMIParamsWithOutResponse(ccpuVersion), delayRaiResponse })

common.Title("Postconditions")
common.Step("Stop SDL", common.postconditions)
