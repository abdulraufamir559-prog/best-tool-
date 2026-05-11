--[[
  @name: Google Gemini text to audio generator
  @author: Abdul Rauf Amir
  @version: 1.5
  @description: Advanced TTS with Voice Announcement on Update
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
local CURRENT_VERSION = "1.5"
local VERSION_URL = "https://raw.githubusercontent.com/abdulraufamir559-prog/best-tool-/main/version.txt"
local UPDATE_CODE_URL = "https://raw.githubusercontent.com/abdulraufamir559-prog/best-tool-/main/main.lua"
local PLUGIN_PATH = "/storage/emulated/0/解说/Plugins/Text to audio generator developed by Abdul Rauf/main.lua"
local updateInProgress = false

-- [Audio & UI Settings]
local VOICE_LIST = {"Puck", "Kore", "Charon", "Zephyr", "Fenrir", "Leda", "Orus", "Aoede", "Callirrhoe", "Autonoe", "Enceladus", "Iapetus", "Umbriel", "Algieba", "Despina", "Erinome", "Algenib", "Rasalgethi", "Laomedeia", "Achernar", "Alnilam", "Schedar", "Gacrux", "Pulcherrima"}
local EMOTIONS = {"Natural/Neutral", "Very Happy & Energetic", "Sad & Emotional", "Angry & Loud", "Serious & Professional", "Whispering/Secretive", "Excited/Cheer", "Surprised/Shocked", "Tired/Sleepy", "Shy/Romantic", "Heroic/Epic", "Sarcastic/Funny", "Mysterious/Dark"}

local googleApiKey = ""
local generatedAudioPath = nil
local mediaPlayer = nil
local mainDlg = nil

local PREFS_NAME = "Gemini_TTS_Abdul_Rauf"
local prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)

function trim(s) return s and s:match("^%s*(.-)%s*$") or "" end
function loadSettings() googleApiKey = prefs.getString("apikey", "") end
function saveSettings() local editor = prefs.edit(); editor.putString("apikey", googleApiKey); editor.apply() end

-- [Voice Announcement Function]
function speak(text)
  if service and service.speak then
    service.speak(text)
  else
    Toast.makeText(context, text, 1).show()
  end
end

-- [Update Logic with Voice]
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
                        updateDlg.setMessage("New Version: " .. onlineVersion .. "\n\nKya aap update karna chahtay hain?")
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
    Toast.makeText(context, "Downloading...", 0).show()
    local freshUrl = UPDATE_CODE_URL .. "?t=" .. os.time()
    
    Http.get(freshUrl, function(code, mainCode)
        if code == 200 and mainCode and #mainCode > 100 then
            local f = io.open(PLUGIN_PATH, "w")
            if f then
                f:write(mainCode)
                f:close()
                -- Voice Announcement after successful update
                speak("Update was downloaded, please enjoy.")
                
                mainHandler.post(Runnable({
                    run = function()
                        local successDlg = LuaDialog(context)
                        successDlg.setTitle("Done")
                        successDlg.setMessage("Update successful! Please restart the extension.")
                        successDlg.setButton("OK", function() successDlg.dismiss() end)
                        successDlg.show()
                    end
                }))
            else
                speak("Update failed to save.")
            end
        else
            speak("Server error during update.")
        end
        updateInProgress = false
    end)
end

-- [Settings & About]
function showAboutDialog()
    local v = {}
    local l = {
        LinearLayout, orientation="vertical", padding="20dp",
        {TextView, text="About Extension", textSize=18, gravity="center", typeface=Typeface.DEFAULT_BOLD},
        {TextView, text="Director: Abdul Rauf Amir", gravity="center", paddingBottom="15dp"},
        {Button, id="waBtn", text="WHATSAPP FEEDBACK", layout_width="fill", backgroundColor="#25D366", textColor="#FFFFFF"},
        {Button, id="apiBtn", text="SET API KEY", layout_width="fill", layout_marginTop="10dp", backgroundColor="#2196F3", textColor="#FFFFFF"},
        {Button, id="closeBtn", text="BACK", layout_width="fill", layout_marginTop="10dp"}
    }
    local d = LuaDialog(context).setView(loadlayout(l, v))
    v.waBtn.onClick = function()
        local url = "https://wa.me/923234391100?text=" .. Uri.encode("Feedback for Gemini TTS:")
        context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url)))
        d.dismiss()
        if mainDlg then mainDlg.dismiss() end
    end
    v.apiBtn.onClick = function()
        d.dismiss()
        local av = {}
        local al = {LinearLayout, orientation="vertical", padding="20dp", {EditText, id="apiInput", hint="Enter API Key", layout_width="fill"}, {Button, id="saveBtn", text="SAVE", layout_width="fill"}}
        local ad = LuaDialog(context).setView(loadlayout(al, av))
        av.apiInput.setText(googleApiKey)
        av.saveBtn.onClick = function() googleApiKey = av.apiInput.getText().toString(); saveSettings(); ad.dismiss() end
        ad.show()
    end
    v.closeBtn.onClick = function() d.dismiss() end
    d.show()
