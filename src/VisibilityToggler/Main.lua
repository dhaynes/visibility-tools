local Main = {}

local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local root = script.Parent
local ObjectState = require(root.ObjectState)
local CollisionGroupMgr = require(root.CollisionGroupManager)
local Globals = require(root.Globals)

--Helper functions
-- local hasEnabledProperty = ObjectState.hasEnabledProperty
-- local hasTransparencyProperty = ObjectState.hasTransparencyProperty
-- local isContainerObject = ObjectState.isContainerObject
local isValidObject = ObjectState.isValidObject
local isHideableObject = ObjectState.isHideableObject
local isHidden = ObjectState.isHidden
local isInvisible = ObjectState.isInvisible
local parentIsNotHidden = ObjectState.parentIsNotHidden

local connections
function Main:cleanUp()
	--check if there are any hidden parts. If not, do some cleanup.
	if #CollectionService:GetTagged(Globals.HIDDEN) == 0 then
		PhysicsService:RemoveCollisionGroup(Globals.HIDDEN)
		for _, v in ipairs(connections) do
			if v.added then
				v.added:Disconnect()
			end
			if v.removing then
				v.added:Disconnect()
			end
			if v.ancestryChanged then
				v.ancestryChanged:Disconnect()
			end
		end
		table.clear(connections)
	end
end

function Main:toggleVisibility(toggle, obj)
	if toggle == 1 then
		if ObjectState.makeInvisible(obj) then
			CollisionGroupMgr:AddToHiddenCollisionGroup(obj)
		end
	elseif toggle == 0 then
		if ObjectState.makeVisible(obj) then
			CollisionGroupMgr:RemoveFromHiddenCollisionGroup(obj)
		end
	end
end

function Main:getChildObjects(object)
	--Recursively check for all children, but only check children of certain types of objects.
	local childObjs = {}
	local function recursiveSearch(parent)
		for _, child in ipairs(parent:GetChildren()) do
			if isHideableObject(child) then
				table.insert(childObjs, child)
				recursiveSearch(child)
			end
		end
	end
	recursiveSearch(object)
	return childObjs
end

function Main:toggleVisibilityForChildObjects(toggle, toggledObject)
	local childObjs = self:getChildObjects(toggledObject)
	--Toggle the transparency of an object, but make sure that it isn't a descendant of a hidden object.
	--If it is, ignore it.
	for _, obj in ipairs(childObjs) do
		--if  then continue end
		if isHidden(obj) == false and parentIsNotHidden(obj, toggledObject) then
			self:toggleVisibility(toggle, obj)
		end
	end
end

function Main:showObject(obj)
	if not isHideableObject(obj) then
		return
	end
	if isHidden(obj) == false then
		return
	end

	ObjectState.markAsNotHidden(obj)

	if parentIsNotHidden(obj) then
		CollectionService:RemoveTag(obj, Globals.HIDDEN)
		CollisionGroupMgr:RemoveFromHiddenCollisionGroup(obj)
	end

	if connections and connections[obj] then
		if connections[obj].added then
			connections[obj].added:Disconnect()
		end
		if connections[obj].removing then
			connections[obj].removing:Disconnect()
		end
		table.clear(connections[obj])
	end

	ObjectState.updateObjectName(obj)
end

function Main:listenForAncestryChange(descendant)
	if isHidden(descendant) then
		return
	end
	if not connections[descendant] then
		connections[descendant] = {}
	end
	connections[descendant].ancestryChanged = descendant.AncestryChanged:Connect(function(child, parent)
		if parentIsNotHidden(child) then
			self:toggleVisibility(0, child)
			self:toggleVisibilityForChildObjects(0, child)
		end
		if connections[child].ancestryChanged then
			connections[child].ancestryChanged:Disconnect()
		end
	end)
end

function Main:setupListeners(obj)
	--Listen for adding and removing descendants
	connections[obj] = {}
	connections[obj].added = obj.DescendantAdded:Connect(function(descendant)
		--if an object is added to this hidden object,
		--make sure it is invisible.
		self:toggleVisibility(1, descendant)
	end)

	connections[obj].removing = obj.DescendantRemoving:Connect(function(descendant)
		--if an object is REMOVED as a descendant,
		--then make sure it knows whether or not it should
		--be visible or not.
		if isHidden(descendant) == true then
			return
		end
		--There could be multiple removals at once. Use the selection to check.
		--The first returned is always the object with the connection.
		for _, selectedObject in ipairs(Selection:Get()) do
			if selectedObject == descendant then
				self:listenForAncestryChange(descendant)
			end
		end
	end)
