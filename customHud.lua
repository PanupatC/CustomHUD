_addon.author   = 'Syllendel (Syll#3694)';
_addon.name     = 'customHud';
_addon.version  = '0.25';

require 'common'
require 'd3d8'
require 'imguidef'
require 'timer'

-- Config
local config = {}

-- Buff organization
local groups = {}
local greyed = {}
--local greyedGroupPH = {}
local self = nil
local debuffs = {}
local ignored = {}
local showUngroupedBuffs = true

-- Hold buffs of party
local playersBuffs = {}
local playersDebuffs = {}

-- Hold textures
local images = {}
local cursor = {}
local subcursor = {}

-- Constants
local jobs = {"war", "mnk", "whm", "blm", "rdm", "thf", "pld", "drk", "bst", "brd", "rng", "sam", "nin", "drg", "smn", "blu", "cor", "pup", "dnc", "sch", "geo", "run"}

-- Other local variables
local loaded = false

local refreshCurrentPlayer = false
local refreshAlignement = false

local debug = false
local locked = true
local hide = false

local cursorFrame = 1
local cursorIndex = 1
local subcursorFrame = 1
local subcursorIndex = 1
local numberPartyMembers
local widthPerMember
local posXForCenterAlignment = 0

----------------------------------------------------------------------------------------------------
-- func: load
----------------------------------------------------------------------------------------------------
ashita.register_event('load', function()
	-- If there is a specific theme for that job, use this one instead
	local jobId = AshitaCore:GetDataManager():GetPlayer():GetMainJob()
	
	if(jobId == 0) then
		ashita.timer.create("delayedLoadTimer", 2, 0, onLoad);
		ashita.timer.start_timer("delayedLoadTimer");
	else
		onLoad()
	end
	
end);

function onLoad()	
	local jobId = AshitaCore:GetDataManager():GetPlayer():GetMainJob()
	if(jobId == 0) then
		return
	end
	
	ashita.timer.stop("delayedLoadTimer")

	-- Load the settings
	config = ashita.settings.load_merged(_addon.path .. "\settings.json", config)
	-- Get the amount of party members
	numberPartyMembers = AshitaCore:GetDataManager():GetParty():GetAllianceParty0MemberCount()
	
	-- If there is a specific theme for that job, use this one instead
	-- if(config.groupsPerJob[jobs[jobId]] ~= nil and config.groupsPerJob[jobs[jobId]].theme ~= nil) then
	-- 	config.theme = config.groupsPerJob[jobs[jobId]].theme;
	-- end

	if(config.groupsPerJob[jobs[jobId]] ~= nil and config.groupsPerJob[jobs[jobId]].hpp ~= nil) then
		config.hpp = config.groupsPerJob[jobs[jobId]].hpp;
	end
	
	loadAddonConfiguration(jobId)
	
	loaded = true
end

function loadAddonConfiguration(jobId)
	groups = {}
	greyed = {}
	--greyedGroupPH = {}
	
	images = {}
	
	self = nil
	
	local jobConfig = getJobConfig(jobId)
	
	-- Groups 
	if(jobConfig.groups ~= nil) then
		loadGroupsFromConfig(jobConfig, groups)
	else
		print("No custom grouping rules")
	end
	
	if(jobConfig.show_ungrouped_buffs ~= nil) then
		showUngroupedBuffs = jobConfig.show_ungrouped_buffs
	else
		showUngroupedBuffs = true
	end
	
	-- Greyed
	if(jobConfig.greyed ~= nil) then
		for i, greyedBuff in ipairs(jobConfig.greyed)do
			--if(type(greyedBuff) == "string") then
				--print(config.buffCategories[greyedBuff][1])
			--	greyed[config.buffCategories[greyedBuff][1]] = true
			--else
				greyed[greyedBuff] = true
			--end
		end
	else
		print("No custom greyed rules")
	end
	
	-- Greyed group config
	--[[
	if(jobConfig.greyedGroupPlaceholder ~= nil) then
		for greyedGroup, ph in pairs(jobConfig.greyedGroupPlaceholder) do
			print("Group " .. greyedGroup .. " ph: " .. ph)
			greyedGroupPH[greyedGroup] = ph
		end
	end
	--]]
	
	-- Self only
	if (jobConfig.self ~= nil) then
		self = {}
		-- Groups
		if(jobConfig.self.groups ~= nil) then
			self.groups = {}
			loadGroupsFromConfig(jobConfig.self, self.groups)
		end
		
		-- Greyed
		if(jobConfig.self.greyed ~= nil) then
			self.greyed = {}
			for i, greyedBuff in ipairs(jobConfig.self.greyed)do
				--if(type(greyedBuff) == "string") then
					--print(config.buffCategories[greyedBuff][1])
				--	self.greyed[config.buffCategories[greyedBuff][1]] = true
				--else
					self.greyed[greyedBuff] = true
				--end
			end
		end
		
		-- Greyed group PH
		--[[
		if(jobConfig.self.greyedGroupPlaceholder ~= nil) then
			self.greyedGroupPH = {}
			for greyedGroup, ph in pairs(jobConfig.self.greyedGroupPlaceholder) do
				print("self-Group " .. greyedGroup .. " ph: " .. ph)
				self.greyedGroupPH[greyedGroup] = ph
			end
		end
		--]]
	end
	
	-- Debuffs List
	for i, buffId in ipairs(config.debuffList)do
		--print("Debuff: " .. buffId)
		debuffs[buffId] = true
	end
	
	-- Ignore List
	for i, buffId in ipairs(config.ignoreList)do
		--print("Debuff: " .. buffId)
		ignored[buffId] = true
	end
	
	config.hpp = checkJobHpp()

	-- Load the UI images
	-- if(ashita.file.dir_exists(_addon.path .. "themes\\" .. config.theme)) then
	-- 	loadTheme(config.theme)
	-- else
	-- 	print("Folder " .. _addon.path .. "themes\\" .. config.theme .. " does not exist, using default theme.")
	-- 	loadTheme("default")
	-- end
	loadTheme("default")


	
	-- Update current player buffs
	updateCurrentPlayerBuffs()
end

function getJobConfig(jobId)
	if config.groupsPerJob[jobs[jobId]] ~= nil then
		print("Custom config found for " .. jobs[jobId])
		return config.groupsPerJob[jobs[jobId]]
	else
		print("Using default groups config")
		return config.groupsPerJob["default"]
	end
end

function checkJobHpp()
	mainjob = AshitaCore:GetDataManager():GetPlayer():GetMainJob()
	subjob = AshitaCore:GetDataManager():GetPlayer():GetSubJob()
	-- 14=DRG, 3=WHM, 5=RDM,7=PLD, 16=BLU, 20=SCH
	if (mainjob == 14) then
		if (subjob==3 or subjob==5 or
		    subjob==7 or subjob==16 or subjob==20) then
				return true
		end
	end
	return false
