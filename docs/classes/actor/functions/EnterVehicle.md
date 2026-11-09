# EnterVehicle

Server: `actor:EnterVehicle(vehicle)` requests boarding after a 0.5-second delay. It requires DV, `use_vehicle`, a valid vehicle and an available allowed seat. Permission and availability are checked again when boarding; there is no synchronous success result.

Boarding preserves the actor object and UID, stores its body and equipment, removes the physical NPC/NextBot and binds the actor to the DV driver/passenger entity. `BGN_OnEnterVehicle(actor, provider)` fires after success. Only police actors may board designated police vehicles.
