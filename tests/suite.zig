const std = @import("std");
const pcre2 = @import("pcre2");

test "hola" {
    std.debug.print(pcre2.pcre2, .{});
}
