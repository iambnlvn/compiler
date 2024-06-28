# Compiler

Yet another tool that converts a sigx code syntax to its corresponding asm code.

# Usage

write a `code.sigx` file inside the src (command line args will probably be supported soon), and then compile the Zig code.<br>Run the run.sh and pass to it the gen.asm as its argument;<br>

Example:

```javascript
// ./src/code.sigx
a = 1111111
b = 3

while a > b
{
b  = b * 2
print b
}
```

```bash
zig run ./src/main.zig
```

**Note**:The previous command will generate a gen.asm inside `asm` directory.<br>

To execute the asm file, use the `run.sh` script.<br>
**Note**: the `run.sh` relies on [nasm](https://nasm.us/), make sure it's installed.

```bash
chmod +x ./asm/run.sh
./run.sh gen
```

**Note**: assembly file extension must be removed when passing the generated asm code as an argument(can be changed inside the run.sh tho).

# Side Notes

This is a basic implementation of a compiler, made for learning purposes.<br>
Might extend this to support functions, classes and other things...<br>
Why ? cuz why not ?<br>
