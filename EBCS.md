# Experience-Based Combat System

Available here: https://github.com/soapyf/experience-based-combat-system

Experience-Based Combat System or EBCS is a scripted system for LLCS-based combat regions. LLCS is the Linden Lab Combat System, e.g. when a parcel or region is set to damage and health shows in the status bar at the top. EBCS as the name implies uses Experience permissions to handle `on_death` events, create and manage safezones, and teleporting agents to set spawn points.

The system primarily works via server (ebcs_controller.lsl) and a HUD attachment (ebcs_handler.lsl).

There is also a click button script (ebcs_kiosk.lsl) that allows agents who had previously denied the experience permissions or did not have a free attachment slot to re-attempt the HUD attachment.
