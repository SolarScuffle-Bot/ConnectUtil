--!strict

local CollectionService = game:GetService 'CollectionService'
local Players = game:GetService 'Players'
local StarterPlayer = game:GetService 'StarterPlayer'

local StarterCharacter = StarterPlayer:FindFirstChild 'StarterCharacter'

local Module = {}

local function onPlayerTouched(callback: (player: Player, character: Model, humanoid: Humanoid?, part: BasePart) -> ())
	return function(otherPart: BasePart)
		local otherPlayer, otherCharacter, humanoid = Module.getPlayerFromPart(otherPart)
		if otherPlayer and otherCharacter then
			callback(otherPlayer, otherCharacter, humanoid, otherPart)
		end
	end
end

function Module.getPlayerFromPart(basePart: BasePart): (Player?, Model?, Humanoid?)
	local character = basePart:FindFirstAncestorWhichIsA 'Model'
	if not character or character == workspace then
		return nil, nil, nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	local humanoid = character:FindFirstChildWhichIsA 'Humanoid'

	return player, character, humanoid
end

function Module.playerTouched(
	part: BasePart,
	callback: (player: Player, character: Model, humanoid: Humanoid?, part: BasePart) -> ()
)
	return part.Touched:Connect(onPlayerTouched(callback))
end

function Module.playerTouchEnded(
	part: BasePart,
	callback: (player: Player, character: Model, humanoid: Humanoid?, part: BasePart) -> ()
)
	return part.TouchEnded:Connect(onPlayerTouched(callback))
end

function Module.clicked(detector: ClickDetector, callback: (player: Player, character: Model, humanoid: Humanoid) -> ())
	local parent = detector.Parent
	if not parent then
		error(`Trying to connect to a ClickDetector {detector:GetFullName()} without a parent!`)
	end

	return detector.MouseClick:Connect(function(player)
		local character = player.Character
		if not character then
			return
		end

		local head = character:FindFirstChild 'Head' :: BasePart
		if not head then
			return
		end

		local humanoid = character:FindFirstChildWhichIsA 'Humanoid'
		if not humanoid or humanoid.Health <= 0 or humanoid:GetState() == Enum.HumanoidStateType.Dead then
			return
		end

		callback(player, character, humanoid)
	end)
end

function Module.player(added: (Player) -> (), removing: (Player) -> ()?): (RBXScriptConnection, RBXScriptConnection?)
	local addedConnection = Players.PlayerAdded:Connect(added)
	local removingConnection = removing and Players.PlayerRemoving:Connect(removing)
	for _, player in Players:GetPlayers() do
		added(player)
	end
	return addedConnection, removingConnection
end

function Module.yieldUntilAppearanceLoaded(character: Model)
	if StarterCharacter then
		for _, child in StarterCharacter:GetChildren() do
			character:WaitForChild(child.Name)
		end
		return
	end

	local player = Players:GetPlayerFromCharacter(character)
	assert(player, `Passed character {character} with no associated Player`)

	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
end

function Module.appearance(player: Player, added: (Player, Model) -> (), removing: (Player, Model) -> ()?)
	local function callAdded(character)
		Module.yieldUntilAppearanceLoaded(character)
		added(player, character)
	end

	local addedConnection = player.CharacterAdded:Connect(callAdded)

	local removingConnection = removing
		and player.CharacterRemoving:Connect(function(character)
			removing(player, character)
		end)

	if player.Character then
		callAdded(player.Character)
	end

	return addedConnection, removingConnection
end

function Module.character(player: Player, added: (Player, Model) -> (), removing: (Player, Model) -> ()?)
	local addedConnection = player.CharacterAdded:Connect(function(character)
		added(player, character)
	end)

	local removingConnection = removing
		and player.CharacterRemoving:Connect(function(character)
			removing(player, character)
		end)

	if player.Character then
		added(player, player.Character)
	end

	return addedConnection, removingConnection
end

function Module.humanoid(
	character: Model,
	added: (Player, Model, Humanoid) -> (),
	removing: (Player, Model, Humanoid) -> ()
)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		error(
			`{if typeof(character) == 'Instance' then character:GetFullName() else tostring(character)} is not a character of any Player!`
		)
	end

	local humanoid = character:WaitForChild 'Humanoid' :: Humanoid
	added(player, character, humanoid)

	local diedConnection: RBXScriptConnection?, removedConnection: RBXScriptConnection? = nil, nil

	diedConnection = removing
		and humanoid.Died:Once(function()
			(removedConnection :: RBXScriptConnection):Disconnect()
			removing(player, character, humanoid)
		end)

	removedConnection = removing
		and humanoid.AncestryChanged:Connect(function(_, parent)
			if parent ~= character then
				(diedConnection :: RBXScriptConnection):Disconnect();
				(removedConnection :: RBXScriptConnection):Disconnect()
				removing(player, character, humanoid)
			end
		end)

	return removedConnection, diedConnection
end

