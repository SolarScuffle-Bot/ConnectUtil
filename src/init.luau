--!strict

local CollectionService = game:GetService 'CollectionService'
local Players = game:GetService 'Players'
local StarterPlayer = game:GetService 'StarterPlayer'

local StarterCharacter = StarterPlayer:FindFirstChild 'StarterCharacter'

local Module = {}

local function onPlayerTouched(callback: (other: BasePart, player: Player, character: Model, humanoid: Humanoid?) -> ())
	return function(otherPart: BasePart)
		local otherPlayer, otherCharacter, humanoid = Module.getPlayerFromPart(otherPart)
		if otherPlayer and otherCharacter then
			callback(otherPart, otherPlayer, otherCharacter, humanoid)
		end
	end
end

--[=[
	If the part is a character part, returns the player who owns that part, that player's character, and the character's humanoid (if present).
]=]
function Module.getPlayerFromPart(part: BasePart): (Player?, Model?, Humanoid?)
	local character = part:FindFirstAncestorWhichIsA 'Model'
	if not character then
		return nil, nil, nil
	end

	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		return nil, nil, nil
	end

	local humanoid = character:FindFirstChildWhichIsA 'Humanoid'

	return player, character, humanoid
end

--[=[
	Listens for Touched on the part.
	`callback` is called only when the part is touched by a character.
]=]
function Module.playerTouched(
	part: BasePart,
	callback: (other: BasePart, player: Player, character: Model, humanoid: Humanoid?) -> ()
)
	return part.Touched:Connect(onPlayerTouched(callback))
end

--[=[
	Listens for TouchEnded on the part.
	`callback` is called only when the part is touched by a character.
]=]
function Module.playerTouchEnded(
	part: BasePart,
	callback: (other: BasePart, player: Player, character: Model, humanoid: Humanoid?) -> ()
)
	return part.TouchEnded:Connect(onPlayerTouched(callback))
end

--[=[
	Listens for the ClickDetector being clicked.
	`callback` is called only when clicked by a player whose character has an alive humanoid.
]=]
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

--[=[
	Connects to a signal and fires the callback immediately.
]=]
function Module.event(event: RBXScriptSignal | { Connect: (any, (...any) -> ()) -> (any) -> () }, callback: () -> ())
	local connection = event:Connect(callback) :: RBXScriptConnection
	callback()
	return connection
end

--[=[
	Resumes the thread after all passed signals, tweens, sounds, animations, signals, and functions are called, fired, or finished.
	Call `coroutine.yield()` after calling this function to yield the thread, and wait for this to resume it again.
]=]
function Module.resumeAfterAll(
	...: RBXScriptSignal | Tween | Sound | AnimationTrack | (
	) -> ()
		| {
			Once: ((any, () -> ()) -> { Disconnect: (any) -> () })?,
			Connect: (any, () -> ()) -> { Disconnect: (any) -> () },
		}
)
	local args = { ... }
	local count = #args
	local currentThread = coroutine.running()

	local function tryResume()
		count -= 1
		if count == 0 then
			task.spawn(currentThread)
		end
	end

	local connections = {} :: { any }

	for i, v in args do
		if type(v) == 'function' then
			continue
		elseif type(v) == 'table' then
			if v.Once then
				connections[i] = v:Once(tryResume)
			else
				local connection
				connection = v:Connect(function()
					connection:Disconnect()
					tryResume()
				end)
			end
		elseif typeof(v) == 'RBXScriptSignal' then
			connections[i] = v:Once(tryResume)
		elseif v:IsA 'Tween' then
			connections[i] = v.Completed:Once(tryResume)
		elseif v:IsA 'Sound' then
			connections[i] = v.Ended:Once(tryResume)
		elseif v:IsA 'AnimationTrack' then
			connections[i] = v.Ended:Once(tryResume)
		else
			connections[i] = v:Once(tryResume)
		end
	end

	for i, v in args do
		if type(v) == 'table' or typeof(v) == 'RBXScriptSignal' then
			continue
		elseif type(v) == 'function' then
			connections[i] = task.defer(function()
				v()
				tryResume()
			end)
		else
			v:Play()
		end
	end

	return table.unpack(connections)
end

