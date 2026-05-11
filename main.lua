--[[
  @name: Google Gemini text to audio generator
  @author: Abdul Rauf Amir
  @version: 1.4
  @description: Advanced TTS with Emotions - Direct Save to Downloads & Auto Update
]]

require "import"
import "com.androlua.Http"
import "cjson"
import "com.androlua.LuaDialog"
import "android.widget.*"
import "android.view.*"
import "android.content.Context"
import "android.content.Intent"
import "android.net.Uri"
import "android.media.MediaPlayer"
import "android.util.Base64"
import "android.os.*"
import "android.graphics.Typeface"
import "java.io.*"
import "android.text.InputFilter"

local context = activity or service
local mainHandler = Handler(Looper.getMainLooper())
local CHAR_LIMIT = 10000

-- [Update Settings]
local CURRENT_VERSION = "1.4"
local VERSION_URL = "https://raw.githubusercontent.com/abdulraufamir559-prog/best-tool-/main/version.txt"
local UPDATE_CODE_URL = "https://raw.githubusercontent.com/abdulraufamir559-prog/best-tool-/main/main.lua"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/Text to audio generator developed by Abdul Rauf/main.lua"
local updateInProgress = false

local VOICE_LIST = {"Puck", "Kore", "Charon", "Zephyr", "Fenrir", "Leda", "Orus", "Aoede", "Callirrhoe", "Autonoe", "Enceladus", "Iapetus", "Umbriel", "Algieba", "Despina", "Erinome", "Algenib", "Rasalgethi", "Laomedeia", "Achernar", "Alnilam", "Schedar", "Gacrux", "Pulcherrima"}
local EMOTIONS = {"Natural/Neutral", "Very Happy & Energetic", "Sad & Emotional", "Angry & Loud", "Serious & Professional", "Whispering/Secretive", "Excited/Cheer", "Surprised/Shocked", "Tired/Sleepy", "Shy/Romantic", "Heroic/Epic", "Sarcastic/Funny", "Mysterious/Dark"}

local googleApiKey = ""
local generatedAudioPath = nil
local mediaPlayer = nil
local mainDlg = nil

local PREFS_NAME = "Gemini_TTS_Abdul_Rauf"
local prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

-- [Helper Functions]
function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end
function loadSettings() googleApiKey = prefs.getString("apikey", "") end
function saveSettings() local editor = prefs.edit(); editor.putString("apikey", googleApiKey); editor.apply() end

-- [Update Logic]
function checkUpdate()
    if updateInProgress then return end
    local timestamp = tostring(os.time())
    Http.get(VERSION_URL .. "?t=" .. timestamp, function(code, response)
        if code == 200 and response then
            local onlineVersion = trim(response)
            if onlineVersion ~= CURRENT_VERSION then
                mainHandler.post(Runnable({
                    run = function()
                        local updateDlg = LuaDialog(context)
                        updateDlg.setTitle("Update Available!")
                        updateDlg.setMessage("New Version: " .. onlineVersion .. "\nCurrent Version: " .. CURRENT_VERSION .. "\n\nKya aap update karna chahtay hain?")
                        updateDlg.setButton("Update Now", function()
                            updateDlg.dismiss()
                            downloadUpdate(onlineVersion)
                        end)
                        updateDlg.setButton2("Later", function() updateDlg.dismiss() end)
                        updateDlg.show()
                    end
                }))
            end
        end
    end)
end

function downloadUpdate(onlineVersion)
    updateInProgress = true
    Toast.makeText(context, "Updating... Please wait", 0).show()
    Http.get(UPDATE_CODE_URL .. "?t=" .. os.time(), function(code, mainCode)
        if code == 200 and mainCode and trim(mainCode) ~= "" then
            local f = io.open(PLUGIN_PATH, "w")
            if f then
                f:write(mainCode)
                f:close()
                mainHandler.post(Runnable({
                    run = function()
                        local successDlg = LuaDialog(context)
                        successDlg.setTitle("Success")
                        successDlg.setMessage("Update successful! Please restart the plugin.")
                        successDlg.setButton("OK", function() successDlg.dismiss() end)
                        successDlg.show()
                    end
                }))
            else
              Toast.makeText(context, "File Write Error!", 0).show()
            end
        else
            Toast.makeText(context, "Update Failed!", 0).show()
        end
        updateInProgress = false
    end)
end

-- [API Settings Dialog]
function showApiSettings()
    local v = {}
    local l = {LinearLayout, orientation="vertical", padding="20dp", {TextView, text="Google Gemini API Settings", textSize=16, textColor="#2196F3", paddingBottom="10dp"}, {EditText, id="apiInput", hint="Enter API Key", layout_width="fill", backgroundColor="#F5F5F5", padding="10dp"}, {Button, id="saveBtn", text="SAVE KEY", layout_width="fill", layout_marginTop="10dp", backgroundColor="#4CAF50", textColor="#FFFFFF"}}
    local d = LuaDialog(context).setView(loadlayout(l, v))
    v.apiInput.setText(googleApiKey)
    v.saveBtn.onClick = function() 
        googleApiKey = v.apiInput.getText().toString()
        saveSettings()
        Toast.makeText(context, "API Key Saved!", 0).show()
        d.dismiss() 
    end
    d.show()
end

