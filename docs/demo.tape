# Regenerate with: vhs docs/demo.tape (run from the repo root)
Output docs/demo.gif

Require zig

Set Shell "bash"
Set FontSize 22
Set Width 1200
Set Height 700
Set Padding 20
Set TypingSpeed 40ms

Hide
Type "cd examples/basic && rm -rf zig-out .zig-cache && export PS1='$ ' && clear"
Enter
Sleep 500ms
Show

Type "cat build.zig"
Enter
Sleep 2s

Type "zig build && ./zig-out/bin/basic"
Enter
Wait+Screen /Hello, world!/
Sleep 1s

Type "zig build -Dtarget=aarch64-linux && file zig-out/bin/basic"
Enter
Wait+Screen /ELF 64-bit/
Sleep 2s
