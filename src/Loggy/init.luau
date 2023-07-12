--!strict
--[[
File name: Loggy.luau
Author: RadiatedExodus (RealEthanPlayzDev)
Created at: July 9, 2023
--]]

--// Types
export type LoggyMessageType = "LoggyMessageType.Verbose" | "LoggyMessageType.Debug" | "LoggyMessageType.Info" | "LoggyMessageType.Warn" | "LoggyMessageType.Error" | "LoggyMessageType.Fatal"
export type LoggyHistorySortType = "LoggyHistorySortType.InternalLogOrder" | "LoggyHistorySortType.AscendingTime" | "LoggyHistorySortType.DescendingTime"
export type LoggyMessage = {
    Contents: { [number]: any, n: number };
    DateTime: DateTime;
    MessageType: LoggyMessageType;
    GroupCount: number;
}

--// Libraries
local GoodSignal = require(script.GoodSignal)

--// Functions
local function KillThread()
    local CThread = coroutine.running()
    task.defer(coroutine.close, CThread)
    return coroutine.yield()
end

local function ConcatenateToString<T...>(... : T...): string
	local FinalString = ""
	for i, str in ipairs(table.pack(...)) do
		if i ~= 1 then
			FinalString ..= " "
		end
		
		if (typeof(str) == "table") and (typeof(str["__tostring"]) == "function") then
			local Success, Result = pcall(str["__tostring"], str)
			if Success then
				FinalString ..= Result
			else
				FinalString ..= tostring(str)
			end
		else
			FinalString ..= tostring(str)
		end
	end
	return FinalString
end

--// Enums
local LoggyMessageType = table.freeze({
    Verbose = "LoggyMessageType.Verbose" :: LoggyMessageType;
    Debug = "LoggyMessageType.Debug" :: LoggyMessageType;
    Info = "LoggyMessageType.Info" :: LoggyMessageType;
    Warn = "LoggyMessageType.Warn" :: LoggyMessageType;
    Error = "LoggyMessageType.Error" :: LoggyMessageType;
    Fatal = "LoggyMessageType.Fatal" :: LoggyMessageType;
})

local LoggyHistorySortType = table.freeze({
    InternalLogOrder = "LoggyHistorySortType.InternalLogOrder" :: LoggyHistorySortType;
    AscendingTime = "LoggyHistorySortType.AscendingTime" :: LoggyHistorySortType;
    DescendingTime = "LoggyHistorySortType.DescendingTime" :: LoggyHistorySortType;
})

--// CLASS LoggyNamespace
local LoggyNamespace = {}
LoggyNamespace.__index = LoggyNamespace
LoggyNamespace.__tostring = function(self: LoggyNamespace) return `LoggyNamespace<{self.Name}>` end
LoggyNamespace.__metatable = "This metatable is locked"

--// CLASS Constructor LoggyNamespace
local function constructor_LoggyNamespace(name: string): LoggyNamespace
    return setmetatable({
        Name = tostring(name);
        Messages = {} :: { LoggyMessage };
        Counter = 0;
        GroupCount = 0;
        MessageOut = GoodSignal.new();
    }, LoggyNamespace)
end
export type LoggyNamespace = typeof(constructor_LoggyNamespace(""))

function LoggyNamespace.Write(self: LoggyNamespace, mtype: LoggyMessageType, dt: DateTime?, ... : any)
    local Message: LoggyMessage = {
        Contents = table.pack(...);
        DateTime = if (typeof(dt) == "DateTime") then dt else DateTime.now();
        MessageType = mtype;
        GroupCount = self.GroupCount;
    }
    table.insert(self.Messages, Message)
    self.MessageOut:Fire(Message)
    return
end

function LoggyNamespace.Verbose(self: LoggyNamespace, ... : any)
    self:Write(LoggyMessageType.Verbose, DateTime.now(), ...)
    return
end

function LoggyNamespace.Debug(self: LoggyNamespace, ... : any)
    self:Write(LoggyMessageType.Debug, DateTime.now(), ...)
    return
end

function LoggyNamespace.Info(self: LoggyNamespace, ... : any)
    self:Write(LoggyMessageType.Info, DateTime.now(), ...)
    return
end

function LoggyNamespace.Warn(self: LoggyNamespace, ... : any)
    self:Write(LoggyMessageType.Warn, DateTime.now(), ...)
    return
end

function LoggyNamespace.Error(self: LoggyNamespace, ... : any)
    self:Write(LoggyMessageType.Error, DateTime.now(), ...)
    return
end

function LoggyNamespace.Fatal(self: LoggyNamespace, ... : any)
    self:Write(LoggyMessageType.Fatal, DateTime.now(), ...)
    return
end

function LoggyNamespace.Assert<T>(self: LoggyNamespace, condition: T, failMsg: string): T
    if (not condition) then
        self:Fatal(failMsg, "\n", debug.traceback())
        KillThread()
    end
    return condition
end

function LoggyNamespace.Count(self: LoggyNamespace, label: string)
    self.Counter += 1
    self:Info(`{label or "default"}: {self.Counter}`)
    return
