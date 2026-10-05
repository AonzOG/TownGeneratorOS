# TownGeneratorOS — AonzOG Windows Installer 05/10/2026

This repository is a fork of **Watabou's TownGeneratorOS**, the source code of the **Medieval Fantasy City Generator**.

The original source code and original `README.md` are preserved. This fork adds a Windows installation and launch method intended to make the original Haxe/OpenFL project easier to install and run without manually configuring the development environment.

Original project:

- [Watabou/TownGeneratorOS](https://github.com/watabou/TownGeneratorOS)
- [Medieval Fantasy City Generator](https://watabou.itch.io/medieval-fantasy-city-generator/)

## AonzOG Windows Installer

The fork includes:

**`TownGeneratorOS_Installer.Bat`**

Double-click the installer to open a graphical Windows setup wizard.

The installer provides:

- 🖱️ GUI installation wizard
- 📁 Selectable installation directory
- 💻 Default installation directory: `C:\TownGeneratorOS`
- 🟢 Automatic installation of the compatible Haxe and Neko runtimes
- 📦 Automatic installation of the required Haxelib libraries
- 🏗️ Automatic HTML5 build of TownGeneratorOS
- ▶️ Automatic creation of `Start TownGeneratorOS.bat`
- 🔧 Repair installation
- 🗑️ Uninstall
- 🌐 Local browser-based launch
- 🔒 No permanent system PATH changes

## Compatible Runtime

TownGeneratorOS is an older Haxe/OpenFL project and requires versions compatible with the original source.

The installer uses the tested configuration:

- **Haxe 3.4.7 x86**
- **Neko 2.2.0 x86**
- **Lime 7.3.0**
- **OpenFL 8.9.0**
- **msignal 1.2.5**

The installer also checks for the **Microsoft Visual C++ 2013 x86 Runtime**, which is required by the historical Haxe/Haxelib toolchain, and installs it if necessary.

## HTML5 Build

TownGeneratorOS is compiled as an HTML5 application using:

```text
haxelib run lime build html5 -release -nocffi -Dcanvas
```

The Canvas renderer is used for compatibility with the original OpenFL 8.9.0 codebase and current web browsers.

## Running TownGeneratorOS

After installation, double-click:

**`Start TownGeneratorOS.bat`**

The launcher starts Lime's bundled local HTTP server and opens TownGeneratorOS in your default browser.

The application will normally open at an address similar to:

```text
http://127.0.0.1:8080/
```

The launcher window must remain open while TownGeneratorOS is running. Closing the launcher window stops the local server.

The server is bound to `127.0.0.1`, so TownGeneratorOS is available only on the local computer and is not exposed to other devices on the network.

## Installation

1. Download or clone this repository.
2. Double-click `TownGeneratorOS_Installer.Bat`.
3. Select **Install**.
4. Choose the installation directory or keep the default:

```text
C:\TownGeneratorOS
```

5. Allow the installer to download and configure the required runtime and libraries.
6. Wait for the HTML5 build to complete.
7. Launch TownGeneratorOS using `Start TownGeneratorOS.bat`.

No separate Haxe, Neko, Lime, OpenFL or msignal installation is required beforehand.

## Repair

Run `TownGeneratorOS_Installer.Bat` again and select **Repair**.

Repair reconstructs the installer-managed application, runtime, dependencies and HTML5 build using the known-compatible versions.

## Uninstall

Run `TownGeneratorOS_Installer.Bat` and select **Uninstall**.

The installer uses its installation marker to identify TownGeneratorOS installations created by the installer and includes safeguards against deleting unrelated directories.

## Why the Installer Uses Older Runtime Versions

TownGeneratorOS was written for an older Haxe/OpenFL ecosystem.

Modern Haxe releases are not fully source-compatible with the versions of OpenFL and Lime used by this project. For example, OpenFL 8.9.0 contains language constructs from the Haxe 3.x era that no longer compile correctly under Haxe 4.x.

The installer therefore deliberately uses the historical compatible toolchain rather than automatically installing the newest versions.

## Original README

Watabou's original `README.md` has been preserved unchanged.

Please refer to it for the original author's description of TownGeneratorOS and its source-code requirements.

## Vibe Code Alert

The AonzOG Windows installer and launcher were created with assistance from **GPT-5.6 Sol**.

They have **not** undergone an independent security audit or comprehensive static and dynamic cybersecurity assessment.

Both helper tools are plain-text Batch/PowerShell code, so you can inspect what they do before running them.

**The AonzOG Windows helper scripts are provided as-is and should be used at your own risk.**


## Licence and Attribution

TownGeneratorOS remains subject to the licence included in the original project.

The original Medieval Fantasy City Generator and TownGeneratorOS source code were created by **Watabou**.

The TownGeneratorOS_Installer.Bat is under The Unlicense (because it is vibe coded).

The Windows installer and installation workflow contained in this fork are additions for easier local installation and use of the original project.

# Medieval Fantasy City Generator
This is the source code of the [Medieval Fantasy City Generator](https://watabou.itch.io/medieval-fantasy-city-generator/) (also available [here](http://fantasycities.watabou.ru/?size=15&seed=682063530)). It 
lacks some of the latest features, namely waterbodies, options UI and some smaller ones. Maybe I'll update it later. 

You'll need [OpenFL](https://github.com/openfl/openfl) and [msignal](https://github.com/massiveinteractive/msignal) 
to run this code, both available through `haxelib`.