--[=[
	Resumes the thread after the first passed signals, tweens, sounds, animations, signals, and functions are called, fired, or finished.
	Call `coroutine.yield()` after calling this function to yield the thread, and wait for this to resume it again.
]=]
function Module.resumeAfterFirst(
	...: RBXScriptSignal | Tween | Sound | AnimationTrack | (
	) -> ()
		| {
			Once: ((any, () -> ()) -> { Disconnect: (any) -> () })?,
			Connect: (any, () -> ()) -> { Disconnect: (any) -> () },
		}
)
	local args = { ... }

	local currentThread = coroutine.running()
	local function tryResume()
		task.spawn(currentThread)
	end

	local connections = {} :: { any }

	for i, v in args do
		if type(v) == 'function' then
			continue
		elseif type(v) == 'table' then
			if v.Once then
				connections[i] = v:Once(tryResume)
			else
				local connection
				connection = v:Connect(function()
					connection:Disconnect()
					tryResume()
				end)
			end
		elseif typeof(v) == 'RBXScriptSignal' then
			connections[i] = v:Once(tryResume)
		elseif v:IsA 'Tween' then
			connections[i] = v.Completed:Once(tryResume)
		elseif v:IsA 'Sound' then
			connections[i] = v.Ended:Once(tryResume)
		elseif v:IsA 'AnimationTrack' then
			connections[i] = v.Ended:Once(tryResume)
		else
			connections[i] = v:Once(tryResume)
		end
	end

	for i, v in args do
		if type(v) == 'table' or typeof(v) == 'RBXScriptSignal' then
			continue
		elseif type(v) == 'function' then
			connections[i] = task.defer(function()
				v()
				tryResume()
			end)
		else
			v:Play()
		end
	end

	return table.unpack(connections)
end

--[=[
	Calls `added` when a player is added, and calls `removing` when a player is removing.
	If `added` is specified, returns the `PlayerAdded` connection as the first return value.
	If `removing` is specified, returns the `PlayerRemoving` connection as the second return value.
]=]
function Module.player(added: (Player) -> ()?, removing: (Player) -> ()?): (RBXScriptConnection?, RBXScriptConnection?)
	local removingConnection: RBXScriptConnection?
	if removing then
		removingConnection = Players.PlayerRemoving:Connect(removing)
	end

	local addedConnection: RBXScriptConnection?
	if added then
		addedConnection = Players.PlayerAdded:Connect(added)

		for _, player in Players:GetPlayers() do
			added(player)
		end
	end

	return addedConnection, removingConnection
end

--[=[
	Yields until each child instance in the `prefab` Model is present in the character.
	If `prefab` is not passed, uses the `StarterPlayer.StarterCharacter` if present.
	Will error if the passed character doesn't belong to a player.
]=]
function Module.yieldUntilAppearanceLoaded(character: Model, prefab: Model?)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		error(
			`{if typeof(character) == 'Instance' then character:GetFullName() else tostring(character)} is not a character of any Player!`
		)
	end

	local characterPrefab = prefab or StarterCharacter
	if characterPrefab then
		for _, child in characterPrefab:GetChildren() do
			character:WaitForChild(child.Name)
		end
		return
	end

	if not player:HasAppearanceLoaded() then
		player.CharacterAppearanceLoaded:Wait()
	end
end

--[=[
	Calls `added` whenever the player's character appearance has loaded, and calls `removing` whenever the player's character is being removed.
	If `added` is specified, returns the `CharacterAdded` connection as the first return value.
	If `removing` is specified, returns the `CharacterRemoving` connection as the second return value.
]=]
function Module.appearance(
	player: Player,
	added: (character: Model, player: Player) -> ()?,
	removing: (character: Model, player: Player) -> ()?
)
	local removingConnection: RBXScriptConnection?
	if removing then
		removingConnection = player.CharacterRemoving:Connect(function(character)
			removing(character, player)
		end)
	end

	local addedConnection: RBXScriptConnection?
	if added then
		local function callAdded(character)
			Module.yieldUntilAppearanceLoaded(character)
			added(character, player)
		end

		addedConnection = player.CharacterAdded:Connect(callAdded)

		local character = player.Character
		if character then
			callAdded(character)
		end
	end

	return addedConnection, removingConnection
end

--[=[
	Calls `added` whenever the player's character is added, and calls `removing` whenever the player's character is being removed.
	If `added` is specified, returns the `CharacterAdded` connection as the first return value.
	If `removing` is specified, returns the `CharacterRemoving` connection as the second return value.
]=]
function Module.character(
	player: Player,
	added: (character: Model, player: Player) -> ()?,
	removing: (character: Model, player: Player) -> ()?
): (RBXScriptConnection?, RBXScriptConnection?)
	local removingConnection: RBXScriptConnection?
	if removing then
		removingConnection = player.CharacterRemoving:Connect(function(character)
			removing(character, player)
		end)
	end

	local addedConnection: RBXScriptConnection?
	if added then
		addedConnection = player.CharacterAdded:Connect(function(character)
			added(character, player)
		end)

		local character = player.Character
		if character then
			added(character, player)
		end
	end

	return addedConnection, removingConnection
end

