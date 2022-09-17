local RunService = game:GetService("RunService")

local DebugLogger = require(script.Parent.DebugLogger)

local plugin = plugin or getfenv().PluginManager():CreatePlugin()
plugin.Name = "Visibility Tools Plugin"

local VisibilityToggler = require(script.Parent.VisibilityToggler.Main)
VisibilityToggler:init()

local hidePluginAction = plugin:CreatePluginAction(
	"VisibilityTools_HideAction",
	"Hide",
	"Hides an object and makes it unclickable.",
	"rbxassetid://10928835654",
	true
)
hidePluginAction.Triggered:Connect(function()
	VisibilityToggler:hideActionTriggered()
end)

local showAllPluginAction = plugin:CreatePluginAction(
	"VisibilityTools_ShowAllAction",
	"Show All",
	"Show all objects hidden by Visibility Tools",
	"rbxassetid://10928835654",
	true
)
showAllPluginAction.Triggered:Connect(function()
	VisibilityToggler:showAll()
end)

local isRunning = false
local isClosed = true
game.Close:Connect(function()
	if not RunService:IsStudio() then
		return
	end
	if isClosed then
		return
	end

	DebugLogger:log("Game is closing!")
	isRunning = false
	isClosed = true
end)

game.ChildAdded:Connect(function()
	if RunService:IsClient() then
		return
	end
	if RunService:IsRunning() and not isRunning then
		DebugLogger:log("Game is running!")
		isRunning = true
		isClosed = false
		VisibilityToggler:showAll()
	end
end)
plugin.Unloading:Connect(function()
	DebugLogger:log("Plugin unloading!")
end)
