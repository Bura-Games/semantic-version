--!optimize 2
--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GreenTea = require(script.Parent.GreenTea)
local IS_ULTRA_STRICT_MODE = _G.__DEV__

local IsPositiveInteger = GreenTea.build(GreenTea.number({
	integer = true;
	range = "[0, ]";
}))

local function ParsePrereleaseAndBuildWithSign(value: string): (string, string)
	local prereleaseWithSign, buildWithSign = string.match(value, "^(-[^+]+)(+.+)$")
	if prereleaseWithSign == nil or buildWithSign == nil then
		prereleaseWithSign = string.match(value, "^(-.+)$")
		buildWithSign = string.match(value, "^(+.+)$")
	end

	if prereleaseWithSign == nil and buildWithSign == nil then
		error(string.format("The parameter %q must begin with + or - to denote a prerelease or a build", value))
	end

	return prereleaseWithSign :: string, buildWithSign :: string
end

local function ParsePrerelease(prereleaseWithSign: string?): string?
	if prereleaseWithSign == nil then
		return nil
	end

	local prerelease = string.match(prereleaseWithSign, "^-(%w[%.%w-]*)$" :: string)
	if prerelease == nil then
		error(
			string.format(
				"The prerelease %q is not a slash followed by alphanumerics, dots and slashes",
				prereleaseWithSign
			)
		)
	end

	return prerelease
end

local function ParseBuild(buildWithSign: string?): string?
	if buildWithSign == nil then
		return nil
	end

	local build = string.match(buildWithSign, "^%+(%w[%.%w-]*)$" :: string)
	if build == nil then
		error(string.format("The build %q is not a + sign followed by alphanumerics, dots and slashes", buildWithSign))
	end

	return build
end

type Option = {
	Build: string,
	Prerelease: string,
} | {
	Build: nil,
	Prerelease: nil,
}

local function ParsePrereleaseAndBuild(value: string?): Option
	if not (value ~= "" and value) then
		return {}
	end

	local prereleaseWithSign, buildWithSign = ParsePrereleaseAndBuildWithSign(value)
	local prerelease = ParsePrerelease(prereleaseWithSign)
	local build = ParseBuild(buildWithSign)
	return {
		Build = build :: string;
		Prerelease = prerelease :: string;
	}
end

local function ParseVersion(value: string)
	local stringMajor, stringMinor, stringPatch, stringPrereleaseAndBuild =
		string.match(value, "^(%d+)%.?(%d*)%.?(%d*)(.-)$")
	if stringMajor == nil then
		error(string.format("Could not extract version number(s) from %q", value))
	end

	local major = tonumber(stringMajor) :: number
	local minor = tonumber(stringMinor) :: number
	local patch = tonumber(stringPatch) :: number
	local option = ParsePrereleaseAndBuild(stringPrereleaseAndBuild :: string)
	return major, minor, patch, option.Prerelease, option.Build
end

local function _Compare(a: any, b: any)
	return if a == b then 0 elseif a < b then -1 else 1
end
local Compare = (_Compare :: never) :: ((a: number, b: number) -> number) & ((a: string, b: string) -> number)

local function CompareIds(selfId: string, otherId: string)
	if selfId == otherId then
		return 0
	end

	if selfId == nil then
		return -1
	end

	if otherId == nil then
		return 1
	end

	local selfNumber = tonumber(selfId)
	local otherNumber = tonumber(otherId)
	if selfNumber and otherNumber then
		return Compare(selfNumber, otherNumber)
	end

	if selfNumber then
		return -1
	end

	if otherNumber then
		return 1
	end

	return Compare(selfId, otherId)
end

local function SmallerIdList(selfIds: {string}, otherIds: {string})
	for index, value in selfIds do
		local comparison = CompareIds(value, otherIds[index])
		if comparison ~= 0 then
			return comparison == -1
		end
	end

	return #selfIds < #otherIds
end

local function SmallerPrerelease(mine: string?, other: string?)
	if mine == other or not mine then
		return false
	end

	if not other then
		return true
	end

	return SmallerIdList(string.split(mine, "."), string.split(other, "."))
end

export type SemanticVersion = typeof(setmetatable(
	{} :: {
		Major: number,
		Minor: number,
		Patch: number,
		Prerelease: string?,
		Build: string?,

		NextMajor: (self: SemanticVersion) -> SemanticVersion,
		NextMinor: (self: SemanticVersion) -> SemanticVersion,
		NextPatch: (self: SemanticVersion) -> SemanticVersion,
	},
	{} :: {
		__eq: (self: SemanticVersion, other: SemanticVersion) -> boolean,
		__lt: (self: SemanticVersion, other: SemanticVersion) -> boolean,
		__pow: (self: SemanticVersion, other: SemanticVersion) -> boolean,
		__tostring: (self: SemanticVersion) -> string,
	}
))

type BaseStatics = {
	ClassName: "SemanticVersion",
	new: (
		major: number | string,
		minor: number?,
		patch: number?,
		prerelease: string?,
		build: string?
	) -> SemanticVersion,
	FromReplicatedStorage: () -> SemanticVersion,
}
type SemanticVersionStatics = BaseStatics & {
	__eq: (self: SemanticVersion, other: SemanticVersion) -> boolean,
	__lt: (self: SemanticVersion, other: SemanticVersion) -> boolean,
	__pow: (self: SemanticVersion, other: SemanticVersion) -> boolean,
	__tostring: (self: SemanticVersion) -> string,
}

