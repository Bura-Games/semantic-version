---
sidebar_position: 2
---

# Installation

### Method #1 - HttpService

This method uses `HttpService` to install SemanticVersion.

1. In Roblox Studio, paste the following command into your command bar.
2. Run the following command:

<textarea readonly rows="5" onClick={e => e.target.select()} style={{
   width: "100%"
}}>
   {`local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
local HttpEnabled = HttpService.HttpEnabled
HttpService.HttpEnabled = true
local function RequestAsync(RequestDictionary)
	return HttpService:RequestAsync(RequestDictionary)
end
local function GetAsync(Url, Headers)
	Headers["cache-control"] = "no-cache"
	local Success, ResponseDictionary = pcall(RequestAsync, {
		Headers = Headers;
		Method = "GET";
		Url = Url;
	})
	if not Success then
		return false, ResponseDictionary
	end
	if not ResponseDictionary.Success then
		return false, string.format("HTTP %*: %*", ResponseDictionary.StatusCode, ResponseDictionary.StatusMessage)
	end
	return ResponseDictionary.Body
end
local function Initify(Root)
	local InitFile = Root:FindFirstChild("init") or Root:FindFirstChild("init.lua") or Root:FindFirstChild("init.client.lua") or Root:FindFirstChild("init.server.lua") or Root:FindFirstChild("init.luau") or Root:FindFirstChild("init.client.luau") or Root:FindFirstChild("init.server.luau")
	if InitFile then
		InitFile.Name = Root.Name
		InitFile.Parent = Root.Parent
		for _, Child in Root:GetChildren() do
			Child.Parent = InitFile
		end
		Root:Destroy()
		Root = InitFile
	end
	for _, Child in Root:GetChildren() do
		Initify(Child)
	end
	return Root
end
local FilesList = HttpService:JSONDecode(assert(GetAsync(
	"https://api.github.com/repos/bura-games/semantic-version/contents/src",
	{accept = "application/vnd.github.v3+json"}
)))
local SemanticVersion = Instance.new("Folder")
SemanticVersion.Name = "SemanticVersion"
for _, FileData in FilesList do
	local ModuleScript = Instance.new("ModuleScript")
	ModuleScript.Name = tostring(string.match(FileData.name, "(%w+)%.lua") or string.match(FileData.name, "(%w+)%.luau"))
	local Success, Source = GetAsync(FileData.download_url, {})
	if not Success then
		ModuleScript.Source = string.format("-- %*", tostring(Source))
	else
		ModuleScript.Source = tostring(Success)
	end
	ModuleScript.Parent = SemanticVersion
end
SemanticVersion.Parent = ReplicatedStorage
Initify(SemanticVersion)
HttpService.HttpEnabled = HttpEnabled`}
</textarea>

### Method 2 - Wally

1. Setup [Wally](https://wally.run/) by using `wally init`.
2. Add `howmanysmall/semantic-version` as a dependency.

```toml
[dependencies]
SemanticVersion = "howmanysmall/semantic-version@^1.0.0"
```

## Next

Now, check out the [API reference](/api/SemanticVersion)!