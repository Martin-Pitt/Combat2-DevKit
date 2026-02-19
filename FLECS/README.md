# Flexible Experience-Based Combat System (FLECS)

FLECS is a scripted system for LLCS-based combat region (Linden Lab Combat System, e.g. when a parcel or region is set to damage and health shows in status bar).

FLECS builds upon [EBCS](https://github.com/soapyf/experience-based-combat-system), which is a similar system.

What FLECS does is a few steps further:
* It is modular
    * You can hotswap the scripted object responsible for the game mechanics and the HUD
* Uses the [Combat2.1 Polyfill](../Combat2-Polyfill.lsl) which allows you to use functions like `llSetTeam`, `llGetTeam`, `llGetTeamMemberList`, `llSetTeamRespawn` etc. that have not been implemented yet


## Setup

This system primarily works starting from an object called `FLECS` which has the scripts:
* [FLECS Config](./FLECS%20Config.lsl)
* [FLECS Manager](./FLECS%20Manager.lsl)
* [FLECS Fallback](./FLECS%20Fallback.lsl)
* [Sync LSD](./Sync%20LSD.lsl)

Additionally there are the modules which add game mechanics in separate objects, for example a basic module would have the following:
* [FLECS Basic](./FLECS%20Basic.lsl)
* [Sync LSD](./Sync%20LSD.lsl)

Additionally it should have an object named `FLECS Basic HUD` which has the `FLECS Basic HUD.lsl` script.

Note that you will need to customise the security settings for the scripts, namely:
* the `FLECS_SYSTEM_CHANNEL` and `FLECS_HUD_CHANNEL` channels to secret channel numbers
    * These should only be known to you and people you trust
* Sync LSD you will need to generate new RSA keys for `privateKey` and `publicKey` as well as `protectedKey` to some secret value
    * Before adding the Sync LSD script make sure to set the protected key on the object, e.g. `llLinksetDataWriteProtected(protectedName, "sync", protectedKey);`
    * The protected key helps avoid people from extracting the Sync LSD script from the no-modify script to put it into a different object, which would have allowed them to hijack your synchronised linkset data!

