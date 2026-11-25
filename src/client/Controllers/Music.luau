-- Store sound with the clock: day music and PA announcements, the siren with a spoken countdown,
-- the lights-out clunk, then the night hum. Every sound comes from the manifest or Config and
-- simply stays silent until it has an uploaded id.
-- Music.playVoiceLine(name) is the hook for any line in art/sounds/VOICE_LINES.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ClockEffects = require(ReplicatedStorage.Shared.Logic.ClockEffects)
local Config = require(ReplicatedStorage.Shared.Config)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Hints = require(script.Parent.Hints)
local Net = require(ReplicatedStorage.Shared.Net)

local Settings = Config.DayNight
local Sounds = Settings.Sounds
local Volume = Settings.Volume

-- Gaps so the jingle or chime finishes before the announcer talks over it.
local AFTER_JINGLE = 3
local AFTER_CHIME = 1.5

local Music = {}

local random = Random.new()
local phaseToken = 0
local dayMusic: Sound?
local sirenLoop: Sound?
local nightHum: Sound?
local nightAmbience: Sound?

local function makeSound(id: string?, volume: number, looped: boolean): Sound?
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.Parent = SoundService
	return sound
end

local function playOnce(id: string?, volume: number): boolean
	local sound = makeSound(id, volume, false)
	if not sound then
		return false
	end
	sound.Ended:Once(function()
		sound:Destroy()
	end)
	sound:Play()
	return true
end

local function setPlaying(sound: Sound?, playing: boolean)
	if not sound or sound.IsPlaying == playing then
		return
	end
	if playing then
		sound:Play()
	else
		sound:Stop()
	end
end

local function pick(list: { string }): string
	return list[random:NextInteger(1, #list)]
end

-- Runs fn after `seconds` unless the phase has changed in the meantime.
local function later(seconds: number, fn: () -> ())
	local token = phaseToken
	task.delay(seconds, function()
		if token == phaseToken then
			fn()
		end
	end)
end

-- Plays a voice line by its VOICE_LINES.md file name. Returns false while it isn't uploaded yet.
function Music.playVoiceLine(name: string): boolean
	return playOnce(Settings.VoiceLineIds[name] or ModelLibrary.soundId(name), Volume.Announcer)
end

local function scheduleAnnouncement()
	later(random:NextNumber(Settings.AnnouncementGap.Min, Settings.AnnouncementGap.Max), function()
		playOnce(ModelLibrary.soundId(Sounds.Chime), Volume.Stinger)
		later(AFTER_CHIME, function()
			Music.playVoiceLine(pick(Settings.DayLines))
		end)
		scheduleAnnouncement()
	end)
end

-- The siren comes in blasts with quiet between, not one endless wail
local function sirenBursts(token: number)
	task.spawn(function()
		while phaseToken == token do
			setPlaying(sirenLoop, true)
			task.wait(Settings.SirenBurst.On)
			setPlaying(sirenLoop, false)
			if phaseToken ~= token then
				break
			end
			task.wait(Settings.SirenBurst.Off)
		end
		setPlaying(sirenLoop, false)
	end)
end

local function show(phase: string, endsAt: number, animate: boolean)
	phaseToken += 1
	setPlaying(dayMusic, phase == "Day")
	setPlaying(sirenLoop, false)
	setPlaying(nightHum, phase == "Night")
	setPlaying(nightAmbience, phase == "Night")

	if phase == "Day" then
		if animate then
			-- After the lights finish clunking on (Lighting)
			later(Config.Dawn.JingleDelay, function()
				playOnce(ModelLibrary.soundId(Sounds.Jingle), Volume.Stinger)
				later(AFTER_JINGLE, function()
					Music.playVoiceLine(pick(Settings.MorningLines))
				end)
			end)
		end
		scheduleAnnouncement()
	elseif phase == "Siren" then
		Hints.flash("siren", Settings.SirenHint, 8)
		sirenBursts(phaseToken)
		local timeLeft = endsAt - workspace:GetServerTimeNow()
		local countdownIn = ClockEffects.countdownDelay(timeLeft, Settings.CountdownLead)
		if countdownIn then
			later(countdownIn, function()
				Music.playVoiceLine(Settings.CountdownLine)
			end)
		end
	elseif phase == "Night" and animate then
		playOnce(ModelLibrary.soundId(Sounds.LightsOut), Volume.Stinger)
		Music.playVoiceLine(pick(Settings.LightsOutLines))
	end
end

function Music.Start()
	dayMusic = makeSound(Settings.DayMusicId, Volume.DayMusic, true)
	sirenLoop = makeSound(ModelLibrary.soundId(Sounds.Siren), Volume.Siren, true)
	nightHum = makeSound(ModelLibrary.soundId(Sounds.NightHum), Volume.NightHum, true)
	nightAmbience = makeSound(ModelLibrary.soundId(Sounds.NightAmbience), Volume.NightAmbience, true)

	Net.event("PhaseChanged").OnClientEvent:Connect(function(phase: string, endsAt: number)
		show(phase, endsAt, true)
	end)
	show(
		ReplicatedStorage:GetAttribute("Phase") or "Day",
		ReplicatedStorage:GetAttribute("PhaseEndsAt") or 0,
		false
	)
end

return Music
