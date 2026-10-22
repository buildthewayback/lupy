LUPY 3 — INSTALL (self-contained installer, no Terminal)

Use the LUPY Installer DMG (or the matching ZIP if DMG is not convenient):

1. Double-click the DMG.
2. Double-click “Install LUPY”.
   The complete installation kit is inside that app and is checked before use.
   It does not need the files around it, so it still works if macOS runs it
   from its temporary download location or if you copy it somewhere else.
3. If macOS says it cannot verify the installer, open
   System Settings → Privacy & Security, choose “Open Anyway” for Install
   LUPY, then open it again. This one-time step is needed because this private
   build is ad-hoc signed rather than notarized with a paid Apple account.
4. Click “Install LUPY” and keep the Setup window in view or minimized.

The Setup window names all six stages — Check this Mac; Apple's free tools;
Download one small library; Compile LUPY; Install into Applications; Launch &
prove he's alive — and keeps the percentage on its Dock icon while minimized.
The installer does not ask for repository passwords. It does need internet on
the first install for Apple's tools (if missing) and one small public library.

At the end it proves, rather than merely claims, that Lupy.app is in
Applications, carries his icon, has its program inside, and is running under
your menu bar. If a stage stops, the same final screen names it and a
plain-words report is written for diagnosis.

After installation, use Lupy from Applications like any other Mac app. The
installer DMG/ZIP no longer needs to stay beside him.

Needs: macOS 15 or newer, Apple Silicon, and permission to write to
/Applications. No Xcode download is required; Apple's free Command Line Tools
are enough and the installer offers them if they are missing.

Developer/backup road: the source kit's “Install LUPY.command” performs the
same local build in Terminal.
