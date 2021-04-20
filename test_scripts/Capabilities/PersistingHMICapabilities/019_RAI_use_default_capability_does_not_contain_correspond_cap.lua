---------------------------------------------------------------------------------------------------
-- Proposal:https://github.com/smartdevicelink/sdl_evolution/blob/master/proposals/0249-Persisting-HMI-Capabilities-specific-to-headunit.md
--
-- Description: Check that the SDL use default capabilities from hmi_capabilities.json in case
-- HMI does not send one of GetCapabilities/GetLanguage/GetVehicleType response due to timeout

-- Preconditions:
-- 1  Value of HMICapabilitiesCacheFile parameter is defined (hmi_capabilities_cache.json) in smartDeviceLink.ini file
-- 2. HMI capabilities cache file (hmi_capabilities_cache.json) doesn't exist on file system
-- 3. SDL and HMI are started
-- 4. HMI does not provide one of HMI capabilities (VR/TTS/RC/UI etc)
-- 5. App is registered
-- Sequence:
-- 1. Mobile sends RegisterAppInterface request to SDL
--  a. SDL sends RegisterAppInterface response with correspond capabilities (stored in hmi_capabilities.json) to Mobile
---------------------------------------------------------------------------------------------------
--[[ Required Shared libraries ]]
local common = require('test_scripts/Capabilities/PersistingHMICapabilities/common')
config.application1.registerAppInterfaceParams.appHMIType = { "REMOTE_CONTROL" }

--[[ Local Variables ]]
local appSessionId = 1
local hmiDefaultCap = common.getDefaultHMITable()
local hmiCapabilities = common.updateHMICapabilitiesTable()

local requests = {
  UI = { "GetCapabilities" },
  VR = { "GetCapabilities" },
  TTS = { "GetCapabilities" },
  Buttons = { "GetCapabilities" },
  VehicleInfo = { "GetVehicleType" }
}

--[[ Local Functions ]]
local function updateHMICaps(pMod, pRequest)
  hmiDefaultCap[pMod][pRequest] = nil
  for mod, _ in pairs (hmiDefaultCap) do
    if not mod == "Buttons" then
      hmiDefaultCap[mod].IsReady.params.available = true
    end
  end
end

local function buildCapRaiResponse(pMod, pReq)
  local capRaiResponse = {
    UI = {
      GetCapabilities = {
        audioPassThruCapabilities = hmiCapabilities.UI.audioPassThruCapabilities,
        pcmStreamCapabilities = hmiCapabilities.UI.pcmStreamCapabilities,
        hmiZoneCapabilities = { hmiCapabilities.UI.hmiZoneCapabilities },
        softButtonCapabilities = hmiCapabilities.UI.softButtonCapabilities,
        displayCapabilities = common.buildDisplayCapForMobileExp(hmiCapabilities.UI.displayCapabilities),
      },
      GetLanguage = {
        hmiDisplayLanguage =  hmiCapabilities.UI.language }},
    VR = {
      GetCapabilities = {
        vrCapabilities = hmiCapabilities.VR.vrCapabilities },
      GetLanguage = {
        language = hmiCapabilities.VR.language }},
    TTS = {
      GetCapabilities = {
        speechCapabilities = hmiCapabilities.TTS.speechCapabilities,
        prerecordedSpeech = hmiCapabilities.TTS.prerecordedSpeechCapabilities },
      GetLanguage = {
        language = hmiCapabilities.TTS.language }},
    Buttons = {
      GetCapabilities = {
        buttonCapabilities = hmiCapabilities.Buttons.capabilities }},
    VehicleInfo = {
      GetVehicleType  = {
        vehicleType = hmiCapabilities.VehicleInfo.vehicleType }}
    }
  return capRaiResponse[pMod][pReq]
end

--[[ Scenario ]]
for mod, request  in pairs(requests) do
  for _, req  in ipairs(request) do
    common.Title("Preconditions")
    common.Title("TC processing " .. tostring(mod) .. " " .. tostring(req) .. "]")
    common.Step("Clean environment", common.preconditions)
    common.Step("Update HMI capabilities", common.updateHMICapabilitiesFile)
    common.Step("HMI does not response on " .. mod .. "." .. req, updateHMICaps, { mod, req })

    common.Title("Test")
    common.Step("Ignition on, Start SDL, HMI", common.start, { hmiDefaultCap })
    common.Step("App registration", common.postponedRegisterApp, { appSessionId, buildCapRaiResponse(mod, req) })

    common.Title("Postconditions")
    common.Step("Stop SDL", common.postconditions)
  end
end
