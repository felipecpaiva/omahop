// Spike S9b: does a Quickshell GlobalShortcut bound to ALT_L report the release after another key was pressed in between?
import QtQuick
import Quickshell
import Quickshell.Hyprland

ShellRoot {
  function stamp() { return (new Date()).toISOString().substr(17, 10) }
  GlobalShortcut { appid: "omahopspike"; name: "alt"; onPressed: console.log("GS alt PRESSED " + stamp()); onReleased: console.log("GS alt RELEASED " + stamp()) }
  GlobalShortcut { appid: "omahopspike"; name: "f10"; onPressed: console.log("GS f10 PRESSED " + stamp()); onReleased: console.log("GS f10 RELEASED " + stamp()) }
}