function Module.tag(tag: string, added: (Instance) -> (), removed: (Instance) -> ()?)
	local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(added)
	local removedConnection = removed and CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
	for _, tagged in CollectionService:GetTagged(tag) do
		added(tagged)
	end

	return addedConnection, removedConnection
end

function Module.tagInstance(instance: Instance, tag: string, added: (Instance) -> (), removed: (Instance) -> ()?)
	local addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(function(other)
		if other == instance then
			added(instance)
		end
	end)

	local removedConnection = removed
		and CollectionService:GetInstanceRemovedSignal(tag):Connect(function(other)
			if other == instance then
				removed(instance)
			end
		end)

	for _, tagged in CollectionService:GetTagged(tag) do
		added(tagged)
	end

	return addedConnection, removedConnection
end

function Module.propertyChanged<T>(instance: Instance, property: string, callback: (new: T, old: T) -> (), skip: boolean?)
	local old = (instance :: any)[property] :: T
	local connection = instance:GetPropertyChangedSignal(property):Connect(function()
		local new = (instance :: any)[property] :: T
		callback(new, old)
		old = new
	end)
	if not skip then
		callback(old, old)
	end
	return connection
end

function Module.attributeChanged(
	instance: Instance,
	attribute: string,
	callback: (new: any, old: any) -> (),
	skip: boolean?
)
	local old = instance:GetAttribute(attribute)
	local connection = instance:GetAttributeChangedSignal(attribute):Connect(function()
		local new = instance:GetAttribute(attribute)
		callback(new, old)
		old = new
	end)
	if not skip then
		callback(old, old)
	end
	return connection
end

function Module.anyAttributeChanged(
	instance: Instance,
	callback: (attribute: string, new: any, old: any) -> (),
	skip: boolean?
)
	local old = {}
	for attribute, value in instance:GetAttributes() do
		old[attribute] = value
	end

	local connection = instance.AttributeChanged:Connect(function(attribute)
		local new = instance:GetAttribute(attribute)
		callback(attribute, new, old[attribute])
		old[attribute] = new
	end)

	if not skip then
		for attribute, value in instance:GetAttributes() do
			callback(attribute, value, old[attribute])
		end
	end

	return connection
end

function Module.valueChanged<T>(instance: ValueBase, callback: (new: T, old: T) -> (), skip: boolean?)
	local old = (instance :: any).Value :: T
	local connection = instance.Changed:Connect(function(new: any)
		callback(new, old)
		old = new
	end)

	if not skip then
		callback(old, old)
	end
	return connection
end

function Module.event(signal: RBXScriptSignal, callback: () -> (), skip: boolean?)
	local connection = signal:Connect(callback)
	if not skip then
		callback()
	end
	return connection
end

local function disconnect(connection: Connection)
	if
		typeof(connection) == 'RBXScriptConnection'
		or type(connection) == 'table' and type(connection.Disconnect) == 'function'
	then
		(connection :: RBXScriptConnection):Disconnect()
	elseif typeof(connection) == 'thread' and coroutine.status(connection) ~= 'normal' then
		task.cancel(connection)
	elseif typeof(connection) == 'Instance' then
		if connection:IsA 'Tween' then
			connection:Pause()
		end
		pcall(connection.Destroy, connection)
	elseif typeof(connection) == 'function' then
		connection()
	end
end

--[[
	Recursively disconnects all connections in the table. Removes all entries except for nested tables.
]]
function Module.clean(connections: { [any]: Connection })
	for key, connection in connections do
		if type(connection) == 'table' and type(connection.Disconnect) ~= 'function' then
			Module.clean(connection :: { [any]: Connection })
		else
			disconnect(connection)
			connections[key] = nil
		end
	end
end

--[[
	Similar to `clean`, but removes nested tables.
]]
function Module.empty(connections: { [any]: Connection })
	Module.clean(connections)
	table.clear(connections)
end

--[[
	Calls `clean` on the value at the specified keys. Does nothing if the value is nil.
	Does not remove the connection if it's a nested table.
]]
-- Type ... as generic so user code gets a warning when it doesn't specify the parameter
-- However, don't give the `connections` table an indexer of `[T]`, since that screws with
-- the type inference of tables passed to this function
function Module.cleanKeys<T...>(connections: { [any]: Connection }, ...: T...)
	for _, key in { select(1, ...) } do -- Using `select` is the only way to silence this type error
		local connection = connections[key]
		if type(connection) == 'table' and type(connection.Disconnect) ~= 'function' then
			Module.clean(connection :: { [any]: Connection })
		elseif connection then
			disconnect(connection)
			connections[key] = nil
		end
	end
end

--[[
	Similar to `cleanKeys`, but removes the connection regardless of if it's a nested table.
]]
function Module.emptyKeys<T...>(connections: { [any]: Connection }, ...: T...)
	Module.cleanKeys(connections, ...)
	for _, key in { select(1, ...) } do
		connections[key] = nil
	end
end

export type Connection =
	RBXScriptConnection
	| { Disconnect: (any) -> () }
	| thread
	| Instance
	| () -> () | { [any]: Connection }

return Module
