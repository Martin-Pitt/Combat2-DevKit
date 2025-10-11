
## All Events
`init` [Server] {
    event: "init"
}
`error` [Server] {
    event: "error",
    code: 100-599,
    description: "Details of error"
}
`ping` [Client/Server] {
    event: "ping"
}
`pong` [Client/Server] {
    event: "pong"
}
`verify` [Client] {
    event: "verify",
    signature: string
}
`verified` [Server/Bridge] {
    event: "verified",
    object: key
}
`setup` [Client] {
    event: "setup",
    signature: string,
    subscribe: string Filter[]
},
`subscribe` [Client] {
    event: "subscribe",
    filter: string Filter[]
}
`unsubscribe` [Client] {
    event: "unsubscribe",
    filter: string Filter[]
}

string Filter
    "agent" - all agent entities
    "agent.*" - all agent entities
    "agent.####-####-######-#######" - specific agent entity
    "*" - all entities & singletons
    "territory.Blue Base" - specific territory entity

`entity.add` [Entity-only] [Client] {
    event: "[entity].add",
    identifier: string,
    [any optional properties]
}
`entity.patch` [Client] {
    event: "[entity].patch",
    identifier: optional string,
    [any optional properties]
}
`entity.remove` [Entity-only] [Client] {
    event: "[entity].remove",
    identifier: string
}
`entity.subscribe` [Client] {
    event: "[entity].subscribe",
    identifier: optional string
}
`entity.subscribed` [Server] {
    event: "[entity].subscribed",
    identifier: optional string
}
`entity.unsubscribe` [Client] {
    event: "[entity].unsubscribe",
    identifier: optional string
}
`entity.unsubscribed` [Server] {
    event: "[entity].unsubscribed",
    identifier: optional string
}
`entity.added` [Server] {
    event: "[entity].added",
    identifier: optional string,
    [any optional properties]
}
`entity.patched` [Server] {
    event: "[entity].patched",
    identifier: string,
    [any optional properties]
}
`entity.removed` [Server] {
    event: "[entity].removed",
    identifier: string
}
`entity.get` [Client] {
    event: "[entity].get",
    identifier: string
}
`entity.list` [Entity-only] [Server] {
    event: "[entity].list",
    list: [
        {
            identifier: string,
            [any optional properties]
        },
        ...
    ],
    isLast: false | true
}
`entity.result` [Server] {
    event: "[entity].result",
    identifier: string,
    [any optional properties]
}

## Client Events
`entity.add` [Entity-only]
`entity.patch`
`entity.remove` [Entity-only]
`entity.subscribe`
`entity.unsubscribe`
`entity.get`

## Server Events
`init` [Server]
`error` [Server]
`entity.subscribed`
`entity.unsubscribed`
`entity.added`
`entity.patched`
`entity.removed`
`entity.list` [Entity-only]
`entity.result`

## Entity Events
`entity.add` [Client]
`entity.patch` [Client]
`entity.remove` [Client]
`entity.subscribe` [Client]
`entity.subscribed` [Server]
`entity.unsubscribe` [Client]
`entity.unsubscribed` [Server]
`entity.added` [Server]
`entity.patched` [Server]
`entity.removed` [Server]
`entity.get` [Client]
`entity.list` [Server]
`entity.result` [Server]

## Singleton Events
`entity.patch` [Client]
`entity.subscribe` [Client]
`entity.subscribed` [Server]
`entity.unsubscribe` [Client]
`entity.unsubscribed` [Server]
`entity.added` [Server]
`entity.patched` [Server]
`entity.removed` [Server]
`entity.get` [Client]
`entity.result` [Server]

## Action Events
`entity.add` [Entity-only] [Client]
`entity.patch` [Client]
`entity.remove` [Entity-only] [Client]
`entity.subscribe` [Client]
`entity.unsubscribe` [Client]
`entity.get` [Client]

## Response Events
`entity.subscribed` [Server]
`entity.unsubscribed` [Server]
`entity.added` [Server]
`entity.patched` [Server]
`entity.removed` [Server]
`entity.list` [Entity-only] [Server]
`entity.result` [Server]

## Subscription Events
`entity.added` [Server]
`entity.patched` [Server]
`entity.removed` [Server]