end

function LoggyNamespace.CountReset(self: LoggyNamespace)
    self.Counter = 0
    return
end

function LoggyNamespace.Group(self: LoggyNamespace)
    self.GroupCount += 1
    return
end

function LoggyNamespace.GroupEnd(self: LoggyNamespace)
    if (self.GroupCount > 0) then
        self.GroupCount -= 1
    end
    return
end

function LoggyNamespace.Traceback(self: LoggyNamespace)
    self:Info(debug.traceback())
    return
end

function LoggyNamespace.GetLogHistory(self: LoggyNamespace, sortType: LoggyHistorySortType): { LoggyMessage }
    local Result = {}
    if (sortType == LoggyHistorySortType.InternalLogOrder) then
        Result = table.clone(self.Messages)
    elseif (sortType == LoggyHistorySortType.AscendingTime) or (sortType == LoggyHistorySortType.DescendingTime) then
        local SortableMessages = {} :: { { DT: DateTime, Msg: LoggyMessage } }
        for _, message in self.Messages do
            table.insert(SortableMessages, { DT = message.DateTime, Msg = message })
        end

        table.sort(SortableMessages, function(a, b)
            return if (sortType == LoggyHistorySortType.AscendingTime) then (a.DT.UnixTimestampMillis > b.DT.UnixTimestampMillis) else (a.DT.UnixTimestampMillis < b.DT.UnixTimestampMillis)
        end)

        for _, v in SortableMessages do
            table.insert(Result, v.Msg)
        end
    end
    return Result
end

function LoggyNamespace.AddLogs(self: LoggyNamespace, messages: { LoggyMessage })
    for _, message in messages do
        table.insert(self.Messages, message)
    end
    return
end

function LoggyNamespace.SetLogs(self: LoggyNamespace, messages: { LoggyMessage })
    self.Messages = messages
    return
end

--// CLASS Loggy
local Loggy = {}
Loggy.__index = Loggy
Loggy.__tostring = function() return "Loggy" end
Loggy.__metatable = "This metatable is locked"

--// CLASS Constructor Loggy
local function constructor_Loggy(): Loggy
    local DefaultNamespace = constructor_LoggyNamespace("Default")

    local NewLoggy = setmetatable({
        Namespaces = { DefaultNamespace } :: { LoggyNamespace };
        DefaultNamespace = DefaultNamespace;
        MessageOut = GoodSignal.new();
    }, Loggy)

    DefaultNamespace.MessageOut:Connect(function(message: LoggyMessage)
        return NewLoggy.MessageOut:Fire(DefaultNamespace, message)
    end)

    return NewLoggy
end
export type Loggy = typeof(constructor_Loggy())

function Loggy.CreateNamespace(self: Loggy, name: string): LoggyNamespace
    assert(self:GetNamespace(name) == nil, "existing namespace with the same name already exists")
    local NewNS = constructor_LoggyNamespace(name)
    table.insert(self.Namespaces, NewNS)
    NewNS.MessageOut:Connect(function(message: LoggyMessage)
        return self.MessageOut:Fire(NewNS, message)
    end)
    return NewNS
end

function Loggy.GetDefaultNamespace(self: Loggy): LoggyNamespace
    return self.DefaultNamespace
end

function Loggy.GetNamespace(self: Loggy, name: string): LoggyNamespace?
    for _, namespace in self.Namespaces do
        if (namespace.Name == name) then
            return (namespace :: any) :: LoggyNamespace
        end
    end
    return
end

local LMTStringMap = {
    [LoggyMessageType.Verbose] = "[VRB]";
    [LoggyMessageType.Debug] = "[DBG]";
    [LoggyMessageType.Warn] = "[WRN]";
    [LoggyMessageType.Info] = "[INF]";
    [LoggyMessageType.Error] = "[ERR]";
    [LoggyMessageType.Fatal] = "[FTL]";
}

--// Default MessageOut connectors
local function RobloxStdout(tl: Loggy)
    tl.MessageOut:Connect(function(namespace: LoggyNamespace, message: LoggyMessage)
        local Message = `[{message.DateTime:FormatLocalTime("LTS", "en-US")}] {LMTStringMap[message.MessageType]} [{namespace.Name}]: {string.rep("    ", message.GroupCount)}{ConcatenateToString(table.unpack(message.Contents))}`
        if (message.MessageType == LoggyMessageType.Verbose) or (message.MessageType == LoggyMessageType.Debug) or (message.MessageType == LoggyMessageType.Warn) then
            print(Message)
        elseif (message.MessageType == LoggyMessageType.Warn) then
            warn(Message)
        elseif (message.MessageType == LoggyMessageType.Error) or (message.MessageType == LoggyMessageType.Fatal) then
            task.spawn(error, Message)
        end
    end)
    return
end

--// Static Export
return setmetatable({
    new = constructor_Loggy;
    LoggyMessageType = LoggyMessageType;
    RobloxStdout = RobloxStdout;
    Default = constructor_Loggy();
}, {
    __call = function(): Loggy
        return constructor_Loggy()
    end
})