-- [About & WhatsApp Redirect]
function showAboutDialog()
    local v = {}
    local l = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, text="Google Gemini TTS", textSize=18, textColor="#2E7D32", gravity="center", typeface=Typeface.DEFAULT_BOLD},
        {TextView, text="Developer: Abdul Rauf Amir\nVersion: "..CURRENT_VERSION, gravity="center", paddingBottom="20dp"},
        {Button, id="waBtn", text="SEND FEEDBACK (WHATSAPP)", layout_width="fill", backgroundColor="#25D366", textColor="#FFFFFF"},
        {Button, id="apiBtn", text="API SETTINGS", layout_width="fill", layout_marginTop="10dp", backgroundColor="#9C27B0", textColor="#FFFFFF"},
        {Button, id="closeBtn", text="BACK", layout_width="fill", layout_marginTop="10dp", backgroundColor="#9E9E9E", textColor="#FFFFFF"}
    }
    local d = LuaDialog(context).setView(loadlayout(l, v))
    
    v.waBtn.onClick = function()
        local msg = "Assalam-o-Alaikum Abdul Rauf,\n\nMain aapka Google Gemini TTS extension use kar raha hoon. Extension bohat acha hai, mujay is baray mein feedback dena hai..."
        local url = "https://wa.me/923234391100?text=" .. Uri.encode(msg)
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        d.dismiss()
        if mainDlg then mainDlg.dismiss() end -- Extension close
    end
    
    v.apiBtn.onClick = function() d.dismiss(); showApiSettings() end
    v.closeBtn.onClick = function() d.dismiss() end
    d.show()
end

-- [Audio Generation & UI]
function writeWavHeader(outStream, totalAudioLen)
    local sampleRate, channels, bitsPerSample = 24000, 1, 16
    local byteRate = sampleRate * channels * (bitsPerSample / 8)
    local blockAlign = channels * (bitsPerSample / 8)
    local totalDataLen = totalAudioLen
    local totalSize = totalDataLen + 36
    local function getBytes(val) return {val & 0xff, (val >> 8) & 0xff, (val >> 16) & 0xff, (val >> 24) & 0xff} end
    local tsB, srB, brB, dlB = getBytes(totalSize), getBytes(sampleRate), getBytes(byteRate), getBytes(totalDataLen)
    local h = {0x52, 0x49, 0x46, 0x46, tsB[1], tsB[2], tsB[3], tsB[4], 0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, channels & 0xff, (channels >> 8) & 0xff, srB[1], srB[2], srB[3], srB[4], brB[1], brB[2], brB[3], brB[4], blockAlign & 0xff, (blockAlign >> 8) & 0xff, bitsPerSample & 0xff, (bitsPerSample >> 8) & 0xff, 0x64, 0x61, 0x74, 0x61, dlB[1], dlB[2], dlB[3], dlB[4]}
    for i = 1, #h do outStream.write(h[i]) end
end

function saveToDownloads()
    if not generatedAudioPath then Toast.makeText(context, "Pehle audio generate karein!", 0).show() return end
    local downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
    local fileName = "Gemini_TTS_" .. os.date("%Y%m%d_%H%M%S") .. ".wav"
    local destFile = File(downloadDir, fileName)
    local source = File(generatedAudioPath)
    local input = FileInputStream(source)
    local output = FileOutputStream(destFile)
    local buffer = byte[4096]
    local len = input.read(buffer)
    while len > 0 do output.write(buffer, 0, len); len = input.read(buffer) end
    input.close(); output.close()
    Toast.makeText(context, "Saved to Downloads: " .. fileName, 1).show()
end

function generateAudio(text, voice, apikey, emotion, generateBtn, playBtn, pauseBtn, resultLayout)
    local prompts = { ["Very Happy & Energetic"] = "Joyful energy: ", ["Sad & Emotional"] = "Deeply sad: ", ["Angry & Loud"] = "Intense anger: ", ["Serious & Professional"] = "Professional: ", ["Whispering/Secretive"] = "Whisper: ", ["Excited/Cheer"] = "Excited: ", ["Surprised/Shocked"] = "Shocked: ", ["Tired/Sleepy"] = "Tired: ", ["Shy/Romantic"] = "Romantic: ", ["Heroic/Epic"] = "Heroic: ", ["Sarcastic/Funny"] = "Sarcastic: ", ["Mysterious/Dark"] = "Mysterious: " }
    local finalPrompt = (prompts[emotion] or "Natural: ") .. text
    local apiUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-preview-tts:generateContent?key=" .. apikey
    local body = { contents = {{ parts = {{ text = finalPrompt }} }}, generationConfig = { responseModalities = {"AUDIO"}, speechConfig = { voiceConfig = { prebuiltVoiceConfig = { voiceName = voice } } } } }
    
    Http.post(apiUrl, cjson.encode(body), {["Content-Type"]="application/json"}, function(code, content)
        if code == 200 then
            local ok, data = pcall(cjson.decode, content)
            if ok and data.candidates and data.candidates[1].content.parts[1].inlineData then
                local b64 = data.candidates[1].content.parts[1].inlineData.data
                local bytes = Base64.decode(b64, Base64.NO_WRAP)
                local tempPath = context.getCacheDir().getPath() .. "/tts_temp.wav"
                local fos = FileOutputStream(File(tempPath))
                writeWavHeader(fos, #bytes)
                fos.write(bytes)
                fos.close()
                generatedAudioPath = tempPath
                mainHandler