end

function loadGroupsFromConfig(jobConfig, groups)
	-- Check if there is a custom grouping for the main job
	for x, group in ipairs(jobConfig.groups) do
		groups[x] = {}

		indexCount = 1
		for y, value in ipairs(group) do
			-- If alias (i.e songs)
			if(type(value) == "string") then
				for z, subValue in ipairs(config.buffCategories[value]) do
					--print("groups[" .. x .. "][" .. subValue .. "] = true")
					groups[x][indexCount] = subValue
					indexCount = indexCount + 1
				end
			else
				--print("groups[" .. x .. "][" .. value .. "] = true")
				groups[x][indexCount] = value
				indexCount = indexCount + 1
			end
		end
	end
end

function loadTheme(theme)
	print("Using theme: " .. theme)
	local path = _addon.path .. "themes\\" .. theme
	
	config.ui = {}
	config.ui = ashita.settings.load_merged(path .. "\\theme_settings.json", config.ui)
	
	-- Gauges
	if(config.ui.gauges.hp ~= nil) then
		if(config.ui.gauges.hp.background ~= nil) then
			loadImage("background_hp", path .. "\\gauges\\" .. config.ui.gauges.hp.background)
		end
		loadImage("hp", path .. "\\gauges\\" .. config.ui.gauges.hp.filled)
	end
	
	if(config.ui.gauges.mp ~= nil) then
		if(config.ui.gauges.mp.background ~= nil) then
			loadImage("background_mp", path .. "\\gauges\\" .. config.ui.gauges.mp.background)
		end
		loadImage("mp", path .. "\\gauges\\" .. config.ui.gauges.mp.filled)
	end
	
	if(config.ui.gauges.tp ~= nil) then
		-- Background
		if(config.ui.gauges.tp.background ~= nil) then
			loadImage("background_tp", path .. "\\gauges\\" .. config.ui.gauges.tp.background)
		end
		
		-- Filled
		if(config.ui.gauges.tp.filled2 ~= nil and config.ui.gauges.tp.filled3 ~= nil) then
			loadImage("tp1", path .. "\\gauges\\" .. config.ui.gauges.tp.filled)
			loadImage("tp2", path .. "\\gauges\\" .. config.ui.gauges.tp.filled2)
			loadImage("tp3", path .. "\\gauges\\" .. config.ui.gauges.tp.filled3)
		else
			loadImage("tp", path .. "\\gauges\\" .. config.ui.gauges.tp.filled)
		end
		
		-- Milestones
		if(config.ui.gauges.tp.milestones ~= nil) then
			if(config.ui.gauges.tp.milestones["1000"] ~= nil) then
				loadImage(config.ui.gauges.tp.milestones["1000"].image, path .. "\\gauges\\" .. config.ui.gauges.tp.milestones["1000"].image)
			end
			
			if(config.ui.gauges.tp.milestones["2000"] ~= nil) then
				loadImage(config.ui.gauges.tp.milestones["2000"].image, path .. "\\gauges\\" .. config.ui.gauges.tp.milestones["2000"].image)
			end
			
			if(config.ui.gauges.tp.milestones["3000"] ~= nil) then
				loadImage(config.ui.gauges.tp.milestones["3000"].image, path .. "\\gauges\\" .. config.ui.gauges.tp.milestones["1000"].image)
			end
		end

	end
	
	-- Font
	if(config.ui.font ~= nil) then
		for x=0, 9 do
			loadImage(tostring(x), path .. "\\font\\" .. x .. "." .. config.ui.font.format)
			if config.ui.font.has_small_version == true then
				loadImage(x .. "small", path .. "\\font\\" .. x .. "small." .. config.ui.font.format)
			end
		end
		
		if (config.ui.gauges.name ~= nil) then
			local alphabet = string.lower('ABCDEFGHIJKLMNOPQRSTUVWXYZ')
			for x=1, 26 do
				local letter = alphabet:sub(x,x)
				loadImage(letter, path .. "\\font\\" .. letter .. "." .. config.ui.font.format)
				loadImage(letter .. "_maj", path .. "\\font\\" .. letter .. "_maj." .. config.ui.font.format)
			end
			loadImage("ellipsis", path .. "\\font\\" .. "ellipsis" .. "." .. config.ui.font.format)
			loadImage("-", path .. "\\font\\" .. "-" .. "." .. config.ui.font.format)
			loadImage("'", path .. "\\font\\" .. "'" .. "." .. config.ui.font.format)
			loadImage("(", path .. "\\font\\" .. "(" .. "." .. config.ui.font.format)
			loadImage(")", path .. "\\font\\" .. ")" .. "." .. config.ui.font.format)
			loadImage("space", path .. "\\font\\" .. "space" .. "." .. config.ui.font.format)
			loadImage("%", path .. "\\font\\" .. "percent" .. "." .. config.ui.font.format)
			loadImage(".", path .. "\\font\\" .. "dot" .. "." .. config.ui.font.format)
		end
	end
	
	-- Cursor
	if(config.ui.cursor ~= nil) then
		cursor["width"], cursor["height"] = getImageDimensions(path .. "\\cursor\\1." .. config.ui.cursor.format)
		for x=1, config.ui.cursor.number_images do
			cursor[x] = createTexture(path .. "\\cursor\\" .. x .. "." .. config.ui.cursor.format, cursor["width"], cursor["height"])
			subcursor[x] = createTexture(path .. "\\cursor\\sub" .. x .. "." .. config.ui.cursor.format, cursor["width"], cursor["height"])
		end
	end
	
	-- Player info 
	-- Background
	if(config.ui.player_info ~= nil and config.ui.player_info.background_image ~= nil) then
		loadImage("playerBackground", path .. "\\players\\" .. config.ui.player_info.background_image)
	end
	
	-- Job Icons
	if(config.ui.player_info ~= nil and config.ui.player_info.job_icon ~= nil) then
		for x=1, 22 do
			loadImage("job" .. x, path .. "\\players\\" .. jobs[x] .. "." .. config.ui.player_info.job_icon.format)
		end
	end
	
	-- Calculate width if the theme require X alignement at center
	if (config.ui.distance_between_players.align_x_center == true) then
		widthPerMember = getWidthPerMember()
		posXForCenterAlignment = calculatePosXForCenterAlignment()
	end

	if (config.ui.hpp == nil) then
		config.ui.hpp = {[width] = 40}
	end
end

function loadImage(element, path)
	-- Only load if the image isn't already loaded
	if(images[element] ~= nil) then
		return
	end

	local width, height = getImageDimensions(path)
	
	images[element] = {}
	images[element]["width"] = width
	images[element]["height"] = height
	images[element]["texture"] = createTexture(path, width, height);
end

