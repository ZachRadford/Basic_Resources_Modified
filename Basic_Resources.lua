Basic_Resources = {}

local c = select(2, UnitClass('player'))
local spellGCD

if c == 'ROGUE' then
	spellGCD = 145424 -- Cheap Shot
elseif c == 'DRUID' then
	spellGCD = 768 -- Cat Form
elseif c == 'PALADIN' then
	spellGCD = 31801 -- Seal of Truth
elseif c == 'MONK' then
	spellGCD = 100780 -- Jab
elseif c == 'WARRIOR' then
	spellGCD = 5308 -- Execute
elseif c == 'HUNTER' then
	spellGCD = 3044 -- Arcane Shot
else
    DisableAddOn('Basic_Resources')
    return
end

SLASH_Basic_Resources1, SLASH_Basic_Resources2 = '/bres', '/cres'

local function InitializeVariables()
	for k, v in pairs({ -- defaults
		locked = false,
		always = false,
		scale = 1,
		frequency = 0.01,
		hide_spec = 0,
		gcd = true,
		cpalert = 0,
		hpalert = 0
	}) do
		if Basic_Resources[k] == nil then
			Basic_Resources[k] = v
		end
	end
end

local events = {}

local pointBar = {
	points = {},
	width = 168,
	height = 11,
	max = 0
}

local backDrop = {
    bgFile = 'Interface\\Addons\\Basic_Resources\\white16x16',
    edgeFile = 'Interface\\Addons\\Basic_Resources\\white16x16',
    edgeSize = 1,
    tile = true,
    tileSize = 16
}

local lastUpdate, lastPower = 0, 0
local updaterFrame = CreateFrame('Frame', nil, UIParent)
updaterFrame:SetPoint('TOPLEFT', -1, 1)
updaterFrame:SetSize(0, 0)
local pointFrame = CreateFrame('Frame', 'Basic_PointFrame', UIParent)
pointFrame:SetFrameStrata('BACKGROUND')
pointFrame:SetPoint('CENTER', 0, -222)
pointFrame:SetSize(pointBar.width, pointBar.height)
pointFrame:RegisterForDrag('LeftButton')
pointFrame:SetScript('OnDragStart', pointFrame.StartMoving)
pointFrame:SetScript('OnDragStop', pointFrame.StopMovingOrSizing)
pointFrame:SetMovable(true)
pointFrame:Hide()
for i = 1, 7 do
	pointBar.points[i] = CreateFrame('Frame', nil, pointFrame)
	pointBar.points[i]:SetFrameStrata('BACKGROUND')
	pointBar.points[i]:SetBackdrop(backDrop)
end
local powerFrame = CreateFrame('Frame', 'Basic_PowerFrame', UIParent)
powerFrame:SetFrameStrata('BACKGROUND')
powerFrame:SetPoint('TOPLEFT', pointFrame, 'BOTTOMLEFT', 0, -3)
powerFrame:SetSize(168, 11)
powerFrame:SetBackdrop(backDrop)
powerFrame:SetBackdropColor(0, 0, 0, 0.4)
powerFrame:SetBackdropBorderColor(0, 0, 0, 0.6)
powerFrame:Hide()
local powerBar = CreateFrame('Frame', nil, powerFrame)
powerBar:SetFrameStrata('BACKGROUND')
powerBar:SetPoint('LEFT', 1, 0)
powerBar:SetHeight(9)
powerBar:SetBackdrop(backDrop)
local powerText = powerBar:CreateFontString(nil, 'OVERLAY')
powerText:SetFont('Fonts\\FRIZQT__.TTF', 8, '')
powerText:SetShadowOffset(1, -1)
powerText:SetShadowColor(0, 0, 0, 0.8)
powerText:SetPoint('CENTER', powerFrame)
local pointText = powerBar:CreateFontString(nil, 'OVERLAY')
pointText:SetFont('Fonts\\FRIZQT__.TTF', 8, '')
pointText:SetShadowOffset(1, -1)
pointText:SetShadowColor(0, 0, 0, 0.8)
pointText:SetPoint('CENTER', pointFrame)
local gcdFrame = CreateFrame('Frame', 'Basic_GCDFrame', UIParent)
gcdFrame:SetFrameStrata('BACKGROUND')
gcdFrame:SetPoint('BOTTOMLEFT', pointFrame, 'TOPLEFT', 0, 3)
gcdFrame:SetHeight(4)
gcdFrame:SetBackdrop(backDrop)
gcdFrame:SetBackdropColor(0, 0, 0, 0.4)
gcdFrame:SetBackdropBorderColor(0, 0, 0, 0.6)
gcdFrame:Hide()

