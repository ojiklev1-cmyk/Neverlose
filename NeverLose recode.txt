--[[
WARNING: Heads up! This script has not been verified by ScriptBlox. Use at your own risk!
]]

local NEVERLOSE = loadstring(game:HttpGet("https://raw.githubusercontent.com/CludeHub/SourceCludeLib/refs/heads/main/NerverLoseLibEdited.lua"))()

local Window = NEVERLOSE:AddWindow("NEVERLOSE", "CS:GO CHEAT", 'original')

-- === ВКЛАДКИ ===
Window:AddTabLabel('Aimbot')
local RageBot = Window:AddTab('Ragebot', 'CrossHair')
local AntiAim = Window:AddTab('Anti Aim', 'retry')
local LegitBot = Window:AddTab('Legitbt', 'mouse')

Window:AddTabLabel('Visual')
local Players = Window:AddTab('Players', 'user')
local Weapon = Window:AddTab('Weapon', 'gun')
local Grenades = Window:AddTab('Grenades', 'grenade')
local World = Window:AddTab('World', 'earth')
local View = Window:AddTab('View', 'locked')

Window:AddTabLabel('Miscellaneous')
local Main = Window:AddTab('Main', 'list')
local Inventory = Window:AddTab('Inventory', 'sword')
local Scripts = Window:AddTab('Scripts', 'code')
local Config = Window:AddTab('Config', 'gear')

-- === СЕКЦІЇ (чисті, без тестових тоглів) ===
local movement = Main:AddSection('Movement', "left")
local spammers = Main:AddSection('Spammers', "left")
local other = Main:AddSection('Other', "right")
local buybot = Main:AddSection('BuyBot', "right")

local esp = Players:AddSection('ESP', "left")
local glow = Players:AddSection('Glow', "left")
local chams = Players:AddSection('Chams', "right")

local esp2 = Weapon:AddSection('ESP', "left")
local glow2 = Weapon:AddSection('Glow', "left")
local chams2 = Weapon:AddSection('Chams', "right")

local esp3 = Grenades:AddSection('ESP', "left")
local glow3 = Grenades:AddSection('Glow', "left")
local chams3 = Grenades:AddSection('Chams', "right")

local worldmain = World:AddSection('Main', "left")
local worldfog = World:AddSection('Fog', "left")
local worldmisc = World:AddSection('Misc', "right")
local worldhit = World:AddSection('Hit', "right")

local viewcamera = View:AddSection('Camera', "left")
local viewthirdperson = View:AddSection('Thirdperson', "left")
local viewviewmodel = View:AddSection('View Model', "right")
local viewmisc = View:AddSection('Misc', "right")

local ragemain = RageBot:AddSection('Main', "left")
local accuracy = RageBot:AddSection('Accuracy', "left")
local exploits = RageBot:AddSection('Exploits', "right")
local mindamage = RageBot:AddSection('Min. Damage', "right")
local ragemisc = RageBot:AddSection('Misc', "right")

local aimmain = AntiAim:AddSection('Main', "left")
local fakelag = AntiAim:AddSection('Fake Lag', "left")
local fakeangle = AntiAim:AddSection('Fake Angle', "right")
local aimmisc = AntiAim:AddSection('Misc', "right")

local legitmain = LegitBot:AddSection('Main', "left")
local recoil = LegitBot:AddSection('Recoil Control', "left")
local aims = LegitBot:AddSection('Aim', "right")
local delay = LegitBot:AddSection('Delay', "right")
local autofire = LegitBot:AddSection('Auto Fire', "right")

local inventory = Inventory:AddSection('Inventory', "left")
local inventory2 = Inventory:AddSection('Inventory 2', "right")

-- === ВІДКРИТТЯ/ЗАКРИТТЯ МЕНЮ НА INSERT ===
local UserInputService = game:GetService("UserInputService")

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.Insert then
		local screenGui = game:GetService("CoreGui"):FindFirstChild("NEVERLOSE")
		if screenGui then
			screenGui.Enabled = not screenGui.Enabled
		end
	end
end)