function getImageDimensions(path)
	-- Credit to https://sites.google.com/site/nullauahdark/getimagewidthheight
	local file = io.open(path)
	
	if(file == nil) then
		print("File " .. path .. " doesn't exist.")
	end
	
	local width,height=0,0
	
	local function refresh()
		if type(fileinfo)=="number" then
			file:seek("set",fileinfo)
		else
			file:close()
		end
	end
	
	-- PNG
	file:seek("set",1)
	if file:read(3)=="PNG" then
		file:seek("set",16)
		local widthstr,heightstr=file:read(4),file:read(4)
		if type(fileinfo)=="number" then
			file:seek("set",fileinfo)
		else
			file:close()
		end
		width=widthstr:sub(1,1):byte()*16777216+widthstr:sub(2,2):byte()*65536+widthstr:sub(3,3):byte()*256+widthstr:sub(4,4):byte()
		height=heightstr:sub(1,1):byte()*16777216+heightstr:sub(2,2):byte()*65536+heightstr:sub(3,3):byte()*256+heightstr:sub(4,4):byte()
		return width,height
	end
	file:seek("set")
	
	-- BMP
	if file:read(2)=="BM" then
		file:seek("set",18)
		local widthstr,heightstr=file:read(4),file:read(4)
		refresh()
		width=widthstr:sub(4,4):byte()*16777216+widthstr:sub(3,3):byte()*65536+widthstr:sub(2,2):byte()*256+widthstr:sub(1,1):byte()
		height=heightstr:sub(4,4):byte()*16777216+heightstr:sub(3,3):byte()*65536+heightstr:sub(2,2):byte()*256+heightstr:sub(1,1):byte()
		return width,height
	end
	
	-- JPG/JPEG
	file:seek("set")
	if file:read(2)=="\255\216" then
		local lastb,curb=0,0
		local xylist={}
		local sstr=file:read(1)
		while sstr~=nil do
			lastb=curb
			curb=sstr:byte()
			if (curb==194 or curb==192) and lastb==255 then
				file:seek("cur",3)
				local sizestr=file:read(4)
				local h=sizestr:sub(1,1):byte()*256+sizestr:sub(2,2):byte()
				local w=sizestr:sub(3,3):byte()*256+sizestr:sub(4,4):byte()
				if w>width and h>height then
					width=w
					height=h
				end
			end
			sstr=file:read(1)
		end
		if width>0 and height>0 then
			refresh()
			return width,height
		end
	end
end

function createTexture(path, width, height)
	local res, texture = ashita.d3dx.CreateTextureFromFileA(path);
	--local res, _, _, texture = ashita.d3dx.CreateTextureFromFileExA(path, width, height, 1, 0, D3DFMT_A8R8G8B8, 1, 0xFFFFFFFF, 0xFFFFFFFF, 0xFF000000);
	
	if (res ~= 0) then
		local _, err = ashita.d3dx.GetErrorStringA(res);
        print(string.format('[Error] Failed to load background texture for slot: %s - Error: (%08X) %s', path, res, err));
        return nil;
	end

	return texture;
end

function getWidthPerMember()
	-- Find width of UI element of a party member to calculate X and center the ui later
	-- Calculate width of the window
	local maxWidth = 0
	
	-- Check baground
	if(config.ui.player_info ~= nil) then
		local width = 0
		
		-- Background
		if (config.ui.player_info.background_image ~= nil) then
			width = images["playerBackground"]["width"]
			if(width > maxWidth) then
				maxWidth = width
			end
		end
		
		-- Job Icon and Text?
	end
	
	-- Check HP
	if(config.ui.gauges.hp ~= nil) then
		local width = 0
		
		-- Background
		if (config.ui.gauges.hp.background ~= nil) then
			width = config.ui.gauges.hp.position_from_player_origin.x + images["background_hp"]["width"]
			if(width > maxWidth) then
				maxWidth = width
			end
		end
		
		-- Gauge
		width = config.ui.gauges.hp.position_from_player_origin.x + images["hp"]["width"]
		if (config.ui.gauges.hp.padding_background_filled ~= nil) then
			width = width + config.ui.gauges.hp.padding_background_filled.x
		end
	end
	
	-- Check MP
	if(config.ui.gauges.mp ~= nil) then
		local width = 0
		
		-- Background
		if (config.ui.gauges.mp.background ~= nil) then
			width = config.ui.gauges.mp.position_from_player_origin.x + images["background_mp"]["width"]
			if(width > maxWidth) then
				maxWidth = width
			end
		end
		
		-- Gauge
		width = config.ui.gauges.mp.position_from_player_origin.x + images["mp"]["width"]
		if (config.ui.gauges.mp.padding_background_filled ~= nil) then
			width = width + config.ui.gauges.mp.padding_background_filled.x
		end
	end
	
	-- Check TP
	if(config.ui.gauges.tp ~= nil) then
		local width = 0
		
		-- Background
		if (config.ui.gauges.tp.background ~= nil) then
			width = config.ui.gauges.tp.position_from_player_origin.x + images["background_tp"]["width"]
			if(width > maxWidth) then
				maxWidth = width
			end
		end
		
		-- Gauge
		if(config.ui.gauges.tp.filled2 == nil) then
			width = config.ui.gauges.tp.position_from_player_origin.x + images["tp"]["width"]
			if (config.ui.gauges.tp.padding_background_filled ~= nil) then
				width = width + config.ui.gauges.tp.padding_background_filled.x
			end
			if(width > maxWidth) then
				maxWidth = width
			end
		else
			width = config.ui.gauges.tp.position_from_player_origin.x + images["tp1"]["width"]
			if (config.ui.gauges.tp.padding_background_filled ~= nil) then
				width = width + config.ui.gauges.tp.padding_background_filled.x
				if(width > maxWidth) then
					maxWidth = width
				end
			end
			
			width = config.ui.gauges.tp.position_from_player_origin.x + images["tp2"]["width"]
			if (config.ui.gauges.tp.padding_background_filled2 ~= nil) then
				width = width + config.ui.gauges.tp.padding_background_filled2.x
				if(width > maxWidth) then
					maxWidth = width
				end
			end
			
			width = config.ui.gauges.tp.position_from_player_origin.x + images["tp3"]["width"]
			if (config.ui.gauges.tp.padding_background_filled3 ~= nil) then
				width = width + config.ui.gauges.tp.padding_background_filled3.x
				if(width > maxWidth) then
					maxWidth = width
				end
			end
		end
	end
	
	return maxWidth
end

function calculatePosXForCenterAlignment()
	-- Get middle of the screen
	local posX = 1920 / 2
	
	-- Adjust to players UI width
	posX =  posX - widthPerMember * (numberPartyMembers/2)
	
	-- Adjust to margin between players
	posX = posX - (config.ui.distance_between_players.x-widthPerMember) * ((numberPartyMembers-1)/2)
	
	-- Manual adjustement (in case )
	if (config.ui.distance_between_players.x_adjustement ~= nil) then
		posX = posX + config.ui.distance_between_players.x_adjustement
	end
	
	return posX