end

-- [Core Audio Functions]
function writeWavHeader(outStream, totalAudioLen)
    local sampleRate, channels, bitsPerSample = 24000, 1, 16
    local byteRate = sampleRate * channels * (bitsPerSample / 8)
    local blockAlign = channels * (bitsPerSample / 8)
    local totalSize = totalAudioLen + 36
    local function getBytes(val) return {val & 0xff, (val >> 8) & 0xff, (val >> 16) & 0xff, (val >> 24) & 0xff} end
    local tsB, srB, brB, dlB = getBytes(totalSize), getBytes(sampleRate), getBytes(byteRate), getBytes(totalAudioLen)
    local h = {0x52, 0x49, 0x46, 0x46, tsB[1], tsB[2], tsB[3], tsB[4], 0x57, 0x41, 0x56, 0x45, 0x66, 0x6d, 0x74, 0x20, 0x10, 0x00, 0x00, 0x00, 0x01, 0x00, channels & 0xff, (channels >> 8) & 0xff, srB[1], srB[2], srB[3], srB[4], brB[1], brB[2], brB[3], brB[4], blockAlign & 0xff, (blockAlign >> 8) & 0xff, bitsPerSample & 0xff, (bitsPerSample >> 8) & 0xff, 0x64, 0x61, 0x74, 0x61, dlB[1], dlB[2], dlB[3], dlB[4]}
    for i = 1, #h do outStream.write(h[i]) end
end

function saveToDownloads()
    if not generatedAudioPath then return end
    local downloadDir = Environment.getExternalStoragePublicDirectory(Environment.DIRECTORY_DOWNLOADS)
    local fileName = "AbdulRauf_TTS_" .. os.date("%Y%m%d_%H%M%S") .. ".wav"
    local destFile = File(downloadDir, fileName)
    local source = File(generatedAudioPath)
    local input = FileInputStream(source)
    local output = FileOutputStream(destFile)
    local buffer = byte[4096]
    local len = input.read(buffer)
    while len > 0 do output.write(buffer, 0, len); len = input.read(buffer) end
    input.close(); output.close()
    Toast.makeText(context, "Saved!", 0).show()
end

function generateAudio(text, voice, apikey, emotion, generateBtn, playBtn, resultLayout)
    local prompts = { ["Very Happy & Energetic"] = "Joyful: ", ["Sad & Emotional"] = "Sad: ", ["Angry & Loud"] = "Angry: ", ["Serious & Professional"] = "Formal: ", ["Whispering/Secretive"] = "Whisper: ", ["Excited/Cheer"] = "Excited: ", ["Surprised/Shocked"] = "Shocked: ", ["Tired/Sleepy"] = "Tired: ", ["Shy/Romantic"] = "Romantic: ", ["Heroic/Epic"] = "Heroic: ", ["Sarcastic/Funny"] = "Funny: ", ["Mysterious/Dark"] = "Dark: " }
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
                mainHandler.post(Runnable({run=function()
                    resultLayout.setVisibility(View.VISIBLE)
                    playBtn.setEnabled(true)
                    generateBtn.setText("REGENERATE")
                    generateBtn.setEnabled(true)
                    speak("Audio is ready.")
                end}))
            end
        else
            mainHandler.post(Runnable({run=function()
                generateBtn.setEnabled(true); generateBtn.setText("GENERATE")
                speak("Error code " .. code)
            end}))
        end
    end)
