This is a highly capable Discord bot for Lua analysis, deobfuscation, obfuscation, and sandboxed Luau execution, and JavaScript obfuscation.

Commands use the prefix configured by `PREFIX` (the examples below use `.`). Attach a file, paste a code block, or provide a supported raw URL when a command asks for a script.

## Commands

| Command | Aliases | Description |
| --- | --- | --- |
| `.help [command]` | `.cmds` | List commands or show one command's details. |
| `.bypass <url>` | - | Bypass an ad link. |
| `.l` | `.dump`, `.envlog` | Dump a Roblox Lua script. |
| `.http` | `.httpd`, `.httpdump`, `.httplog`, `.httpl`, `.lhttp` | Dump HTTP usage from a Lua script. |
| `.decompress` | `.ld` | Log all `loadstring` calls in a script. |
| `.luraphdump` | `.luraph`, `.luraphd`, `.lphdump`, `.lphd` | Log constants from a Luraph-obfuscated script. |
| `.ibdump` | `.ib`, `.ibd`, `.ibdumper`, `.ib2dump`, `.ib2dumper`, `.ib2`, `.ib2d` | Dump deserialized data from an IronBrew2 or LuaObfuscator script. |
| `.detect` | - | Detect the obfuscator used by a file. |
| `.prometheusdeobf` | `.promdeobf`, `.wrddeobf`, `.wearedevsdeobf` | Deobfuscate a Prometheus-obfuscated file. |
| `.ib2deobf` | `.ironbrew2deobf`, `.ironbrewdeobf`, `.ibdeobf`, `.luaobfvmdeobf` | Deobfuscate IronBrew2 or LuaObfuscator VM-mode files. Can only run on Windows server hosts. |
| `.msdeobf` | `.moonsecdeobf`, `.moonsecv3deobf`, `.msv3deobf`, `.msibdeobf` | Deobfuscate a MoonSec v3 file. Can only run on Windows server hosts. |
| `.luaobf` | `.noluaobf` | Deobfuscate LuaObfuscator string-encryption files. |
| `.decompile` | `.lua51dec`, `.luadecomp`, `.ldecomp`, `.ldecompile`, `.l51dec`, `.l51decomp`, `.l51decompile` | Decompile Lua 5.1 bytecode. Luau bytecode is not supported. Can only run on Windows server hosts. |
| `.isbytecode` | - | Identify Lua 5.1 or Luau bytecode and show header information. |
| `.obfuscate` | `.obf`, `.obfuscator` | Obfuscate a Lua script. |
| `.jsobf` | `.jsobfuscate`, `.jsobfuscator`, `.obfjs`, `.obfuscatejs`, `.obfuscatorjs` | Obfuscate a JavaScript file. |
| `.beautify` | `.bf`, `.coolify` | Beautify a Lua script. |
| `.minify` | `.mf`, `.uncoolify` | Minify a Lua script. |
| `.compress` | - | Compress a Luau script. |
| `.luau` | - | Run a standalone Luau script in the sandbox. Roblox globals are not available. |
| `.get <url>` | `.httpget`, `.wget`, `.gethttp` | Fetch a website and return its data as a file. |
| `.recipe` | - | Return a random recipe. |
| `.usage [@user]` | `.uses`, `.usages` | Show a user's Skidware usage count. |
| `.leaderboard` | `.lb` | Show the top 10 Skidware users. |
| `.membercount` | `.mc` | Show the current server's member count. |
| `.stats` | `.statistics`, `.data` | Show server statistics. |
| `.chat <message>` | - | Chat with the configured AI service. |
| `.deepseek <prompt>` | - | Ask the configured DeepSeek service a question. |

### Moderator commands

These commands require an authorized user:

- `.blacklist @user` / `.plsstopusingthis`: blacklist a user.
- `.unblacklist @user` / `.plsreusethis`: remove a user's blacklist.
- `.viewObfuscationRuns`: Views all unobfuscated files passed through the obfuscator.
- `.viewLoggerRuns`: Views all .l'ed files
- `.viewLuauRuns`: Views all .luau'ed files

### Platform notes

`.ib2deobf`, `.msdeobf`, and `.decompile` are disabled on Linux because they depend on Windows executables. Use `.help` in Discord for the live command list.