end

---------------------------------------------------------------------------------------------------
-- func: outgoing_packet
-- desc: Called when our addon receives an outgoing packet.
---------------------------------------------------------------------------------------------------
ashita.register_event('outgoing_packet', function(id, size, packet)
	-- Job change
	if(id == 0x100) then
		--{ctype='unsigned char', label='Main Job'}, -- 04
		local mainJob = struct.unpack('B', packet, 0x04 + 1);
		
		config.theme = "default"
		-- If main job changed, reload the addon configuration
		if(mainJob ~= 0 and mainJob ~= AshitaCore:GetDataManager():GetPlayer():GetMainJob()) then
			-- If there is a specific theme for that job
			-- if(config.groupsPerJob[jobs[mainJob]] ~= nil and config.groupsPerJob[jobs[mainJob]].theme ~= nil) then
			-- 	config.theme = config.groupsPerJob[jobs[mainJob]].theme;
			-- else
			-- 	config.theme = "default"
			-- end
			
			loadAddonConfiguration(mainJob)
		end
	end
	
	return false
end);



---------------------------------------------------------------------------------------------------
-- func: incoming_packet
---------------------------------------------------------------------------------------------------
ashita.register_event('incoming_packet', function(id, size, packet)
	-- Current player update
	if(id == 0x037) then
		-- Flag to refresh the current player before rendering
		-- If it was done directly Ashita wouldn't have processed the changes in buffs yet
		refreshCurrentPlayer = true
		return false;
	end	
	
	-- Zone of party structure update
	if (id == 0x0C8 or id == 0x0A) then
		refreshAlignement = true
		return false
	end
	
	-- Party members buffs update
	if (id == 0x76) then
		for x = 0, 4, 1 do
			partyMemberServerId = struct.unpack('I', packet, x * 0x30 + 0x04 + 1);
			updatePartyMemberBuffs(x, partyMemberServerId, packet)
		end
	end

	return false;
end);

function updateCurrentPlayerBuffs()
	local buffs = AshitaCore:GetDataManager():GetPlayer():GetBuffs();
	currentPlayerServerId = AshitaCore:GetDataManager():GetParty():GetMemberServerId(0)
	
	playersBuffs[currentPlayerServerId] = {}
	playersDebuffs[currentPlayerServerId] = {}
	
	-- Loop the buffs
	for k, v in pairs(buffs) do
		addBuffToPlayer(currentPlayerServerId, v)
	end
end

function updatePartyMemberBuffs(x, partyMemberServerId, packet)
	playersBuffs[partyMemberServerId] = {}
	playersDebuffs[partyMemberServerId] = {}

	-- Loop the buffs contained in the packet
	for i = 0, 31, 1 do
	
		local mask = bit.band(bit.rshift(struct.unpack('b', packet, bit.rshift(i, 2) + (x * 0x30 + 0x0C) + 1), 2 * (i % 4)), 3);
		if (struct.unpack('b', packet, (x * 0x30 + 0x14) + i + 1) ~= -1 or mask > 0) then
		
			local buffId = bit.bor(struct.unpack('B', packet, (x * 0x30 + 0x14) + i + 1), bit.lshift(mask, 8));
			addBuffToPlayer(partyMemberServerId, buffId)
			
		end
		
	end
end

function addBuffToPlayer(playerServerId, buffId)
	-- Check if the buff is valid and not ignored
	if buffId == nil or buffId < 1 or ignored[buffId] == true then
		return
	end
	
	-- Debuff
	if(debuffs[buffId] == true) then
		if (playersDebuffs[playerServerId][buffId] == nil) then
			playersDebuffs[playerServerId][buffId] = 1
		else
			playersDebuffs[playerServerId][buffId] = playersDebuffs[playerServerId][buffId] + 1
		end
	
	-- Buff
	else					
		if (playersBuffs[playerServerId][buffId] == nil) then
			playersBuffs[playerServerId][buffId] = 1
		else
			playersBuffs[playerServerId][buffId] = playersBuffs[playerServerId][buffId] + 1
		end
	end
end