--[=[
	An immutable class for representing semantic versioning.

	There are metamethods that are undocumented, so here they are:

	```lua
	local _ = SemanticVersion.new("1.0.0") == SemanticVersion.new("1.0.0") -- __eq check
	local _ = SemanticVersion.new("1.0.0") < SemanticVersion.new("2.0.0") -- __lt check
	local _ = SemanticVersion.new("1.0.0") ^ SemanticVersion.new("2.0.0") -- pessimistic check
	local _ = tostring(SemanticVersion.new("1.0.0"))
	```

	:::info
	Pessimistic check is basically the same as the one from Rubygems. It is
	particularly useful when you want to ensure compatibility with future
	minor updates while avoiding potential issues from major version changes.
	:::

	@class SemanticVersion
]=]
local SemanticVersion = {} :: SemanticVersion & SemanticVersionStatics
SemanticVersion.ClassName = "SemanticVersion";
(SemanticVersion :: any).__index = SemanticVersion

--[=[
	The major version.

	@readonly
	@prop Major number
	@within SemanticVersion
]=]
--[=[
	The minor version.

	@readonly
	@prop Minor number
	@within SemanticVersion
]=]
--[=[
	The patch version.

	@readonly
	@prop Patch number
	@within SemanticVersion
]=]

--[=[
	The prerelease version.

	@readonly
	@prop Prerelease string?
	@within SemanticVersion
]=]
--[=[
	The build version.

	@readonly
	@prop Build string?
	@within SemanticVersion
]=]

--[=[
	Creates a new semantic version.

	@param major number | string -- The major version if an integer, otherwise the version string.
	@param minor? number -- The minor version.
	@param patch? number -- The patch version.
	@param prerelease? string -- The prerelease version.
	@param build? string -- The build version.
	@return SemanticVersion
]=]
function SemanticVersion.new(
	major: number | string,
	minor: number?,
	patch: number?,
	prerelease: string?,
	build: string?
): SemanticVersion
	local self = setmetatable({}, SemanticVersion)
	if type(major) == "string" then
		major, minor, patch, prerelease, build = ParseVersion(major)
	end

	local trueMinor = minor or 0
	local truePatch = patch or 0

	if IS_ULTRA_STRICT_MODE then
		local typeSuccess0, typeError0 = IsPositiveInteger:matches(major)
		if not typeSuccess0 then
			error(typeError0)
		end
		local typeSuccess1, typeError1 = IsPositiveInteger:matches(trueMinor)
		if not typeSuccess1 then
			error(typeError1)
		end
		local typeSuccess2, typeError2 = IsPositiveInteger:matches(truePatch)
		if not typeSuccess2 then
			error(typeError2)
		end
	end

	self.Major = major
	self.Minor = trueMinor
	self.Patch = truePatch
	self.Prerelease = prerelease
	self.Build = build
	table.freeze(self)
	return (self :: any) :: SemanticVersion
end

--[=[
	Gets the semantic version from ReplicatedStorage attributes.

	:::info
	The attributes used are `SemVerMajor`, `SemVerMinor`, `SemVerPatch`,
	`SemVerPrerelease`, and `SemVerBuild`. They are all integers, with
	the exception of `SemVerPrerelease` and `SemVerBuild` being optional strings.
	:::

	@return SemanticVersion
]=]
function SemanticVersion.FromReplicatedStorage()
	local semVerPrerelease = ReplicatedStorage:GetAttribute("SemVerPrerelease")
	local semVerBuild = ReplicatedStorage:GetAttribute("SemVerBuild")

	return SemanticVersion.new(
		ReplicatedStorage:GetAttribute("SemVerMajor"),
		ReplicatedStorage:GetAttribute("SemVerMinor"),
		ReplicatedStorage:GetAttribute("SemVerPatch"),
		if semVerPrerelease and semVerPrerelease ~= "" then semVerPrerelease else nil,
		if semVerBuild and semVerBuild ~= "" then semVerBuild else nil
	)
end

--[=[
	Gets the next major version.
	@return SemanticVersion
]=]
function SemanticVersion:NextMajor(): SemanticVersion
	return SemanticVersion.new(self.Major + 1, 0, 0)
end

--[=[
	Gets the next minor version.
	@return SemanticVersion
]=]
function SemanticVersion:NextMinor(): SemanticVersion
	return SemanticVersion.new(self.Major, self.Minor + 1, 0)
end

--[=[
	Gets the next patch version.
	@return SemanticVersion
]=]
function SemanticVersion:NextPatch(): SemanticVersion
	return SemanticVersion.new(self.Major, self.Minor, self.Patch + 1)
end

function SemanticVersion:__eq(other)
	return self.Major == other.Major
		and self.Minor == other.Minor
		and self.Patch == other.Patch
		and self.Prerelease == other.Prerelease
end
function SemanticVersion:__lt(other)
	if self.Major ~= other.Major then
		return self.Major < other.Major
	end

	if self.Minor ~= other.Minor then
		return self.Minor < other.Minor
	end

	if self.Patch ~= other.Patch then
		return self.Patch < other.Patch
	end

	return SmallerPrerelease(self.Prerelease, other.Prerelease)
end

-- This works like the "pessimisstic operator" in Rubygems.
-- if a and b are versions, a ^ b means "b is backwards-compatible with a"
-- in other words, "it's safe to upgrade from a to b"
function SemanticVersion:__pow(other)
	return if self.Major == 0 then self == other else self.Major == other.Major and self.Minor <= other.Minor
end

function SemanticVersion:__tostring()
	local stringBuilder = {string.format("%*.%*.%*", self.Major, self.Minor, self.Patch)}
	local build = self.Build
	local prerelease = self.Prerelease

	if prerelease ~= "" and prerelease then
		table.insert(stringBuilder, `-{prerelease}`)
	end

	if build ~= "" and build then
		table.insert(stringBuilder, `+{build}`)
	end

	return table.concat(stringBuilder)
end

return table.freeze(SemanticVersion :: BaseStatics)
