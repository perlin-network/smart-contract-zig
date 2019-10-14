const std = @import("std");
const hextable = "0123456789abcdef";

pub fn encodedLen(n: u64) u64 {
    return n * 2;
}

pub fn encode(dst: []u8, src: []u8) void {
    var j: u64 = 0;
    for (src) |v| {
        dst[j] = hextable[v >> 4];
        dst[j + 1] = hextable[v & 0x0f];
        j += 2;
    }

    return;
}

test "encode hex" {
    var string = "shiota nagisa";
    var dest: [encodedLen(string.len)]u8 = undefined;

    encode(dest[0..dest.len], string[0..string.len]);

    std.debug.assert(std.mem.eql(u8, dest, "7368696f7461206e6167697361"));
}

pub fn decodedLen(n: u64) u64 {
    return n / 2;
}

pub fn decode(dst: []u8, src: []u8) !void {
    var i: u64 = 0;
    var j: u64 = 1;

    while (j < src.len) : (j += 2) {
        var a = fromHexChar(src[j - 1]) orelse return error.InvalidByte;
        var b = fromHexChar(src[j]) orelse return error.InvalidByte;

        dst[i] = (a << @intCast(u3, b)) | b;
        i += 1;
    }

    if (src.len % 2 == 1) {
        if (fromHexChar(src[j - 1]) == null) {
            return error.InvalidByte;
        }

        return error.ErrLength;
    }

    return;
}

fn fromHexChar(c: u8) ?u8 {
    return switch (c) {
        ('0' <= c and c <= '9') => c - '0',
        ('a' <= c and c <= 'f') => c - 'a' + 10,
        ('A' <= c and c <= 'F') => c - 'A' + 10,
        else => null,
    };
}

test "decode hex" {
    var string = "7368696f7461206e6167697361";
    var dest: [decodedLen(string.len)]u8 = undefined;

    decode(dest[0..dest.len], string[0..string.len]);

    std.debug.assert(std.mem.eql(u8, dest, "shiota nagisa"));
}