----------------------------------------------------------------------------------------------------
-- func: render
----------------------------------------------------------------------------------------------------
ashita.register_event('render', function()
	if (loaded == false) then
		return
	end

    local party = AshitaCore:GetDataManager():GetParty();
    if (party:GetMemberActive(0) == false or party:GetMemberServerId(0) == 0) then
		hide = true
        return;
	else
		hide = false
	end

	-- Refresh current player's buffs if necessary
	if (refreshCurrentPlayer == true) then
		refreshCurrentPlayer = false;
		updateCurrentPlayerBuffs()
	end
	
	if (refreshAlignement == true and config.ui.distance_between_players.align_x_center == true) then
		local ptMembersCount = AshitaCore:GetDataManager():GetParty():GetAllianceParty0MemberCount()
		if (ptMembersCount ~= numberPartyMembers) then
			refreshAlignement = false
			numberPartyMembers = ptMembersCount
			posXForCenterAlignment = calculatePosXForCenterAlignment()
			
		end
	end
	
	-- Create the window
	local flags = ImGuiWindowFlags_AlwaysAutoResize + ImGuiWindowFlags_NoTitleBar
	if locked == true then
		flags = flags + ImGuiWindowFlags_NoInputs
	end
	
	-- Don't display if chat window expanded and option is set in config
	if (hideHUD() == true) then
		imgui.Begin(
			'customHud.default',
			nil, -- bool p_open?
			1, 1, -- Size on first use?
			0, -- Background Alpha
			flags  -- Flags
		)
		imgui.End()
		return
	end
	
	imgui.Begin(
		'customHud.default',
		nil, -- bool p_open?
		1, 1, -- Size on first use?
		config.ui.background_alpha, -- Background Alpha
		flags  -- Flags
	)
	
	-- Global Background image
	if (config.ui.background_image ~= nil) then
		imgui.SetCursorPos(1, 0)
		imgui.Image(images["background"]["texture"]:Get(), 
			images["background"]["width"], images["background"]["height"], -- Size
			0, 0, -- UV
			1, 1, -- UV1
			1, 1, 1, 1 -- Color
		)
	end
	
	-- Center on X if required
	if (config.ui.distance_between_players.align_x_center == true and posXForCenterAlignment ~= nil) then
		local posX, posY = imgui.GetWindowPos()
		imgui.SetWindowPos(posXForCenterAlignment, posY)
	end



	-- For each player of the party
	target_id = AshitaCore:GetDataManager():GetTarget():GetTargetServerId()
	st_index = GetStPartyIndex()
	for x = 0, 5 do
		local playerServerId = AshitaCore:GetDataManager():GetParty():GetMemberServerId(x)
		
		if (playerServerId > 0) then
			local playerStartPositionX = 1 + x * config.ui.distance_between_players.x -- On the X axis not adding 1 cause the first row of pixel to be out of the frame
			local playerStartPositionY = x * config.ui.distance_between_players.y
			-- +5 to make room for moving text upwards
			playerStartPositionY = playerStartPositionY + config.ui.target_gauge["y"] + 5

			-- Player Background image
			if (images["playerBackground"] ~= nil) then
				imgui.SetCursorPos(playerStartPositionX, playerStartPositionY)
				imgui.Image(images["playerBackground"]["texture"]:Get(), 
					images["playerBackground"]["width"], images["playerBackground"]["height"], -- Size
					0, 0, -- UV
					1, 1, -- UV1
					1, 1, 1, 1 -- Color
				)
			end
		
			-- If the player is targeted draw the cursor
			if (config.ui.cursor ~= nil) then
				local xCursorOffset = 0
				local yCursorOffset = 0
				if ( config.ui.cursor.position_from_player_origin ~= nil) then
					xCursorOffset = config.ui.cursor.position_from_player_origin.x
					yCursorOffset = config.ui.cursor.position_from_player_origin.y
				end
				
				use_cursor = nil
				if (st_index ~= nil and st_index == x) then
					use_cursor = subcursor
				elseif playerServerId == target_id then
					use_cursor = cursor
				end
				if (use_cursor ~= nil) then
					drawCursor(playerStartPositionX + xCursorOffset, playerStartPositionY + yCursorOffset, use_cursor)
				end

				if(config.ui.cursor.gap_with_gauges ~= nil) then
					playerStartPositionX = playerStartPositionX + cursor["width"] + config.ui.cursor.gap_with_gauges
				end
			end	
			
			-- HP, MP and TP gauges
			drawGauge(playerStartPositionX, playerStartPositionY, "hp", AshitaCore:GetDataManager():GetParty():GetMemberCurrentHPP(x)/100)
			drawGauge(playerStartPositionX,  playerStartPositionY, "mp",  AshitaCore:GetDataManager():GetParty():GetMemberCurrentMPP(x)/100)
			if(images["tp2"] == nil) then
				drawGauge(playerStartPositionX, playerStartPositionY, "tp", AshitaCore:GetDataManager():GetParty():GetMemberCurrentTP(x)/3000)
			else
				drawTPTripleFill(playerStartPositionX, playerStartPositionY, AshitaCore:GetDataManager():GetParty():GetMemberCurrentTP(x))
			end
			
			-- HP, MP and TP numbers
			drawNumbers(playerStartPositionX, playerStartPositionY, "mp", AshitaCore:GetDataManager():GetParty():GetMemberCurrentMP(x), GetMemberName)
			drawNumbers(playerStartPositionX, playerStartPositionY, "hp", AshitaCore:GetDataManager():GetParty():GetMemberCurrentHP(x), AshitaCore:GetDataManager():GetParty():GetMemberCurrentHPP(x))
			drawNumbers(playerStartPositionX, playerStartPositionY, "tp", AshitaCore:GetDataManager():GetParty():GetMemberCurrentTP(x), AshitaCore:GetDataManager():GetParty():GetMemberCurrentTP(x)/30)
			drawMilestones(playerStartPositionX, playerStartPositionY, AshitaCore:GetDataManager():GetParty():GetMemberCurrentTP(x))
			
			-- Player Info
			-- Name
			drawName(playerStartPositionX, playerStartPositionY, AshitaCore:GetDataManager():GetParty():GetMemberName(x))
			
			-- Job Icons
			if (config.ui.player_info ~= nil and config.ui.player_info.job_icon ~= nil) then
				local jobId =  AshitaCore:GetDataManager():GetParty():GetMemberMainJob(x)
				if(jobId > 0) then
					imgui.SetCursorPos(playerStartPositionX + config.ui.player_info.job_icon.position_from_player_origin.x, playerStartPositionY + config.ui.player_info.job_icon.position_from_player_origin.y)
					imgui.Image(images["job" .. jobId]["texture"]:Get(), 
						images["job" .. jobId]["width"], images["job" .. jobId]["height"], -- Size
						0, 0, -- UV
						1, 1, -- UV1
						1, 1, 1, 1 -- Color
					)
				end
			end
			
			-- Buffs and debuffs
			if x == 0 then
				drawBuffs(playerStartPositionX, playerStartPositionY, playerServerId, true)
			else
				drawBuffs(playerStartPositionX, playerStartPositionY, playerServerId, false)
			end
			drawDebuffs(playerStartPositionX, playerStartPositionY, playerServerId)
			
		end
	end
	
	-- if (config.targetBar) then
	gconfig = config.ui.target_gauge
	if (config.target_gauge == true) then
		local target = AshitaCore:GetDataManager():GetTarget();
		local party = AshitaCore:GetDataManager():GetParty();

		
		if (gconfig.name == nil or gconfig.name.display == nil or config.ui.gauges.name.display == false) then
			-- skip per config value
		elseif (target:GetTargetEntityPointer() == nil or
			target:GetTargetName() == '' or
			target:GetTargetServerId() == 0 or
			target:GetTargetServerId() == party:GetMemberServerId(0)) then
				-- skip when self is targetted
		else
			tid = target:GetTargetServerId()
			if (tid ~= nil) then
				local tentity = GetEntity(target:GetTargetIndex());
				if (tentity ~= nil) then
					spawn = tentity.SpawnFlags
					if (spawn==1 or spawn==13 or spawn==16) then
						-- 1=Player, 13=PT member, 16=Monster
						name = tentity.Name
						hpp = tentity.HealthPercent
						distance = string.format('%.1f', math.sqrt(tentity.Distance))

						
						x = cursor["width"] + config.ui.cursor.gap_with_gauges
						y = 5
						drawGauge(x, y, "hp", hpp/100)

						-- calculate position here instead of in function
						if (gconfig["name"]["display"]) then
							
							if(gconfig.name.x ~= nil) then
								tmpX = x + gconfig.name.x
							end
							if(gconfig.name.y ~= nil) then
								tmpY = y + gconfig.name.y
							end
							drawText(tmpX,tmpY,name)
						end

						if (gconfig["hpp"]["display"]) then
							if(gconfig.hpp.x ~= nil) then
								tmpX = x + gconfig.hpp.x
							end
							if(gconfig.hpp.y ~= nil) then
								tmpY = y + gconfig.hpp.y
							end
							text = tostring(hpp).."%"
							drawText(tmpX,tmpY,text)
						end

						if (gconfig["distance"]["display"]) then
							if(gconfig.distance.x ~= nil) then
								tmpX = x + gconfig.distance.x
							end
							if(gconfig.distance.y ~= nil) then
								tmpY = y + gconfig.distance.y
							end
							drawText(tmpX,tmpY,distance)
						end
					end
				end
			end

		end
	end

	
	imgui.End()
	
end);

