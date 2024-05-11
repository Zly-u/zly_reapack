# Zly's ReaPack Repository

# About
A repo of scripts that I have made for simplifying and automating my personal Music/YTPMV work processes.

Each script's folder should contain a ReadMe describing what each script does, if it doesn't please poke me, I easily forget to do such things.


# Adding the Repo into [ReaPack](https://reapack.com/):
1. Add `https://github.com/Zly-u/zly_reapack/raw/master/index.xml` through: `Extensions` -> `ReaPack` -> `Import Repositories`
2. And, just in case: `Extensions` -> `ReaPack` -> `Synchronize Packages`


# TEMPLATES

### [ImGui_Script.lua](https://github.com/Zly-u/zly_reapack/blob/master/_Templates/ImGui_Script.lua)
An ImGui template script to easily start developing scripts with UIs.  
It already contains some helper functionality such as:
  * A base organisation for Window and UI development with [ReaImGui](https://github.com/cfillion/reaimgui).
  * Contains ReaImGui demo for the ease of learning UI dev for it.
  * Dependencies Checker.
  * Multiline String Constructor `MultLineStringConstructor(...)`.
  * Path Relative scripts requiring through `require(module)`.
  * Modified native `print(...)` function to work with Reaper's console.
  * `URL_Openner(URL)`.
  * Borrowed and slightly modified `InfoHelper` from ReaImGui: `ImGui_InfoMarker(ctx, desc)`.
  * Converts ReaImGui's and JS's functions into simplified OOP kinda oriented syntax, examples:
    * `reaper.ImGui_Begin(ctx)` -> `ImGui.Begin(ctx)`
    * `reaper.JS_Dialog_BrowseForOpenFiles(...)` -> `JS.Dialog_BrowseForOpenFiles(...)`
