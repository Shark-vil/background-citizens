slib.Animator = slib.Animator or {}

slib.Components = slib.Components or {}
slib.Components.GUI = slib.Components.GUI or {}
slib.Components.Network = slib.Components.Network or {}
slib.Components.GlobalCvar = slib.Components.GlobalCvar or {}
slib.Components.GlobalCommand = slib.Components.GlobalCommand or {}
slib.Components.FakePlayer = slib.Components.FakePlayer or {}
slib.Components.Animator = slib.Components.Animator or {}

slib.Storage = slib.Storage or {}
slib.Storage.Network = slib.Storage.Network or {}
slib.Storage.LoadedPlayers = slib.Storage.LoadedPlayers or {}
slib.Storage.GlobalCvar = slib.Storage.GlobalCvar or {}
slib.Storage.Animations = slib.Storage.Animations or {}
slib.Storage.ActiveAnimations = slib.Storage.ActiveAnimations or {}

-- Quick access to modules
snet = slib.Components.Network
sgui = slib.Components.GUI
scvar = slib.Components.GlobalCvar
scommand = slib.Components.GlobalCommand

-- slib.Network = slib.Components.Network
-- slib.GUI = slib.Components.GUI
-- slib.SharedCvars = slib.Components.GlobalCvar
-- slib.SharedCommands = slib.Components.GlobalCommand