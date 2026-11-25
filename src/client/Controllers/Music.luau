-- Store sound with the clock: day music and the morning PA line, the siren with a ticking clock and
-- a spoken countdown, the lights-out clunk and alarm beep, then the night hum. Every sound comes from
-- the manifest or Config and simply stays silent until it has an uploaded id; PA lines always show
-- as [PA] subtitles. Music.playVoiceLine(name) is the hook for any line in art/sounds/VOICE_LINES.md.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local ClockEffects = require(ReplicatedStorage.Shared.Logic.ClockEffects)
local Config = require(ReplicatedStorage.Shared.Config)
local Mix = require(ReplicatedStorage.Shared.Mix)
local ModelLibrary = require(ReplicatedStorage.Shared.ModelLibrary)
local Hints = require(script.Parent.Hints)
local Net = require(ReplicatedStorage.Shared.Net)
local Subtitles = require(script.Parent.Subtitles)

local Settings = Config.DayNight
local Sounds = Settings.Sounds
local Volume = Settings.Volume

type PaLine = { voice: string, text: string }

-- Gaps so the jingle or chime finishes before the announcer talks over it.
local AFTER_JINGLE = 3
local COUNTDOWN_WORD_SECONDS = 1.2

local Music = {}

local random = Random.new()
local phaseToken = 0
local dayMusic: Sound?
local sirenLoop: Sound?
local nightHum: Sound?
local nightAmbience: Sound?
local clockTick: Sound?
local clockTickFast: Sound?

local function makeSound(
	id: string?,
	volume: number,
	looped: boolean,
	group: Mix.Group,
	scare: Mix.ScareKind?
): Sound?
	if not id then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.SoundId = id
	sound.Volume = volume
	sound.Looped = looped
	sound.Parent = SoundService
	Mix.route(sound, group, scare)
	return sound
end

local function playOnce(id: string?, volume: number, group: Mix.Group, scare: Mix.ScareKind?): boolean
	local sound = makeSound(id, volume, false, group, scare)
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

local function pick<T>(list: { T }): T
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
	return playOnce(Settings.VoiceLineIds[name] or ModelLibrary.soundId(name), Volume.Announcer, "Voice")
end

-- The recorded clip plays once it has an id; the subtitle shows either way, for anyone muted or deaf.
local function announce(line: PaLine)
	Music.playVoiceLine(line.voice)
	Subtitles.show(Settings.PaPrefix .. line.text, Settings.PaSubtitleSeconds)
end

-- The last seconds before lights out: the clock ticks faster under the spoken count, word by word.
local function countdown()
	local line = Settings.CountdownLine
	setPlaying(clockTick, false)
	setPlaying(clockTickFast, true)
	Music.playVoiceLine(line.voice)
	for index, word in line.words do
		later(index - 1, function()
			Subtitles.show(Settings.PaPrefix .. word, COUNTDOWN_WORD_SECONDS)
		end)
	end
end

-- The siren comes in blasts with quiet between, not one endless wail. Each blast swells in and
-- dies away instead of starting and cutting hard.
local function sirenBursts(token: number)
	local burst = Settings.SirenBurst
	task.spawn(function()
		while phaseToken == token do
			if sirenLoop then
				sirenLoop.Volume = 0
				setPlaying(sirenLoop, true)
				Mix.fade(sirenLoop, Volume.Siren, burst.FadeIn)
			end
			task.wait(burst.On)
			if sirenLoop then
				Mix.fade(sirenLoop, 0, burst.FadeOut)
			end
			task.wait(burst.FadeOut)
			setPlaying(sirenLoop, false)
			if phaseToken ~= token then
				break
			end
			task.wait(math.max(0, burst.Off - burst.FadeOut))
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
	setPlaying(clockTick, phase == "Siren")
	setPlaying(clockTickFast, false)

	if phase == "Day" then
		if animate then
			-- After the lights finish clunking on (Lighting)
			later(Config.Dawn.JingleDelay, function()
				playOnce(ModelLibrary.soundId(Sounds.Jingle), Volume.Stinger, "Music")
				later(AFTER_JINGLE, function()
					announce(pick(Settings.MorningLines))
				end)
			end)
		end
	elseif phase == "Siren" then
		Hints.flash("siren", Settings.SirenHint, 8)
		sirenBursts(phaseToken)
		local timeLeft = endsAt - workspace:GetServerTimeNow()
		local countdownIn = ClockEffects.countdownDelay(timeLeft, Settings.CountdownLead)
		if countdownIn then
			later(countdownIn, countdown)
		elseif timeLeft > 0 then
			setPlaying(clockTick, false)
			setPlaying(clockTickFast, true)
		end
	elseif phase == "Night" and animate then
		playOnce(ModelLibrary.soundId(Sounds.LightsOut), Volume.Stinger, "SFX")
		playOnce(ModelLibrary.soundId(Sounds.AlarmBeep), Volume.AlarmBeep, "Scare", "sharp")
		announce(pick(Settings.LightsOutLines))
	end
end

function Music.Start()
	dayMusic = makeSound(Settings.DayMusicId, Volume.DayMusic, true, "Music")
	sirenLoop = makeSound(ModelLibrary.soundId(Sounds.Siren), Volume.Siren, true, "Scare")
	nightHum = makeSound(ModelLibrary.soundId(Sounds.NightHum), Volume.NightHum, true, "Ambience")
	nightAmbience =
		makeSound(ModelLibrary.soundId(Sounds.NightAmbience), Volume.NightAmbience, true, "Ambience")
	clockTick = makeSound(ModelLibrary.soundId(Sounds.ClockTick), Volume.ClockTick, true, "SFX")
	clockTickFast = makeSound(ModelLibrary.soundId(Sounds.ClockTickFast), Volume.ClockTick, true, "SFX")

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
