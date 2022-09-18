local Main = {
	connections = nil,
	workspaceConnection = nil,
}

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local Selection = game:GetService("Selection")
local PhysicsService = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local pluginRoot = script.Parent.Parent
local root = script.Parent
local ObjectState = require(root.ObjectState)
local CollisionGroupMgr = require(root.CollisionGroupManager)
local Globals = require(root.Globals)

--Helper functions
local isValidObject = ObjectState.isValidObject
local isHideableObject = ObjectState.isHideableObject
local isHidden = ObjectState.isHidden
local isInvisible = ObjectState.isInvisible

local DebugLogger = require(pluginRoot.DebugLogger)

function Main:cleanUp()
	--check if there are any hidden parts. If not, do some cleanup.
	if #CollectionService:GetTagged(Globals.HIDDEN) == 0 then
		PhysicsService:RemoveCollisionGroup(Globals.HIDDEN)
		for _, v in ipairs(self.connections) do
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
		table.clear(self.connections)
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

function Main:parentIsNotHidden(obj, ignore)
	--walk upwards in the hierarchy to check for a parent that is hidden.
	local parent = obj.Parent
	while true do
		if parent ~= ignore and ObjectState.isHidden(parent) then
			return false
		elseif parent == game.Workspace then
			return true
		else
			parent = parent.Parent
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
		if isHidden(obj) == false and self:parentIsNotHidden(obj, toggledObject) then
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

	if self:parentIsNotHidden(obj) then
		CollectionService:RemoveTag(obj, Globals.HIDDEN)
		CollisionGroupMgr:RemoveFromHiddenCollisionGroup(obj)
	end

	if self.connections and self.connections[obj] then
		if self.connections[obj].added then
			self.connections[obj].added:Disconnect()
		end
		if self.connections[obj].removing then
			self.connections[obj].removing:Disconnect()
		end
		table.clear(self.connections[obj])
	end
end

function Main:listenForAncestryChange(descendant)
	if isHidden(descendant) then
		return
	end
	if not self.connections[descendant] then
		self.connections[descendant] = {}
	end
	self.connections[descendant].ancestryChanged = descendant.AncestryChanged:Connect(function(child, parent)
		if self:parentIsNotHidden(child) then
			self:toggleVisibility(0, child)
			self:toggleVisibilityForChildObjects(0, child)
		end
		if self.connections[child].ancestryChanged then
			self.connections[child].ancestryChanged:Disconnect()
		end
	end)
end

function Main:setupListeners(obj)
	--Listen for adding and removing descendants
	self.connections[obj] = {}
	self.connections[obj].added = obj.DescendantAdded:Connect(function(descendant)
		--if an object is added to this hidden object,
		--make sure it is invisible.
		DebugLogger:log("Descendant added to " .. obj.Name .. ": " .. descendant.Name)
		self:toggleVisibility(1, descendant)
	end)

	self.connections[obj].removing = obj.DescendantRemoving:Connect(function(descendant)
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
end

function Main:toggleHidden(toggle, objects)
	for _, toggledObject in ipairs(objects) do
		if toggle == 1 then
			self:hideObject(toggledObject)
		elseif toggle == 0 then
			self:showObject(toggledObject)
		end

		--Check to see if it is a descendant of a Hidden object.
		if self:parentIsNotHidden(toggledObject) then
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

	DebugLogger:log("Initializing VisibilityTools plugin")

	if not self.connections then
		self.connections = {}
	end
	local tagged = CollectionService:GetTagged(Globals.HIDDEN)
	if #tagged > 0 then
		--there are things still tagged as hidden, so make sure they are hidden.
		self:toggleHidden(1, tagged)
	end

	--Add a listener to workspace to look for children that are added.
	--Used to handle copy/pasting hidden objects from other placefiles.
	if not self.workspaceConnection then
		self.workspaceConnection = game.Workspace.DescendantAdded:Connect(function(descendant)
			if RunService:IsRunning() then
				return
			end

			DebugLogger:log("Child added to Workspace")
			--if it's hidden and pasted into the workspace, it might not have any listeners attached to it.
			--so hide it again to reinitialize listeners.
			if isHidden(descendant) then
				self:hideObject(descendant)
			end
			if isInvisible(descendant) and not isHidden(descendant) then
				if self:parentIsNotHidden(descendant) then
					self:toggleVisibility(0, descendant)
				end
			end
			self:cleanUp()
		end)
	end

	self:cleanUp()
end

return Main