function hideHUD()
	if hide == true then
		return true
	end
	
	if (config.ui.hide_when_expand_chat ~= nil) then
		-- Config specific to the theme
		if (config.ui.hide_when_expand_chat == true) then
			return isExpandedChat()
		end
	else
		-- Config by default
		if (config.hide_when_expand_chat_default_behavior ~= nil and config.hide_when_expand_chat_default_behavior == true) then
				return isExpandedChat()
		end
	
	end
	
	return false
end

function isExpandedChat()
	local pattern = "83EC??B9????????E8????????0FBF4C24??84C0"
	local patternAddress = ashita.memory.findpattern("FFXiMain.dll", 0, pattern, 0x04, 0);
	local chatExpandedPointer = ashita.memory.read_uint32(patternAddress)+0xF1
	local chatExpandedValue = ashita.memory.read_uint8(chatExpandedPointer)
	
	return chatExpandedValue ~= 0
end

function drawCursor(cursorX, cursorY, cursor_to_use)
	cursor_to_use = cursor_to_use or cursor
	imgui.SetCursorPos(cursorX, cursorY)
	
	imgui.Image(cursor_to_use[cursorIndex]:Get(), 
		cursor["width"], cursor["height"], -- Size
		0, 0, -- UV
		1, 1, -- UV1
		1, 1, 1, config.ui.cursor.alpha -- Color
	)
	
	if(cursorFrame == config.ui.cursor.change_after_x_frames) then
		cursorFrame = 1
		if cursorIndex == config.ui.cursor.number_images then
			cursorIndex = 1
		else
			cursorIndex = cursorIndex + 1
		end
	else
		cursorFrame = cursorFrame + 1
	end

end

function drawGauge(cursorX, cursorY, gaugeType, ratio)
	-- If no gauge definition
	if(config.ui.gauges[gaugeType] == nil) then
		return
	end
	
	if(config.ui.gauges[gaugeType].position_from_player_origin ~= nil) then
		cursorX = cursorX + config.ui.gauges[gaugeType].position_from_player_origin.x
		cursorY = cursorY + config.ui.gauges[gaugeType].position_from_player_origin.y
	end

	-- Background
	if(config.ui.gauges[gaugeType].background ~= nil) then
		imgui.SetCursorPos(cursorX, cursorY)
		imgui.Image(images["background_" .. gaugeType]["texture"]:Get(),
			images["background_" .. gaugeType]["width"], images["background_" .. gaugeType]["height"],
			0, 0,
			1, 1
		)
		
		cursorX = cursorX + config.ui.gauges[gaugeType].padding_background_filled.x
		cursorY = cursorY + config.ui.gauges[gaugeType].padding_background_filled.y
	end
	
	imgui.SetCursorPos(cursorX, cursorY)
	imgui.Image(images[gaugeType]["texture"]:Get(),
		images[gaugeType]["width"] * ratio, images[gaugeType]["height"],
		0, 0,
		ratio, 1
	)
end

function drawTPTripleFill(cursorX, cursorY, tp)
	if tp >= 1000 then
		tp = (tp-1000)/2 + 2000
	end
	
	if(config.ui.gauges.tp.position_from_player_origin ~= nil) then
		cursorX = cursorX + config.ui.gauges.tp.position_from_player_origin.x
		cursorY = cursorY + config.ui.gauges.tp.position_from_player_origin.y
	end
	
	imgui.SetCursorPos(cursorX, cursorY)
	imgui.Image(images["background_tp"]["texture"]:Get(),
		images["background_tp"]["width"], images["background_tp"]["height"],
		0, 0,
		1, 1,
		1, 1, 1, 1,
		0, 0, 0, 0
	)
	
	-- Draw first bar
	for x = 1, 3 do
		local ratio = getRatio(x, tp)
		
		if(ratio == 0) then
			return
		end
		
		if(config.ui.gauges.tp["padding_background_filled" .. x] ~= nil) then
			imgui.SetCursorPos(cursorX + config.ui.gauges.tp["padding_background_filled" .. x].x, cursorY + config.ui.gauges.tp["padding_background_filled" .. x].y)
		else
			-- Use default padding
			imgui.SetCursorPos(cursorX + config.ui.gauges.tp.padding_background_filled.x, cursorY + config.ui.gauges.tp.padding_background_filled.y)
		end
		
		imgui.Image(images["tp"..x]["texture"]:Get(),
		images["tp"..x]["width"] * ratio, images["tp"..x]["height"],
			0, 0,
			ratio, 1
		)
	end
end

function getRatio(x, tp)	
	if (tp <= (x-1)*1000) then
		return 0
	end
	
	if (tp >= x*1000) then
		return 1
	end
	
	return (tp-((x-1)*1000))/1000
end

function drawMilestones(cursorX, cursorY, tp)
	if (config.ui.gauges.tp == nil or config.ui.gauges.tp.milestones == nil) then
		return
	end
	
	if (tp == 3000) then
		drawMilestone(cursorX, cursorY, config.ui.gauges.tp.milestones["3000"])
		
		if (config.ui.gauges.tp.milestones.display_only_highest == true) then
			return;
		end
	end
	
	if (tp >= 2000) then
		drawMilestone(cursorX, cursorY, config.ui.gauges.tp.milestones["2000"])
		
		if (config.ui.gauges.tp.milestones.display_only_highest == true) then
			return;
		end
	end
	
	if(tp >= 1000) then
		drawMilestone(cursorX, cursorY, config.ui.gauges.tp.milestones["1000"])
	end
	
end

function drawMilestone(cursorX, cursorY, milestoneConfig)
	if(milestoneConfig == nil) then
		return;
	end
	
	imgui.SetCursorPos(cursorX + milestoneConfig.position_from_player_origin.x, cursorY + milestoneConfig.position_from_player_origin.y)
	imgui.Image(images[milestoneConfig.image]["texture"]:Get(), 
		images[milestoneConfig.image]["width"], images[milestoneConfig.image]["height"]
	)
end

