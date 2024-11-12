AutoDriveToggleConnectionEvent = {}
AutoDriveToggleConnectionEvent_mt = Class(AutoDriveToggleConnectionEvent, Event)

InitEventClass(AutoDriveToggleConnectionEvent, "AutoDriveToggleConnectionEvent")

function AutoDriveToggleConnectionEvent.emptyNew()
    local self = Event.new(AutoDriveToggleConnectionEvent_mt)
    return self
end

function AutoDriveToggleConnectionEvent.new(startNode, endNode, reverseDirection, dualConnection)
    local self = AutoDriveToggleConnectionEvent.emptyNew()
    self.startNode = startNode
    self.endNode = endNode
    self.reverseDirection = reverseDirection
    self.dualConnection = dualConnection
    return self
end

function AutoDriveToggleConnectionEvent:writeStream(streamId, connection)
    streamWriteUIntN(streamId, self.startNode.id, 20)
    streamWriteUIntN(streamId, self.endNode.id, 20)
    streamWriteBool(streamId, self.reverseDirection)
    streamWriteBool(streamId, self.dualConnection)
end

function AutoDriveToggleConnectionEvent:readStream(streamId, connection)
    self.startNode = ADGraphManager:getWayPointById(streamReadUIntN(streamId, 20))
    self.endNode = ADGraphManager:getWayPointById(streamReadUIntN(streamId, 20))
    self.reverseDirection = streamReadBool(streamId)
    self.dualConnection = streamReadBool(streamId)
    self:run(connection)
end

function AutoDriveToggleConnectionEvent:run(connection)
    if g_server ~= nil and connection:getIsServer() == false then
        -- If the event is coming from a client, server have only to broadcast
        AutoDriveToggleConnectionEvent.sendEvent(self.startNode, self.endNode, self.reverseDirection, self.dualConnection)
    else
        ADGraphManager:toggleConnectionBetween(self.startNode, self.endNode, self.reverseDirection, self.dualConnection, false)
    end
end

function AutoDriveToggleConnectionEvent.sendEvent(startNode, endNode, reverseDirection, dualConnection)
    local event = AutoDriveToggleConnectionEvent.new(startNode, endNode, reverseDirection, dualConnection)
    if g_server ~= nil then
        -- Server have to broadcast to all clients and himself
        g_server:broadcastEvent(event, true)
    else
        -- Client have to send to server
        g_client:getServerConnection():sendEvent(event)
    end
end