end

function showMain()
    loadSettings()
    local views = {}
    local layout = { ScrollView, layout_width="fill", { LinearLayout, orientation="vertical", padding="20dp", {TextView, text="Gemini Text to Audio", textSize=18, textColor="#2E7D32", gravity="center", typeface=Typeface.DEFAULT_BOLD}, {TextView, text="By Abdul Rauf Amir", gravity="center", paddingBottom="15dp"}, {EditText, id="textInput", hint="Enter text...", layout_height="120dp", layout_width="fill", gravity=Gravity.TOP, backgroundColor="#F5F5F5", padding="10dp"}, {TextView, text="Select Emotion:", layout_marginTop="10dp"}, {Spinner, id="emotionSpin", layout_width="fill"}, {TextView, text="Select Voice:", layout_marginTop="5dp"}, {Spinner, id="voiceSpin", layout_width="fill"}, {Button, id="generateBtn", text="GENERATE", layout_width="fill", layout_marginTop="15dp", backgroundColor="#2196F3", textColor="#FFFFFF"}, {LinearLayout, id="resultLayout", visibility=View.GONE, layout_marginTop="10dp", {Button, id="playBtn", text="PLAY", layout_weight=1, backgroundColor="#4CAF50", textColor="#FFFFFF"}, {Button, id="downloadBtn", text="DOWNLOAD", layout_weight=1, backgroundColor="#FF9800", textColor="#FFFFFF"}}, {Button, id="aboutBtn", text="ABOUT / SETTINGS", layout_width="fill", layout_marginTop="20dp", backgroundColor="#607D8B", textColor="#FFFFFF"}, {Button, id="exitBtn", text="EXIT", layout_width="fill", backgroundColor="#D32F2F", textColor="#FFFFFF", layout_marginTop="10dp"} } }
    mainDlg = LuaDialog(context).setView(loadlayout(layout, views))
    
    views.textInput.setFilters({InputFilter.LengthFilter(CHAR_LIMIT)})
    views.emotionSpin.setAdapter(ArrayAdapter(context, android.R.layout.simple_spinner_item, EMOTIONS))
    views.voiceSpin.setAdapter(ArrayAdapter(context, android.R.layout.simple_spinner_item, VOICE_LIST))
    
    views.generateBtn.onClick = function()
        local txt = views.textInput.getText().toString()
        if txt == "" or googleApiKey == "" then speak("Please check API key or text.") return end
        views.generateBtn.setText("Processing..."); views.generateBtn.setEnabled(false)
        generateAudio(txt, VOICE_LIST[views.voiceSpin.getSelectedItemPosition()+1], googleApiKey, EMOTIONS[views.emotionSpin.getSelectedItemPosition()+1], views.generateBtn, views.playBtn, views.resultLayout)
    end
    
    views.playBtn.onClick = function()
        if mediaPlayer then mediaPlayer.release() end
        mediaPlayer = MediaPlayer(); mediaPlayer.setDataSource(generatedAudioPath); mediaPlayer.prepare(); mediaPlayer.start()
    end
    
    views.downloadBtn.onClick = function() saveToDownloads() end
    views.aboutBtn.onClick = function() showAboutDialog() end
    views.exitBtn.onClick = function() if mediaPlayer then mediaPlayer.release() end; mainDlg.dismiss() end
    
    mainDlg.show()
    mainHandler.postDelayed(Runnable({run=checkUpdate}), 2000)
end

showMain()