function drawName(cursorX, cursorY, name)
	if (name == nil) or (name == "") then
		return
	end
	

	-- If no definition for name or explictly asked to not display
	if (config.ui.gauges.name == nil or config.ui.gauges.name.display == nil or config.ui.gauges.name.display == false) then
		return
	end

	if(config.ui.gauges.name.position_from_player_origin ~= nil) then
		cursorX = cursorX + config.ui.gauges.name.position_from_player_origin.x
		cursorY = cursorY + config.ui.gauges.name.position_from_player_origin.y
	end
	
	imgui.SetCursorPos(cursorX, cursorY)
	imgui.Text("")
	
	local nbLetter = 0
	for c in name:gmatch(".") do
		if (config.ui.gauges.name.max_letters ~= nil) then
			nbLetter = nbLetter +1
			
			-- Too many letters, display the dots and break
			if (nbLetter > config.ui.gauges.name.max_letters) then
				imgui.SameLine(0, 0)
				imgui.Image(images["ellipsis"]["texture"]:Get(), 
					images["ellipsis"]["width"], images["ellipsis"]["height"], -- Size
					0, 0, -- UV
					1, 1, -- UV1
					1, 1, 1, 1 -- Color
				)
				break
			end
			
		end
		
		if string.match(c, "%u") then
			c = c:lower().."_maj"
		end
	
		imgui.SameLine(0, 0)
		imgui.Image(images[c]["texture"]:Get(), 
			images[c]["width"], images[c]["height"], -- Size
			0, 0, -- UV
			1, 1, -- UV1
			1, 1, 1, 1 -- Color
		)
	end
	
end

function drawText(x, y, text)
	gconfig = config.ui.target_gauge

	imgui.SetCursorPos(x, y)
	imgui.Text("")
	
	local nbLetter = 0
	for c in text:gmatch(".") do
		if (gconfig.name.max_letters ~= nil) then
			nbLetter = nbLetter +1
			-- Trucate if longer than max_letters
			if (nbLetter > gconfig.name.max_letters) then
				imgui.SameLine(0, 0)
				imgui.Image(images["ellipsis"]["texture"]:Get(), 
					images["ellipsis"]["width"], images["ellipsis"]["height"], -- Size
					0, 0, -- UV
					1, 1, -- UV1
					1, 1, 1, 1 -- Color
				)
				break
			end
		end
		
		if string.match(c, "%u") then
			c = c:lower().."_maj"
		end
		if (c == " ") then
			c = "space"
		end
		imgui.SameLine(0, 0)
		imgui.Image(images[c]["texture"]:Get(), 
			images[c]["width"], images[c]["height"], -- Size
			0, 0, 1, 1, -- UV
			1, 1, 1, 1 -- Color
		)
	end
end



function drawNumbers(cursorX, cursorY, gaugeType, value, ratio)
	-- If no definition for numbers or explictly asked to not display
	if (config.ui.gauges[gaugeType] == nil or config.ui.gauges[gaugeType].numbers == nil or config.ui.gauges[gaugeType].numbers.display == false) then
		return
	end
	
	local r,g,b,a = getColor(config.ui.gauges[gaugeType].numbers.color, ratio)

	local cursorX = cursorX + config.ui.gauges[gaugeType].numbers.position_relative_to_gauge.x
	local cursorY = cursorY + config.ui.gauges[gaugeType].numbers.position_relative_to_gauge.y
	
	if(config.ui.gauges[gaugeType].position_from_player_origin ~= nil) then
		cursorX = cursorX + config.ui.gauges[gaugeType].position_from_player_origin.x
		cursorY = cursorY + config.ui.gauges[gaugeType].position_from_player_origin.y
	end
	
	if(config.ui.gauges[gaugeType].numbers.align_right == true) then
		-- Deduce text size from cursorX
		for c in tostring(value):gmatch(".") do
			if(config.ui.gauges[gaugeType].numbers.small == true) then
				c = c.."small"
			end
			cursorX = cursorX - images[c]["width"]
		end
	end
	if (config.hpp == true and gaugeType == "hp") then
		cursorX = cursorX - config.ui.hpp["width"]
	end
	imgui.SetCursorPos(cursorX, cursorY)
	imgui.Text("")
	
	-- Draw the numbers images
	for c in tostring(value):gmatch(".") do
		imgui.SameLine(0, 0)
		
		if(config.ui.gauges[gaugeType].numbers.small == true) then
			c = c.."small"
		end
		
		imgui.Image(images[c]["texture"]:Get(), 
			images[c]["width"], images[c]["height"], -- Size
			0, 0, -- UV
			1, 1, -- UV1
			r, g, b, a -- Color
		)

		cursorX = cursorX + images[c]["width"]
	end

	-- if(gaugeType == "hp" and config.ui.gauges.hp.hpp == true and ratio) then
	if(gaugeType == "hp" and config.hpp == true and ratio) then
		cursorX = cursorX + 5
		cursorY = cursorY + 2
		imgui.SetCursorPos(cursorX, cursorY)
		imgui.Text("")
		r,g,b,a = 1,1,1,1
		
		c = "("
		imgui.SameLine(0, 0)
		imgui.Image(
			images[c]["texture"]:Get(), 
			images[c]["width"], images[c]["height"], -- Size
			0, 0, -- UV
			1, 1, -- UV1
			r, g, b, a -- Color
		)

		for c in tostring(ratio):gmatch(".") do
			c = c.."small"
			imgui.SameLine(0, 0)
			imgui.Image(
				images[c]["texture"]:Get(), 
				images[c]["width"], images[c]["height"], -- Size
				0, 0, -- UV
				1, 1, -- UV1
				r, g, b, a -- Color
			)
		end
		
		c = ")"
		imgui.SameLine(0, 0)
		imgui.Image(
			images[c]["texture"]:Get(), 
			images[c]["width"], images[c]["height"], -- Size
			0, 0, -- UV
			1, 1, -- UV1
			r, g, b, a -- Color
		)

	end
end

function getColor(colorConfig, amount)
	local r = 1
	local g = 1
	local b = 1
	local a = 1
	
	if(colorConfig == nil) then
		return r,g,b,a
	end
	
	for ratio, color in pairs(colorConfig) do
		if amount <= tonumber(ratio) then
			if(colorConfig[ratio].a == nil) then
				return colorConfig[ratio].r, colorConfig[ratio].g, colorConfig[ratio].b, a
			else
				return colorConfig[ratio].r, colorConfig[ratio].g, colorConfig[ratio].b, colorConfig[ratio].a
			end
		end
	end
	
	return r,g,b,a
end

