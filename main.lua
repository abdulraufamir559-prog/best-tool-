--[[
  @name: Google Gemini text to audio generator
  @author: Abdul Rauf Amir
  @version: 2.1
  @description: Fixed Persistent Update Dialog - Auto Exit on Success
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

-- [Settings]
local CURRENT_VERSION = "2.1" -- Yaad rakhein: GitHub wali file mein bhi version change karna zaroori hai
local VERSION_URL = "https://raw.githubusercontent.com/abdulraufamir559-prog/best-tool-/main/version.txt"
local UPDATE_CODE_URL = "https://raw.githubusercontent.com/abdulraufamir559-prog/best-tool-/main/main.lua"
local updateInProgress = false

-- [Path Detection]
local function getSafePath()
    local path = ""
    if service then path = tostring(service.getLuaDir())
    elseif activity then path = tostring(activity.getLuaDir()) end
    if path == "" or path == "nil" then
        path = "/storage/emulated/0/解说/Plugins/Text to audio generator developed by Abdul Rauf"
    end
    return path .. "/main.lua"
end
local PLUGIN_PATH = getSafePath()

function speak(text)
  if service and service.speak then service.speak(text)
  else Toast.makeText(context, text, 1).show() end
end

-- [Improved Download Logic with Auto-Exit]
function downloadUpdate(onlineVersion)
    updateInProgress = true
    speak("Downloading update, please wait.")
    local freshUrl = UPDATE_CODE_URL .. "?t=" .. os.time()
    Http.get(freshUrl, function(code, mainCode)
        if code == 200 and mainCode and #mainCode > 100 then
            local f = io.open(PLUGIN_PATH, "w")
            if f then
                f:write(mainCode)
                f:close()
                speak("Update was downloaded, please enjoy.")
                
                mainHandler.post(Runnable({run=function()
                    local successDlg = LuaDialog(context)
                    successDlg.setTitle("Update Successful")
                    successDlg.setMessage("Naya version install ho gaya hai. Extension ko refresh karne ke liye OK par click karein.")
                    successDlg.setButton("OK", function() 
                        successDlg.dismiss()
                        if mainDlg then mainDlg.dismiss() end -- Main window band kar dega
                    end)
                    successDlg.setCancelable(false)
                    successDlg.show()
                end}))
            else speak("Path error.") end
        else speak("Update failed.") end
        updateInProgress = false
    end)
end

function checkUpdate()
    if updateInProgress then return end
    Http.get(VERSION_URL .. "?t=" .. os.time(), function(code, response)
        if code == 200 and response then
            local onlineVersion = response:match("^%s*(.-)%s*$") -- Trim function alternative
            -- Dialogue sirf tabhi dikhayega agar version sach mein alag ho
            if onlineVersion ~= CURRENT_VERSION then
                mainHandler.post(Runnable({run=function()
                    local updateDlg = LuaDialog(context)
                    updateDlg.setTitle("New Update!")
                    updateDlg.setMessage("Version " .. onlineVersion .. " available.\n\nKya aap naye features update karna chahte hain?")
                    updateDlg.setButton("Update Now", function() 
                        updateDlg.dismiss() 
                        downloadUpdate(onlineVersion) 
                    end)
                    updateDlg.setButton2("Later", function() updateDlg.dismiss() end)
                    updateDlg.show()
                end}))
            end
        end
    end)
end

-- [Main Interface & Other Functions]
-- (Aapka baaki ka generateAudio, showAboutDialog aur showMain wala hissa yahan aayega)

function showMain()
    -- Load API logic...
    -- UI layout logic...
    -- ...
    
    -- Dialogue check starting delay
    mainHandler.postDelayed(Runnable({run=checkUpdate}), 3000)
end

pcall(showMain)