function pointBar:setMax(m)
	if self.max ~= m then
		self.max = m
		local pointWidth
		if m > 0 then
			pointWidth = (self.width - (m - 1) * 2) / m
		end
		for i = 1, #self.points do
			if i <= m then
				self.points[i]:SetSize(pointWidth, self.height)
				self.points[i]:SetPoint('LEFT', pointFrame, 'LEFT', (i - 1) * (pointWidth + 2), 0)
				self.points[i]:Show()
			else
				self.points[i]:Hide()
			end
		end
	end
end

function GetBuffInfo(spellId)
	local _, id, count, expires
	for i = 1, 40 do
		_, _, _, count, _, _, expires, _, _, _, id = UnitAura('player', i, 'PLAYER|HELPFUL')
		if id == spellId then
			return count, expires
		end
	end
	return 0, 0
end

local function GetDebuffInfo(spellId)
	local _, id, count, expires
	for i = 1, 40 do
		_, _, _, count, _, _, expires, _, _, _, id = UnitAura('target', i, 'PLAYER|HARMFUL')
		if id == spellId then
			return count, expires
		end
	end
	return 0, 0
end

local function UpdatePointBar()
	if c == 'DRUID' and UnitPowerType('player') == 1 then
		local stacks, expires = GetDebuffInfo(33745)
		pointBar:setMax(3)
		pointText:Show()
		for i = 1, 3 do
			if (stacks or 0) >= i then
				pointBar.points[i]:SetBackdropColor(0.73, 0.46, 0.4, 1)
				pointBar.points[i]:SetBackdropBorderColor(0.6, 0, 0, 1)
			else
				pointBar.points[i]:SetBackdropColor(0, 0, 0, 0.6)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.4)
			end
		end
		pointText:SetText(stacks > 0 and format('%.1fs', expires - GetTime()))
	elseif c == 'PALADIN' then
		local power, powerMax = UnitPower('player', 9), UnitPowerMax('player', 9)
		pointBar:setMax(powerMax)
		for i = 1, powerMax do
			if power >= i then
				pointBar.points[i]:SetBackdropColor(0.8, 0.8, 0, 1)
				pointBar.points[i]:SetBackdropBorderColor(0.9, 0.9, 0.1, 1)
				if Basic_Resources.hpalert > 0 and i == Basic_Resources.hpalert and lastPower == i - 1 then
					PlaySoundFile('Interface\\Addons\\Basic_Resources\\sounds\\' .. math.random(1, 11) .. '.mp3', 'Master')
				end
			else
				pointBar.points[i]:SetBackdropColor(0, 0, 0, 0.6)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.4)
			end
		end
		lastPower = power
	elseif c == 'ROGUE' or (c == 'DRUID' and UnitPowerType('player') == 3) then
		local points, anticipation = UnitPower('player', 4)
		pointBar:setMax(5)
		pointText:Hide()
		if anticipation == nil then 
			anticipation = 0
		end
		if c == 'ROGUE' and points > 5 then
			anticipation = points - 5
			points = 5
		end
		for i = 1, 5 do
			if c == 'ROGUE' and points == 5 and anticipation >= i then
				pointBar.points[i]:SetBackdropColor(0, 0.35, 0.6, 1)
				pointBar.points[i]:SetBackdropBorderColor(0.2, 0.8, 1, 1)
			elseif points >= i then
				pointBar.points[i]:SetBackdropColor(0.6, 0, 0, 1)
				pointBar.points[i]:SetBackdropBorderColor(0.8, 0.8, 0.1, 1)
			else
				pointBar.points[i]:SetBackdropColor(0, 0, 0, 0.6)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.4)
			end
		end
		if Basic_Resources.cpalert > 0 and points == Basic_Resources.cpalert and lastPower == points - 1 then
			PlaySoundFile('Interface\\Addons\\Basic_Resources\\sounds\\' .. math.random(1, 11) .. '.ogg', 'Master')
		end
		lastPower = points
	elseif c == 'MONK' then
		local chi, chiMax = UnitPower('player', 12), UnitPowerMax('player', 12)
		pointBar:setMax(chiMax)
		for i = 1, chiMax do
			if chi >= i then
				pointBar.points[i]:SetBackdropColor(0, 0.85, 0.6, 1)
				pointBar.points[i]:SetBackdropBorderColor(0, 0.55, 0.4, 1)
			else
				pointBar.points[i]:SetBackdropColor(0, 0, 0, 0.6)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.4)
			end
		end
	elseif c == 'WARRIOR' and GetSpecialization() == 2 then
		local enhancedWhirlwind = IsPlayerSpell(157473)
		local ragingBlowCharges = (GetBuffInfo(131116))
		local wildStrikeCharges = (GetBuffInfo(46916))
		local meatCleaverCharges = (GetBuffInfo(85739))
		if enhancedWhirlwind then
			meatCleaverCharges = meatCleaverCharges / 2
		end
		pointBar:setMax(enhancedWhirlwind and 6 or 7)
		for i = 1, 2 do
			if ragingBlowCharges >= i then
				pointBar.points[i]:SetBackdropColor(0.7, 0, 0, 1)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.6)
			else
				pointBar.points[i]:SetBackdropColor(0, 0, 0, 0.6)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.4)
			end
		end
		for i = 3, 4 do
			if wildStrikeCharges >= i - 2 then
				pointBar.points[i]:SetBackdropColor(0.4, 0.4, 0.4, 1)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.6)
			else
				pointBar.points[i]:SetBackdropColor(0, 0, 0, 0.6)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.4)
			end
		end
		for i = 5, pointBar.max do
			if meatCleaverCharges >= i - 4 then
				pointBar.points[i]:SetBackdropColor(0.3, 0.7, 0.8, 1)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.6)
			else
				pointBar.points[i]:SetBackdropColor(0, 0, 0, 0.6)
				pointBar.points[i]:SetBackdropBorderColor(0, 0, 0, 0.4)
			end
		end
	elseif pointBar.max ~= 0 then
		pointBar:setMax(0)
		pointText:Hide()
	end
