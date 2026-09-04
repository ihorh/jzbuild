# Regenerate with: vhs docs/demo.tape (run from the repo root)
Output docs/demo.gif

Require zig
Require bat

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

Type "bat --style=header --paging=never --color=always build.zig src/main.c"
Enter
Sleep 3s

Type "zig build && ./zig-out/bin/basic"
Enter
Wait+Screen /Hello, world!/
Sleep 1s

Type "file zig-out/bin/basic"
Enter
Wait+Screen /Mach-O/
Sleep 2s

Type "zig build -Dtarget=x86_64-linux && file zig-out/bin/basic"
Enter
Wait+Screen /ELF 64-bit/
Sleep 6s
