
Data
- 'Singleton', a big JSON object blob
    - For example game settings and/or game state, etc
- 'Entity', an array of JSON objects
    - For example a list of agents, game objects, etc

Data Server
- One per region
- Full dataset is stored in Linkset Data as persistent storage
- Keeps track of subscribers and notifies them of changes
- Keeps track of Data Bridges
- Notifies Data Bridges in sim of updates
    - Attaching a unique id to the packet to relay to prevent any feedback loops
- Receives updates of neighboring Data Servers, via Data Bridges, that is then integrated
- On initialisation, it needs to check if there are other Data Servers in neighbouring regions and if so, request a full copy of a dataset to replicate locally
- On region restarts, it needs to 

Data Bridge
- A special relay that can be setup on sim borders
- Communicates within 20m using llSay across borders to another Data Bridge
- At initialisation it tells Data Server of its' existence and also checks & verifies with Data Bridges across sim boundaries
- Relays data updates from another bridge's data server to its' own data server
- (Temporarily) remembers the unique id of any relayed packet; Ignores any packet with that id to prevent feedback loops
- On receiving a relayed packet sends it to the in-sim Data Server
- On receiving a relayed packet sends it to other in-sim Data Bridges
- Before sending a packet, check via llEdgeOfWorld where neighbouring Data Bridge was, otherwise put packet into a pending queue
- On reconnecting with a Data Bridge, push through the pending queue
- Otherwise if queue ended up full, disable the pending queue and announce the reconnected Data Bridge that its' Data Server should completely reset and get a full dataset

Data Client
- Script that communicates into network
- `adding`, `modifying` and `removing` data
- `subscribing`/`unsubscribing` to data
- `setup` event helps with subscribing and getting fresh dataset
- `setup` events can be used on region crossings to resubscribe and get latest data