end

local function UpdatePowerBar()
	local resource = UnitPower('player')
	if resource == 0 then
		powerBar:DisableDrawLayer('BACKGROUND')
		powerBar:DisableDrawLayer('BORDER')
	else
		if UnitPowerType('player') == 3 then
			powerBar:SetBackdropColor(0.7, 0.7, 0, 1)
			powerBar:SetBackdropBorderColor(0.8, 0.8, 0.1, 1)
		elseif UnitPowerType('player') == 1 then
			powerBar:SetBackdropColor(0.7, 0, 0, 1)
			powerBar:SetBackdropBorderColor(0.8, 0.1, 0.1, 1)
		elseif UnitPowerType('player') == 2 then
			powerBar:SetBackdropColor(0.5, 0.2, 0.1, 1)
			powerBar:SetBackdropBorderColor(0.6, 0.3, 0.2, 1)
		else
			powerBar:SetBackdropColor(0, 0, 0.7, 1)
			powerBar:SetBackdropBorderColor(0.1, 0.1, 0.8, 1)
		end
		powerBar:SetWidth(166 * (resource / UnitPowerMax('player')))
		powerBar:EnableDrawLayer('BACKGROUND')
		powerBar:EnableDrawLayer('BORDER')
	end
	powerText:SetText(resource .. '/' .. UnitPowerMax('player'))
end

local function UpdateGCDBar()
	local gcdStart, gcdDuration = GetSpellCooldown(spellGCD)
	if gcdStart ~= 0 then
		gcdFrame:SetWidth(168 - 168 * ((GetTime() - gcdStart) / gcdDuration))
		gcdFrame:EnableDrawLayer('BACKGROUND')
		gcdFrame:EnableDrawLayer('BORDER')
	else
		gcdFrame:DisableDrawLayer('BACKGROUND')
		gcdFrame:DisableDrawLayer('BORDER')
	end
end

function events:UNIT_COMBO_POINTS()
    UpdatePointBar()
end

function events:ADDON_LOADED(name)
	if name == 'Basic_Resources' then
		InitializeVariables()
		gcdFrame:SetScale(Basic_Resources.scale)
		pointFrame:SetScale(Basic_Resources.scale)
		powerFrame:SetScale(Basic_Resources.scale)
		pointFrame:EnableMouse(not Basic_Resources.locked)
	end
end

function events:ACTIVE_TALENT_GROUP_CHANGED(spec)
	if Basic_Resources.hide_spec == spec then
		updaterFrame:Hide()
		gcdFrame:Hide()
		pointFrame:Hide()
		powerFrame:Hide()
	else
		updaterFrame:Show()
	end
end

function events:PLAYER_ENTERING_WORLD()
	events:ACTIVE_TALENT_GROUP_CHANGED(GetActiveSpecGroup())
end

updaterFrame:SetScript('OnUpdate', function(self, elapsed)
    lastUpdate = lastUpdate + elapsed
    if lastUpdate >= Basic_Resources.frequency then
		if (Basic_Resources.always or UnitCanAttack('player', 'target')) then
			if Basic_Resources.gcd then
				UpdateGCDBar()
				gcdFrame:Show()
			end
			UpdatePointBar()
			pointFrame:Show()
			UpdatePowerBar()
			powerFrame:Show()
		elseif powerFrame:IsVisible() then
			gcdFrame:Hide()
			pointFrame:Hide()
			powerFrame:Hide()
		end
        lastUpdate = 0
    end
end)

updaterFrame:SetScript('OnEvent', function(self, event, ...) events[event](self, ...) end)
for k in pairs(events) do
    updaterFrame:RegisterEvent(k)
end