--[=[
	Calls `added` once a Humanoid exists under the character, and calls `removing` *once* when either the Humanoid dies or is removed.
	If `removing` is provided, returns the removed and death connections in order.
	Will error if the passed character doesn't belong to a player.
]=]
function Module.humanoid(
	character: Model,
	added: (humanoid: Humanoid, character: Model, player: Player) -> ()?,
	removing: (humanoid: Humanoid, character: Model, player: Player) -> ()?
): (RBXScriptConnection?, RBXScriptConnection?)
	local player = Players:GetPlayerFromCharacter(character)
	if not player then
		error(
			`{if typeof(character) == 'Instance' then character:GetFullName() else tostring(character)} is not a character of any Player!`
		)
	end

	local humanoid = character:WaitForChild 'Humanoid' :: Humanoid
	if added then
		added(humanoid, character, player)
	end

	local diedConnection: RBXScriptConnection?, removedConnection: RBXScriptConnection?
	if removing then
		diedConnection = humanoid.Died:Once(function()
			(removedConnection :: RBXScriptConnection):Disconnect()
			removing(humanoid, character, player)
		end)

		--? Not using the parent parameter because humanoid.Parent == workspace.My_Character, but parent == workspace. Terrible, I don't know why this happens.
		removedConnection = humanoid.AncestryChanged:Connect(function()
			if humanoid.Parent ~= character then
				(diedConnection :: RBXScriptConnection):Disconnect();
				(removedConnection :: RBXScriptConnection):Disconnect()
				removing(humanoid, character, player)
			end
		end)
	end

	return removedConnection, diedConnection
end

--[=[
	Listens for a tag being added to and removed from instances.
	The `added` callback is called with every tagged instance immediately.
	If `added` is specified, returns the `InstanceAdded` connection as the first return value.
	If `removing` is specified, returns the `InstanceRemoved` connection as the second return value.
]=]
function Module.tag(tag: string, added: (Instance) -> ()?, removed: (Instance) -> ()?)
	local removedConnection: RBXScriptConnection?
	if removed then
		removedConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(removed)
	end

	local addedConnection: RBXScriptConnection?
	if added then
		addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(added)
		for _, tagged in CollectionService:GetTagged(tag) do
			added(tagged)
		end
	end

	return addedConnection, removedConnection
end

--[=[
	Listens for the specified tag being added to and removed from the instance.
	The `added` callback is called immediately if the tag is present on the instance.
	If `added` is specified, returns the `InstanceAdded` connection as the first return value.
	If `removing` is specified, returns the `InstanceRemoved` connection as the second return value.
]=]
function Module.tagInstance(instance: Instance, tag: string, added: (Instance) -> ()?, removed: (Instance) -> ()?)
	local removedConnection: RBXScriptConnection?
	if removed then
		removedConnection = CollectionService:GetInstanceRemovedSignal(tag):Connect(function(other)
			if other == instance then
				removed(instance)
			end
		end)
	end

	local addedConnection: RBXScriptConnection?
	if added then
		addedConnection = CollectionService:GetInstanceAddedSignal(tag):Connect(function(other)
			if other == instance then
				added(instance)
			end
		end)

		for _, tagged in CollectionService:GetTagged(tag) do
			added(tagged)
		end
	end

	return addedConnection, removedConnection
end

--[=[
	Listens for the specified property being changed on the instance.
	The value from the last time the property was changed is passed to the callback.
	The callback is called with the current value immediately (passing the current value for the old one), unless `skip` is set to true.
]=]
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

--[=[
	Listens for the specified attribute being changed on the instance.
	The value from the last time the attribute was changed is passed to the callback.
	The callback is called with the current value immediately (passing the current value for the old one), unless `skip` is set to true.
]=]
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

--[=[
	Listens for any attribute being changed on the instance.
	The value from the last time an attribute was changed is passed to the callback.
	The callback is called with the current value of every attribute immediately (passing the current value for the old one), unless `skip` is set to true.
]=]
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

--[=[
	Listens for the Value instance being changed.
	The value from the last time the `Changed` event fired is passed to the callback.
	The callback is called with the current value immediately (passing the current value for the old one), unless `skip` is set to true.
]=]
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

--[=[
	Recursively disconnects all connections in the table. Removes all entries except for nested tables.
	Warning: If the table contains a yielding function, this function will yield!
]=]
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

--[=[
	Similar to `clean`, but removes nested tables.
	Warning: If the table contains a yielding function, this function will yield!
]=]
function Module.empty(connections: { [any]: Connection })
	Module.clean(connections)
	table.clear(connections)
end

--[=[
	Calls `clean` on the value at the specified keys. Does nothing if the value is nil.
	Does not remove the connection if it's a nested table.
	Warning: If the table contains a yielding function, this function will yield!
]=]
function Module.cleanKeys<T...>(connections: { [any]: Connection }, ...: T...)
	-- Type ... as generic so user code gets a warning when it doesn't specify the parameter
	-- However, don't give the `connections` table an indexer of `[T]`, since that screws with
	-- the type inference of tables passed to this function

	for _, key: any in table.pack(...) do
		local connection = connections[key]
		if type(connection) == 'table' and type(connection.Disconnect) ~= 'function' then
			Module.clean(connection :: { [any]: Connection })
		elseif connection then
			disconnect(connection)
			connections[key] = nil
		end
	end
end

--[=[
	Similar to `cleanKeys`, but removes the connection regardless of if it's a nested table.
	Warning: If the table contains a yielding function, this function will yield!
]=]
function Module.emptyKeys<T...>(connections: { [any]: Connection }, ...: T...)
	Module.cleanKeys(connections, ...)
	for _, key: any in table.pack(...) do
		connections[key] = nil
	end
end

export type Connection = any

return Module
