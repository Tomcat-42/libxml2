# libxml2 zig

[libxml2](https://gitlab.gnome.org/GNOME/libxml2), packaged for the Zig build system.

## Using

```zig
const dep = b.dependency("libxml2", .{ .target = target, .optimize = optimize, .minimum = true, .valid = true });
exe.root_module.linkLibrary(dep.artifact("xml"));
```
