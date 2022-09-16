local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local PhysicsService = game:GetService("PhysicsService")

local root = script.Parent
local ObjectState = require(root.ObjectState)
local CollisionGroupMgr = require(root.CollisionGroupMgr)
local Globals = require(root.Globals)

--Helper functions
local hasEnabledProperty = ObjectState.hasEnabledProperty
local hasTransparencyProperty = ObjectState.hasTransparencyProperty
local isContainerObject = ObjectState.isContainerObject
local isValidObject = ObjectState.isValidObject
local isHideableObject = ObjectState.isHideableObject
local isHidden = ObjectState.isHidden
local isInvisible = ObjectState.isInvisible
local parentIsNotHidden = ObjectState.parentIsNotHidden

--local COLLISION_GROUP = "VisibilityTools_CollisionGroup"
--local HIDDEN = "VisibilityTools_Hidden"
--local INVISIBLE = "VisibilityTools_Invisible"
--local ENABLED = "VisibilityTools_Enabled"
--local TRANSPARENCY = "VisibilityTools_Transparency"

local connections
local function cleanUp()
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

local function toggleVisibility(toggle, obj)
	if not isHideableObject(obj) then
		return
	end
	if toggle == 1 then
		if isInvisible(obj) then
			return
		end
		if hasTransparencyProperty(obj) then
			ObjectState.makeTransparent(obj)
		elseif hasEnabledProperty(obj) then
			ObjectState.makeUnEnabled(obj)
		end
		CollisionGroupMgr:AddToHiddenCollisionGroup(obj)
	elseif toggle == 0 then
		if isInvisible(obj) == false then
			return
		end
		if hasTransparencyProperty(obj) then
			ObjectState.makeUnTransparent(obj)
		elseif hasEnabledProperty(obj) then
			ObjectState.makeEnabled(obj)
		end
		CollisionGroupMgr:RemoveFromHiddenCollisionGroup(obj)
	end
	ObjectState.updateObjectName(obj)
end

local function getChildObjects(object)
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

local function toggleVisibilityForChildObjects(toggle, toggledObject)
	local childObjs = getChildObjects(toggledObject)
	--Toggle the transparency of an object, but make sure that it isn't a descendant of a hidden object.
	--If it is, ignore it.
	for _, obj in ipairs(childObjs) do
		--if  then continue end
		if isHidden(obj) == false and parentIsNotHidden(obj, toggledObject) then
			toggleVisibility(toggle, obj)
		end
	end
end

local function showObject(obj)
	if not isHideableObject(obj) then
		return
	end
	if isHidden(obj) == false then
		return
	end

	ObjectState.makeNotHidden(obj)

	CollectionService:RemoveTag(obj, Globals.HIDDEN)
	CollisionGroupMgr:RemoveFromHiddenCollisionGroup(obj)
	if connections[obj] then
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

local function listenForAncestryChange(descendant)
	if isHidden(descendant) then
		return
	end
	if not connections[descendant] then
		connections[descendant] = {}
	end
	connections[descendant].ancestryChanged = descendant.AncestryChanged:Connect(function(child, parent)
		if parentIsNotHidden(child) then
			toggleVisibility(0, child)
			toggleVisibilityForChildObjects(0, child)
		end
		if connections[child].ancestryChanged then
			connections[child].ancestryChanged:Disconnect()
		end
	end)
end

local function setupListeners(obj)
	--Listen for adding and removing descendants
	connections[obj] = {}
	connections[obj].added = obj.DescendantAdded:Connect(function(descendant)
		--if an object is added to this hidden object,
		--make sure it is invisible.
		toggleVisibility(1, descendant)
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
				listenForAncestryChange(descendant)
			end
		end
	end)
end

local function hideObject(obj)
	if not isHideableObject(obj) then
		return
	end

	--The object might already be hidden, but setup listeners anyways.
	--Do this in case you've reopened the file and the listeners were reset.
	setupListeners(obj)

	if isHidden(obj) then
		return
	end

	ObjectState.makeHidden(obj)

	CollectionService:AddTag(obj, Globals.HIDDEN)
	CollisionGroupMgr:AddToHiddenCollisionGroup(obj)

	ObjectState.updateObjectName(obj)
end

local function toggleHidden(toggle, objects)
	local objectsToToggle = objects
	for _, toggledObject in ipairs(objects) do
		if toggle == 1 then
			hideObject(toggledObject)
		elseif toggle == 0 then
			showObject(toggledObject)
		end

		--Check to see if it is a descendant of a Hidden object.
		if parentIsNotHidden(toggledObject) then
			toggleVisibility(toggle, toggledObject)
		end

		toggleVisibilityForChildObjects(toggle, toggledObject)
	end

	cleanUp()
end

local function showAll()
	if not game:GetService("RunService"):IsEdit() then
		return
	end
	ChangeHistoryService:SetWaypoint("Initiating Show All")

	local hiddenObjects = CollectionService:GetTagged(Globals.HIDDEN)
	for _, hiddenObject in ipairs(hiddenObjects) do
		showObject(hiddenObject)
		toggleVisibility(0, hiddenObject)
		toggleVisibilityForChildObjects(0, hiddenObject)
	end
	cleanUp()
	ChangeHistoryService:SetWaypoint("Show All")
end

local function hideActionTriggered()
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
		toggleHidden(1, objectsToToggle)
		ChangeHistoryService:SetWaypoint("Hide Object")
	else
		ChangeHistoryService:SetWaypoint("Initiating Show")
		toggleHidden(0, objectsToToggle)
		ChangeHistoryService:SetWaypoint("Show Object")
	end
end

local function init()
	if not connections then
		connections = {}
	end
	local tagged = CollectionService:GetTagged(Globals.HIDDEN)
	if #tagged > 0 then
		--there are things still tagged as hidden, so make sure they are hidden.
		toggleHidden(1, tagged)
	end
	cleanUp()
end

local hidePluginAction = plugin:CreatePluginAction(
	"VisibilityTools_HideAction",
	"Hide",
	"Hides an object and makes it unclickable.",
	"rbxassetid://9614014815",
	true
)
hidePluginAction.Triggered:Connect(hideActionTriggered)

local showAllPluginAction = plugin:CreatePluginAction(
	"VisibilityTools_ShowAllAction",
	"Show All",
	"Show all objects hidden by Visibility Tools",
	"rbxassetid://9614014815",
	true
)
showAllPluginAction.Triggered:Connect(showAll)

if game:GetService("RunService"):IsEdit() then
	init()
end
