-- The central mixer. Every Sound the game makes goes through Mix.route into one of the groups
-- under SoundService.Master (declared in default.project.json so client and server always share
-- them). The server adds the compressor and limiter on Master. Group volumes, ducking and the
-- scare budget are per player, so they run on the client (Controllers/AudioSettings starts them).
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local AudioMix = require(ReplicatedStorage.Shared.Logic.AudioMix)

local Settings = Config.Mix

export type Group = "Music" | "Ambience" | "SFX" | "Voice" | "Scare" | "UI"
export type ScareKind = AudioMix.ScareKind

local Mix = {}

-- Server sounds that need the client's attention (scare budget, voice ducking) carry this tag
local WATCH_TAG = "MixWatch"
local GROUP_NAMES = { "Music", "Ambience", "SFX", "Voice", "Scare", "UI" }
local isClient = RunService:IsClient()
local random = Random.new()

local function findOrMake(parent: Instance, name: string): SoundGroup
	local found = parent:FindFirstChild(name)
	if found and found:IsA("SoundGroup") then
		return found
	end
	local group = Instance.new("SoundGroup")
	group.Name = name
	group.Parent = parent
	return group
end

local master = findOrMake(SoundService, "Master")
local groups: { [string]: SoundGroup } = {}
for _, name in GROUP_NAMES do
	groups[name] = findOrMake(master, name)
end

local function addEffect(name: string, values: { [string]: number }, priority: number)
	if master:FindFirstChild(name) then
		return
	end
	local effect = Instance.new("CompressorSoundEffect")
	effect.Name = name
	effect.Threshold = values.Threshold
	effect.Ratio = values.Ratio
	effect.Attack = values.Attack
	effect.Release = values.Release
	effect.Priority = priority -- higher runs first: level, then cap
	effect.Parent = master
end

if RunService:IsServer() then
	addEffect("Compressor", Settings.Compressor, 2)
	addEffect("Limiter", Settings.Limiter, 1)
end

local audio: AudioMix.Audio = { master = 1, music = 1, effects = 1, voice = 1, gentle = false }
local scareState = AudioMix.newScareState()
local duckUntil: { [any]: number } = {}
local ducked = false
local duckToken = 0

local function tweenVolume(target: Instance, volume: number, seconds: number)
	TweenService:Create(
		target,
		TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Volume = volume }
	):Play()
end

local function applyGroups(seconds: number)
	tweenVolume(master, AudioMix.masterVolume(Settings, audio), seconds)
	for name, group in groups do
		tweenVolume(group, AudioMix.groupVolume(Settings, audio, name, ducked), seconds)
	end
end

local function updateDuck()
	local now = os.clock()
	local nextEnd = math.huge
	for reason, untilAt in duckUntil do
		if untilAt <= now then
			duckUntil[reason] = nil
		else
			nextEnd = math.min(nextEnd, untilAt)
		end
	end
	local active = nextEnd < math.huge
	if active ~= ducked then
		ducked = active
		applyGroups(if active then Settings.Duck.Down else Settings.Duck.Up)
	end
	if active then
		duckToken += 1
		local token = duckToken
		task.delay(nextEnd - now, function()
			if token == duckToken then
				updateDuck()
			end
		end)
	end
end

-- Music and ambience dip for at least `seconds` under `reason`; calling again extends it.
function Mix.duck(reason: any, seconds: number)
	if not isClient then
		return
	end
	duckUntil[reason] = math.max(duckUntil[reason] or 0, os.clock() + seconds)
	updateDuck()
end

-- Voice lines hold the duck while they play; the cap covers a line that never ends or loads.
local function duckWhile(sound: Sound)
	Mix.duck(sound, 30)
	local function release()
		duckUntil[sound] = os.clock() + Settings.Duck.VoiceTail
		updateDuck()
	end
	sound.Ended:Once(release)
	sound.Stopped:Once(release)
	sound.Destroying:Once(release)
end

-- A soft attack, the budget's volume share, and a falloff that tapers far scares out.
local function applyScare(sound: Sound, kind: ScareKind)
	local target = sound.Volume * AudioMix.scareScale(scareState, os.clock(), kind, Settings, audio.gentle)
	sound.RollOffMode = Enum.RollOffMode.InverseTapered
	sound.RollOffMinDistance = math.min(sound.RollOffMinDistance, Settings.Scare.FullWithin)
	sound.Volume = 0
	if target > 0 then
		tweenVolume(sound, target, random:NextNumber(table.unpack(Settings.Scare.FadeIn)))
	end
end

local function watch(sound: Sound, group: string, scare: ScareKind?)
	if scare then
		applyScare(sound, scare)
	end
	if group == "Voice" then
		duckWhile(sound)
	end
end

-- Puts a sound in its group and caps its volume. Call it after setting Volume and roll-off, right
-- before Play. scare = "sharp" or "stinger" runs it through the scare budget.
function Mix.route(sound: Sound, group: Group, scare: ScareKind?)
	sound.SoundGroup = groups[group]
	sound.Volume = math.min(sound.Volume, Settings.VolumeCap)
	if not scare and group ~= "Voice" then
		return
	end
	if isClient then
		watch(sound, group, scare)
	else
		sound:SetAttribute("MixScare", scare)
		CollectionService:AddTag(sound, WATCH_TAG)
	end
end

-- Eases a sound (a loop, usually) to a volume instead of a hard start or cut.
function Mix.fade(sound: Sound, volume: number, seconds: number)
	tweenVolume(sound, volume, seconds)
end

function Mix.audio(): AudioMix.Audio
	return table.clone(audio)
end

function Mix.setAudio(new: AudioMix.Audio)
	audio = table.clone(new)
	applyGroups(0.2)
end

-- Client only: picks up the server's scare and voice sounds and sets the group levels.
function Mix.startClient()
	local function onWatched(instance: Instance)
		if instance:IsA("Sound") and instance.SoundGroup then
			watch(instance, instance.SoundGroup.Name, instance:GetAttribute("MixScare") :: ScareKind?)
		end
	end
	CollectionService:GetInstanceAddedSignal(WATCH_TAG):Connect(onWatched)
	for _, instance in CollectionService:GetTagged(WATCH_TAG) do
		onWatched(instance)
	end
	applyGroups(0)
end

return Mix