function SlashCmdList.Basic_Resources(msg, editbox)
    msg = { strsplit(' ', strlower(msg)) }
	if msg[1] == 'locked' then
        if msg[2] then Basic_Resources.locked = msg[2] == 'on' end
		pointFrame:EnableMouse(not Basic_Resources.locked)
        print('Basic Resources - Locked: ' .. (Basic_Resources.locked and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'scale' then
		Basic_Resources.scale = tonumber(msg[2]) or 1
		gcdFrame:SetScale(Basic_Resources.scale)
		pointFrame:SetScale(Basic_Resources.scale)
		powerFrame:SetScale(Basic_Resources.scale)
		print('Basic Resources - Scale set to: |cFFFFD000' .. Basic_Resources.scale .. '|r times')
	elseif msg[1] == 'frequency' then
		Basic_Resources.frequency = tonumber(msg[2]) or 0.01
		print('Basic Resources - Update frequency: Every |cFFFFD000' .. Basic_Resources.frequency .. '|r seconds')
	elseif msg[1] == 'always' then
        if msg[2] then Basic_Resources.always = msg[2] == 'on' end
        print('Basic Resources - Always shown: ' .. (Basic_Resources.always and '|cFF00C000On' or '|cFFC00000Off'))
	elseif msg[1] == 'hidespec' then
        if msg[2] then
			local spec = tonumber(msg[2]) or 0
			if spec >= 0 and spec <= 2 then
				Basic_Resources.hide_spec = spec
				events:ACTIVE_TALENT_GROUP_CHANGED(GetActiveSpecGroup())
			end
		end
        print('Basic Resources - Hide in specialization: |cFFFFD000' .. (Basic_Resources.hide_spec == 0 and 'None' or Basic_Resources.hide_spec))
	elseif msg[1] == 'gcd' then
		if msg[2] then
			Basic_Resources.gcd = msg[2] == 'on'
			if not Basic_Resources.gcd then
				gcdFrame:Hide()
			end
		end
		print('Basic Resources - Global cooldown bar: ' .. (Basic_Resources.gcd and '|cFF00C000On' or '|cFFC00000Off'))
	elseif (c == 'DRUID' or c == 'ROGUE') and msg[1] == 'cpalert' then
		if msg[2] then Basic_Resources.cpalert = msg[2] == 'off' and 0 or tonumber(msg[2]) or 5 end
		print('Basic Resources - Alert at: ' .. (Basic_Resources.cpalert > 0 and '|cFFFFD000' .. Basic_Resources.cpalert .. '|r combo points' or '|cFFC00000Never'))
	elseif c == 'PALADIN' and msg[1] == 'hpalert' then
		if msg[2] then Basic_Resources.hpalert = msg[2] == 'off' and 0 or tonumber(msg[2]) or 3 end
		print('Basic Resources - Alert at: ' .. (Basic_Resources.hpalert > 0 and '|cFFFFD000' .. Basic_Resources.hpalert .. '|r holy power' or '|cFFC00000Never'))
    elseif msg[1] == 'reset' then
		pointFrame:ClearAllPoints()
        pointFrame:SetPoint('CENTER', 0, -222)
		powerFrame:ClearAllPoints()
		powerFrame:SetPoint('TOPLEFT', pointFrame, 'BOTTOMLEFT', 0, -3)
		gcdFrame:ClearAllPoints()
		gcdFrame:SetPoint('BOTTOMLEFT', pointFrame, 'TOPLEFT', 0, 3)
		print('Basic Resources - Position has been reset to default')
    else
		print('Basic Resources (version: |cFFFFD000' .. GetAddOnMetadata('Basic_Resources', 'Version') .. '|r) - Commands:')
	    print('  /bres locked |cFF00C000on|r/|cFFC00000off|r - lock the Basic Resources frame so that it can\'t be moved')
		print('  /bres scale |cFFFFD000[number]|r - set the scale of the Basic Resources UI (default is 1.0 times)')
		print('  /bres frequency |cFFFFD000[number]|r - set the update frequency (default is every 0.01 seconds)')
		print('  /bres always |cFF00C000on|r/|cFFC00000off|r - always show Basic Resources even with no target')
		print('  /bres hidespec |cFFFFD0000|r/|cFFFFD0001|r/|cFFFFD0002|r - hide Basic Resources in specialization 1 or 2 (0 is neither)')
		print('  /bres gcd |cFF00C000on|r/|cFFC00000off|r - show global cooldown bar')
		if c == 'DRUID' or c == 'ROGUE' then
			print('  /bres cpalert |cFFFFD000[#combo points]|r/|cFFC00000off|r - enable/disable the sound effect alert at x combo points')
		elseif c == 'PALADIN' then
			print('  /bres hpalert |cFFFFD000[#holy power]|r/|cFFC00000off|r - enable/disable the sound effect alert at x holy power')
		end
        print('  /bres |cFFFFD000reset|r - reset the location of Basic Resources to default')
    end
end
