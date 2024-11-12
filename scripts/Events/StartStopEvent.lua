AutoDriveStartStopEvent = {}
AutoDriveStartStopEvent.TYPE_START = 0
AutoDriveStartStopEvent.TYPE_STOP = 1
AutoDriveStartStopEvent_mt = Class(AutoDriveStartStopEvent, Event)

InitEventClass(AutoDriveStartStopEvent, "AutoDriveStartStopEvent")

function AutoDriveStartStopEvent.emptyNew()
    local self = Event.new(AutoDriveStartStopEvent_mt)
    return self
end

function AutoDriveStartStopEvent.new(vehicle, eventType, hasCallbacks, isStartingAIVE)
    local self = AutoDriveStartStopEvent.emptyNew()
    self.eventType = eventType
    self.vehicle = vehicle
    self.hasCallbacks = hasCallbacks or false
    self.isStartingAIVE = isStartingAIVE or false
    return self
end

function AutoDriveStartStopEvent:writeStream(streamId, connection)
    NetworkUtil.writeNodeObjectId(streamId, NetworkUtil.getObjectId(self.vehicle))
    streamWriteUIntN(streamId, self.eventType, 4)
    streamWriteBool(streamId, self.hasCallbacks)
    streamWriteBool(streamId, self.isStartingAIVE)
end

function AutoDriveStartStopEvent:readStream(streamId, connection)
    self.vehicle = NetworkUtil.getObject(NetworkUtil.readNodeObjectId(streamId))
    self.eventType = streamReadUIntN(streamId, 4)
    self.hasCallbacks = streamReadBool(streamId)
    self.isStartingAIVE = streamReadBool(streamId)
    self:run(connection)
end

function AutoDriveStartStopEvent:run(connection)
    if self.eventType == self.TYPE_START then
        SpecializationUtil.raiseEvent(self.vehicle, "onStartAutoDrive")
    elseif self.eventType == self.TYPE_STOP then
        SpecializationUtil.raiseEvent(self.vehicle, "onStopAutoDrive", self.hasCallbacks, self.isStartingAIVE)
    end
end

function AutoDriveStartStopEvent:sendStartEvent(vehicle)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(AutoDriveStartStopEvent.new(vehicle, self.TYPE_START), true)
    end
end

function AutoDriveStartStopEvent:sendStopEvent(vehicle, hasCallbacks, isStartingAIVE)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(AutoDriveStartStopEvent.new(vehicle, self.TYPE_STOP, hasCallbacks, isStartingAIVE), true)
    end
end