function drawBuffs(cursorX, cursorY, playerServerId, isSelf)
	if playersBuffs[playerServerId] == nil or config.ui.buffs == nil then
		return;
	end
	
	local groupsToCheck = groups
	local greyedToCheck = greyed
	if isSelf == true and self ~= nil then
		if(self.groups ~= nil) then
			groupsToCheck = self.groups
		end
		if(self.greyed ~= nil) then
			greyedToCheck = self.greyed
		end
	end
	
	cursorX = cursorX + config.ui.buffs.buffs_position_from_player_origin.x
	cursorY = cursorY + config.ui.buffs.buffs_position_from_player_origin.y
	
	imgui.SetCursorPos(cursorX, cursorY)
	imgui.Text("")
	
	-- The list of buffs displayed in groups
	displayedBuffs= {}
	
	-- Loop over the groups
	lastGroupEmpty = true;
	drawSeparator = false;
	for x, group in ipairs(groupsToCheck) do
		-- Show buff separator
		if(lastGroupEmpty == false) then
			drawSeparator = true
		end
		
		-- Loop over the buffs in the current group
		for index, buffId in ipairs(groupsToCheck[x]) do
			
			-- Check if the player has the buff
			if(playersBuffs[playerServerId][buffId] ~= nil) then
				if(drawSeparator == true) then
					imgui.SameLine(0,1)
					imgui.Text("|")
					drawSeparator = false
				end
			
				lastGroupEmpty = false
				displayedBuffs[buffId] = true
				
				-- Draw the buff for each occurence of it (i.e different level of a same song have the same buffId)
				for y = 1, playersBuffs[playerServerId][buffId] do
					imgui.SameLine(0,1)
					drawBuffIcon(buffId)
					
					if(debug) then
					imgui.SameLine(0, 1)
					imgui.TextColored(0,1,0,1,buffId)
				end
				end
			
			-- If the player doesn't have it and the buff must appear greyed
			elseif(greyedToCheck[buffId] == true) then
				if(drawSeparator == true) then
					imgui.SameLine(0,1)
					imgui.Text("|")
					drawSeparator = false
				end
				
				lastGroupEmpty = false
				imgui.SameLine(0,1)
				drawBuffIcon(buffId, true)
			end
		end
	end
	
	-- If desired display the ungrouped buffs
	if showUngroupedBuffs == true then
		-- Loop over the buffs on the player
		for buffId, amount in pairs(playersBuffs[playerServerId]) do
			-- If the buff isn't displayed already
			if (not displayedBuffs[buffId] == true) then
			
				-- Show buff separator (only once) if something was drawn before
				if(lastGroupEmpty == false) then
					imgui.SameLine(0,1)
					imgui.Text("|")
					lastGroupEmpty = true
				end
				
				for x=1, amount do
					imgui.SameLine(0,1)
					drawBuffIcon(buffId)
				
					if(debug) then
						imgui.SameLine(0, 1)
						imgui.TextColored(0,1,0,1,buffId)
					end
				end
			end
		end
	end
	
end

function drawDebuffs(cursorX, cursorY, playerServerId)
	if playersDebuffs[playerServerId] == nil or config.ui.buffs == nil or config.ui.buffs.debuffs_position_from_player_origin == nil then
		return;
	end
	
	cursorX = cursorX + config.ui.buffs.debuffs_position_from_player_origin.x
	cursorY = cursorY + config.ui.buffs.debuffs_position_from_player_origin.y
	
	imgui.SetCursorPos(cursorX, cursorY)
	imgui.Text("")
	
	-- Loop over the debuffs on the player
	for buffId, amount in pairs(playersDebuffs[playerServerId]) do
		imgui.SameLine(0,1)
		drawBuffIcon(buffId)
		
		if(debug) then
			imgui.SameLine(0, 1)
			imgui.TextColored(0,1,0,1,buffId)
		end
	end
	
end

function drawBuffIcon(buffId, greyed)
	-- If image not loaded
	if(images[buffId] == nil) then
		-- Load image
		images[buffId] = createTexture(_addon.path .. "themes\\icons\\" .. buffId .. "." .. config.ui.buffs.format, config.ui.buffs.icon_size, config.ui.buffs.icon_size);
	end
	
	if(greyed == true) then
		imgui.Image(images[buffId]:Get(), 
			config.ui.buffs.icon_size, config.ui.buffs.icon_size, -- Size
			0, 0, -- UV
			1, 1, -- UV1
			1, 1, 1, .2 -- Color
		)
	else
		imgui.Image(images[buffId]:Get(), 
			config.ui.buffs.icon_size, config.ui.buffs.icon_size
		)
	end
end

---------------------------------------------------------------------------------------------------
-- func: command
---------------------------------------------------------------------------------------------------
ashita.register_event('command', function(cmd, nType)
	-- Ensure we should handle this command..
    local args = cmd:args()
	
	if (#args == 0 ) then
		return false;
	end
	
    if (string.lower(args[1]) ~= '/customhud' and string.lower(args[1]) ~= '/hud') then
        return false;
    end
	

	if (#args == 2) then
		local cmd = string.lower(args[2])
		
		if (cmd == 'debug') then
			-- Toggle debug on/off
        	debug = not debug

		elseif (cmd == 'lock' or cmd == 'locked') then
			-- Toggle position locked on/off
			locked = not locked
			if(locked == true) then
				print("HUD position locked")
			else
				print("You can now move the HUD with left click")
			end

		elseif (cmd == 'buffs' or cmd == 'ungrouped') then
			-- Toggle display of non grouped buffs
			showUngroupedBuffs = not showUngroupedBuffs
			if(showUngroupedBuffs == true) then
				print("Ungrouped buffs will be shown")
			else
				print("Ungrouped buffs will be hidden")
			end

		elseif (cmd == "hide") then
			hide = not hide
				
		elseif (cmd == 'hpp') then
			config.hpp = not config.hpp
			if (config.hpp == true) then
				print("Disabling HPP")
			else
				print("Enabling HPP")
			end

		elseif (cmd == "tg") then
			config.target_gauge = not config.target_gauge
			if (config.target_gauge == true) then
				print("Enabling target gauge")
			else
				print("Disabling target gauge")
			end

		elseif (cmd == "x") then
			test()

		else
			return false;
		end

		return true;
    end

	return false;


end);

function GetStPartyIndex()
    local ptr = AshitaCore:GetPointerManager():GetPointer('party');
    ptr = ashita.memory.read_uint32(ptr);
    ptr = ashita.memory.read_uint32(ptr);
    local isActive = (ashita.memory.read_uint32(ptr + 0x54) ~= 0);
    if isActive then
        return ashita.memory.read_uint8(ptr + 0x50);
    else
        return nil;
    end
end

function test(x)
	-- print(AshitaCore:GetDataManager():GetTarget():GetSubTargetServerId())
	-- print(AshitaCore:GetDataManager():GetTarget():GetTargetServerId())
	print(GetStPartyIndex())
	-- x = x or "nothing"
	-- print(x)
	-- mainjob = AshitaCore:GetDataManager():GetPlayer():GetMainJob()
	-- subjob = AshitaCore:GetDataManager():GetPlayer():GetSubJob()
	-- print(mainjob)
	-- print(subjob)
	-- 14=DRG, 3=WHM, 5=RDM,7=PLD, 16=BLU, 20=SCH
	-- target = AshitaCore:GetDataManager():GetTarget();
	-- tentity = GetEntity(target:GetTargetIndex());
	-- print(tentity.SpawnFlags)
end

