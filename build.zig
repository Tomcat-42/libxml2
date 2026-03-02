const std = @import("std");
const LinkMode = std.builtin.LinkMode;

const manifest = @import("build.zig.zon");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const os = target.result.os.tag;

    const options = .{
        .linkage = b.option(LinkMode, "linkage", "Library linkage type") orelse .static,
        .minimum = b.option(bool, "minimum", "Build a minimally sized library") orelse false,
        .valid = b.option(bool, "valid", "DTD validation support"),
        .threads = b.option(bool, "threads", "Multithreading support"),
        .catalog = b.option(bool, "catalog", "XML Catalogs support"),
        .debug = b.option(bool, "debug", "Debugging module"),
        .html = b.option(bool, "html", "HTML parser"),
        .iconv = b.option(bool, "iconv", "iconv support"),
        .iso8859x = b.option(bool, "iso8859x", "ISO-8859-X support if no iconv"),
        .sax1 = b.option(bool, "sax1", "Older SAX1 interface"),
        .xinclude = b.option(bool, "xinclude", "XInclude 1.0 support"),
        .output = b.option(bool, "output", "Serialization support"),
        .push = b.option(bool, "push", "Push parser interfaces"),
        .xpath = b.option(bool, "xpath", "XPath 1.0 support"),
        .pattern = b.option(bool, "pattern", "xmlPattern selection interface"),
        .regexps = b.option(bool, "regexps", "Regular expressions support"),
        .reader = b.option(bool, "reader", "xmlReader parsing interface"),
        .writer = b.option(bool, "writer", "xmlWriter serialization interface"),
        .c14n = b.option(bool, "c14n", "Canonical XML 1.0 support"),
        .schemas = b.option(bool, "schemas", "XML Schemas 1.0 support"),
        .relaxng = b.option(bool, "relaxng", "RELAX NG support"),
        .schematron = b.option(bool, "schematron", "Schematron support"),
        .xptr = b.option(bool, "xptr", "XPointer support"),
    };

    const minimum = options.minimum;
    const valid = options.valid orelse !minimum;
    const threads = options.threads orelse !minimum;
    const catalog = options.catalog orelse !minimum;
    const debug = options.debug orelse !minimum;
    const html = options.html orelse !minimum;
    const iconv_opt = options.iconv orelse (!minimum and target.query.isNative());
    const iso8859x = options.iso8859x orelse !minimum;
    const sax1 = options.sax1 orelse !minimum;
    const xinclude = options.xinclude orelse !minimum;

    const output = options.output orelse (!minimum or options.c14n == true or options.writer == true);
    const push = options.push orelse (!minimum or options.reader == true or options.writer == true);
    const xpath = options.xpath orelse (!minimum or options.c14n == true or options.schematron == true or options.xptr == true);
    const pattern = options.pattern orelse (!minimum or options.schemas == true or options.schematron == true);
    const regexps = options.regexps orelse (!minimum or options.relaxng == true or options.schemas == true);
    const reader = options.reader orelse (!minimum and push);
    const writer = options.writer orelse (!minimum and output and push);
    const c14n = options.c14n orelse (!minimum and output and xpath);
    const schemas = options.schemas orelse (!minimum and pattern and regexps);
    const relaxng = options.relaxng orelse (!minimum and schemas);
    const schematron = options.schematron orelse (!minimum and pattern and xpath);
    const xptr = options.xptr orelse (!minimum and xpath);

    const upstream = b.lazyDependency("libxml2_c", .{}) orelse return;
    const version: std.SemanticVersion = try .parse(manifest.version);

    const xml_version_header = b.addConfigHeader(.{
        .include_path = "libxml/xmlversion.h",
        .style = .{ .cmake = upstream.path("include/libxml/xmlversion.h.in") },
    }, .{
        .VERSION = manifest.version,
        .LIBXML_VERSION_NUMBER = @as(i64, @intCast(version.major * 1_00_00 + version.minor * 1_00 + version.patch)),
        .LIBXML_VERSION_EXTRA = "",
        .WITH_THREADS = threads,
        .WITH_THREAD_ALLOC = false,
        .WITH_OUTPUT = output,
        .WITH_PUSH = push,
        .WITH_READER = reader,
        .WITH_PATTERN = pattern,
        .WITH_WRITER = writer,
        .WITH_SAX1 = sax1,
        .WITH_HTTP = false,
        .WITH_VALID = valid,
        .WITH_HTML = html,
        .WITH_LEGACY = false,
        .WITH_C14N = c14n,
        .WITH_CATALOG = catalog,
        .WITH_XPATH = xpath,
        .WITH_XPTR = xptr,
        .WITH_XINCLUDE = xinclude,
        .WITH_ICONV = iconv_opt,
        .WITH_ICU = false,
        .WITH_ISO8859X = iso8859x,
        .WITH_DEBUG = debug,
        .WITH_REGEXPS = regexps,
        .WITH_RELAXNG = relaxng,
        .WITH_SCHEMAS = schemas,
        .WITH_SCHEMATRON = schematron,
        .WITH_MODULES = false,
        .MODULE_EXTENSION = null,
        .WITH_ZLIB = false,
    });

    const config_header = b.addConfigHeader(.{
        .include_path = "config.h",
        .style = .{ .cmake = upstream.path("config.h.cmake.in") },
    }, .{
        .HAVE_DECL_GETENTROPY = switch (os) {
            .linux => true,
            .freebsd, .openbsd => true,
            else => os.isDarwin(),
        },
        .HAVE_DECL_GLOB = os != .windows,
        .HAVE_DECL_MMAP = os != .windows and os != .wasi,
        .HAVE_DLOPEN = false,
        .HAVE_FUNC_ATTRIBUTE_DESTRUCTOR = true,
        .HAVE_LIBHISTORY = false,
        .HAVE_LIBREADLINE = false,
        .HAVE_SHLLOAD = false,
        .HAVE_STDINT_H = true,
        .XML_SYSCONFDIR = "/",
        .XML_THREAD_LOCAL = @as(?enum { _Thread_local }, null),
    });

    const mod = b.createModule(.{ .target = target, .optimize = optimize, .link_libc = true });
    mod.addConfigHeader(config_header);
    mod.addConfigHeader(xml_version_header);
    mod.addIncludePath(upstream.path("include"));
    mod.addCSourceFiles(.{ .root = upstream.path(""), .files = srcs, .flags = flags });
    if (os == .windows and options.linkage == .static) mod.addCMacro("LIBXML_STATIC", "1");

    if (c14n) mod.addCSourceFile(.{ .file = upstream.path("c14n.c"), .flags = flags });
    if (catalog) mod.addCSourceFile(.{ .file = upstream.path("catalog.c"), .flags = flags });
    if (debug) mod.addCSourceFile(.{ .file = upstream.path("debugXML.c"), .flags = flags });
    if (html) mod.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{ "HTMLparser.c", "HTMLtree.c" }, .flags = flags });
    if (output) mod.addCSourceFile(.{ .file = upstream.path("xmlsave.c"), .flags = flags });
    if (pattern) mod.addCSourceFile(.{ .file = upstream.path("pattern.c"), .flags = flags });
    if (reader) mod.addCSourceFile(.{ .file = upstream.path("xmlreader.c"), .flags = flags });
    if (regexps) mod.addCSourceFile(.{ .file = upstream.path("xmlregexp.c"), .flags = flags });
    if (relaxng) mod.addCSourceFile(.{ .file = upstream.path("relaxng.c"), .flags = flags });
    if (schemas) mod.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{ "xmlschemas.c", "xmlschemastypes.c" }, .flags = flags });
    if (schematron) mod.addCSourceFile(.{ .file = upstream.path("schematron.c"), .flags = flags });
    if (writer) mod.addCSourceFile(.{ .file = upstream.path("xmlwriter.c"), .flags = flags });
    if (xinclude) mod.addCSourceFile(.{ .file = upstream.path("xinclude.c"), .flags = flags });
    if (xpath) mod.addCSourceFile(.{ .file = upstream.path("xpath.c"), .flags = flags });
    if (xptr) mod.addCSourceFiles(.{ .root = upstream.path(""), .files = &.{ "xlink.c", "xpointer.c" }, .flags = flags });

    if (os == .windows) mod.linkSystemLibrary("bcrypt", .{});
    if (iconv_opt and os.isBSD()) mod.linkSystemLibrary("iconv", .{});

    const lib = b.addLibrary(.{
        .name = "xml",
        .root_module = mod,
        .linkage = options.linkage,
        .version = version,
    });
    lib.installHeader(xml_version_header.getOutputFile(), "libxml/xmlversion.h");
    lib.installHeadersDirectory(upstream.path("include/libxml"), "libxml", .{});
    b.installArtifact(lib);
}

const flags: []const []const u8 = &.{
    "-pedantic",       "-Wall",                  "-Wextra",
    "-Wshadow",        "-Wpointer-arith",        "-Wcast-align",
    "-Wwrite-strings", "-Wstrict-prototypes",    "-Wmissing-prototypes",
    "-Wno-long-long",  "-Wno-format-extra-args", "-Wno-array-bounds",
};

const srcs: []const []const u8 = &.{
    "buf.c",       "chvalid.c",         "dict.c",
    "entities.c",  "encoding.c",        "error.c",
    "globals.c",   "hash.c",            "list.c",
    "parser.c",    "parserInternals.c", "SAX2.c",
    "threads.c",   "tree.c",            "uri.c",
    "valid.c",     "xmlIO.c",           "xmlmemory.c",
    "xmlstring.c",
};