end

function Main:hideObject(obj)
	if not isHideableObject(obj) then
		return
	end

	--The object might already be hidden, but setup listeners anyways.
	--Do this in case you've reopened the file and the listeners were reset.
	self:setupListeners(obj)

	if isHidden(obj) then
		return
	end

	ObjectState.markAsHidden(obj)

	CollectionService:AddTag(obj, Globals.HIDDEN)
	CollisionGroupMgr:AddToHiddenCollisionGroup(obj)

	ObjectState.updateObjectName(obj)
end

function Main:toggleHidden(toggle, objects)
	for _, toggledObject in ipairs(objects) do
		if toggle == 1 then
			self:hideObject(toggledObject)
		elseif toggle == 0 then
			self:showObject(toggledObject)
		end

		--Check to see if it is a descendant of a Hidden object.
		if parentIsNotHidden(toggledObject) then
			self:toggleVisibility(toggle, toggledObject)
		end

		self:toggleVisibilityForChildObjects(toggle, toggledObject)
	end

	self:cleanUp()
end

function Main:showAll()
	ChangeHistoryService:SetWaypoint("Initiating Show All")

	local hiddenObjects = CollectionService:GetTagged(Globals.HIDDEN)
	for _, hiddenObject in ipairs(hiddenObjects) do
		CollectionService:RemoveTag(hiddenObject, Globals.HIDDEN)
		self:showObject(hiddenObject)
		self:toggleVisibility(0, hiddenObject)
		self:toggleVisibilityForChildObjects(0, hiddenObject)
	end
	self:cleanUp()
	ChangeHistoryService:SetWaypoint("Show All")
end

function Main:hideActionTriggered()
	if not game:GetService("RunService"):IsEdit() then
		return
	end
	--Check to see if any of the selected objects are shown.
	--If so, then default to hide vs show.
	local selectedObjectIsNotHidden = false
	local selection = Selection:Get()
	local objectsToToggle = {}
	for _, selectedObject in ipairs(selection) do
		if isValidObject(selectedObject) == false then
			continue
		end
		if not isHidden(selectedObject) then
			selectedObjectIsNotHidden = true
		end
		table.insert(objectsToToggle, selectedObject)
	end
	if selectedObjectIsNotHidden then
		ChangeHistoryService:SetWaypoint("Initiating Hide")
		self:toggleHidden(1, objectsToToggle)
		ChangeHistoryService:SetWaypoint("Hide Object")
	else
		ChangeHistoryService:SetWaypoint("Initiating Show")
		self:toggleHidden(0, objectsToToggle)
		ChangeHistoryService:SetWaypoint("Show Object")
	end
end

function Main:init()
	if RunService:IsRunning() and RunService:IsClient() then
		return
	end

	print("Initializing plugin...")

	if not connections then
		connections = {}
	end
	local tagged = CollectionService:GetTagged(Globals.HIDDEN)
	if #tagged > 0 then
		--there are things still tagged as hidden, so make sure they are hidden.
		self:toggleHidden(1, tagged)
	end
	self:cleanUp()
end

-- local hidePluginAction = plugin:CreatePluginAction(
-- 	"VisibilityTools_HideAction",
-- 	"Hide",
-- 	"Hides an object and makes it unclickable.",
-- 	"rbxassetid://10928835654",
-- 	true
-- )
-- -- hidePluginAction.Triggered:Connect(VisibilityToggler:hideActionTriggered())
-- hidePluginAction.Triggered:Connect(hideActionTriggered)

-- local showAllPluginAction = plugin:CreatePluginAction(
-- 	"VisibilityTools_ShowAllAction",
-- 	"Show All",
-- 	"Show all objects hidden by Visibility Tools",
-- 	"rbxassetid://10928835654",
-- 	true
-- )
-- -- showAllPluginAction.Triggered:Connect(VisibilityToggler:showAll())
-- showAllPluginAction.Triggered:Connect(showAll)

return Main
