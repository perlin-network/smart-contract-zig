const std = @import("std");

extern "env" fn _send_transaction(tag: u8, payload_ptr: [*]const u8, payload_len: usize) void;

extern "env" fn _payload_len() usize;
extern "env" fn _payload(payload_ptr: [*]const u8) void;

extern "env" fn _result(data_ptr: [*]const u8, data_len: usize) void;

extern "env" fn _log(msg_ptr: [*]const u8, msg_len: usize) void;

extern "env" fn _verify_ed25519(key_ptr: [*]const u8, key_len: usize, data_ptr: [*]const u8, data_len: usize, sig_ptr: [*]const u8, sig_len: usize) void;
extern "env" fn _hash_blake2b_256(data_ptr: [*]const u8, data_len: usize, out_ptr: [*]const u8, out_len: usize) usize;
extern "env" fn _hash_blake2b_512(data_ptr: [*]const u8, data_len: usize, out_ptr: [*]const u8, out_len: usize) usize;
extern "env" fn _hash_sha256(data_ptr: [*]const u8, data_len: usize, out_ptr: [*]const u8, out_len: usize) usize;
extern "env" fn _hash_sha512(data_ptr: [*]const u8, data_len: usize, out_ptr: [*]const u8, out_len: usize) usize;

const heap = std.heap.wasm_allocator;

pub fn log(comptime fmt: []const u8, args: ...) void {
    var msg = std.fmt.allocPrint(heap, fmt, args) catch unreachable;
    _log(msg.ptr, msg.len);
}

pub fn abort(reason: []const u8) noreturn {
    _result(reason.ptr, reason.len);
    unreachable;
}

pub const Tag = enum(u8) {
    Nop,
    Transfer,
    Stake,
    Contract,
    Batch,
};

pub fn sendTransaction(tx: var) void {
    const T = @typeOf(tx);

    switch (T) {
        Transfer, Stake => {
            var payload = tx.marshal();
            defer heap.free(payload);

            _send_transaction(Tag, payload.ptr, payload.len);
        },
        else => @compileError("Unknown transaction type provided to sendTransaction(): " ++ @typeName(T)),
    }
}

pub const Transfer = struct {
    pub recipient_id: [32]u8,
    pub amount: u64,
    pub gas_limit: ?u64 = null,
    pub gas_deposit: ?u64 = null,
    pub func_name: ?[]u8 = null,
    pub func_params: ?[]u8 = null,

    pub fn marshal(self: Transfer) []u8 {
        if (self.gas_limit != null and self.gas_deposit != null and self.func_name != null and self.func_params != null) {
            var buf = heapAlloc(u8, 32 + 8 + 8 + 8 + 8 + 4 + self.func_name.?.len + 4 + self.func_params.?.len) catch unreachable;

            buf[0..32] = self.recipient_id[0..32];
            std.mem.writeIntSliceLittle(u64, buf[32 .. 32 + 8], self.amount);

            std.mem.writeIntSliceLittle(u64, buf[32 + 8 .. 32 + 8 + 8], self.gas_limit.?);
            std.mem.writeIntSliceLittle(u64, buf[32 + 8 + 8 .. 32 + 8 + 8 + 8], self.gas_deposit.?);

            std.mem.writeIntSliceLittle(u32, buf[32 + 8 + 8 + 8 .. 32 + 8 + 8 + 8 + 4], self.func_name.?.len);
            buf[32 + 8 + 8 + 8 + 4 .. 32 + 8 + 8 + 8 + 4 + self.func_name.?.len] = self.func_name.?[0..];

            std.mem.writeIntSliceLittle(u32, buf[32 + 8 + 8 + 8 + 4 + self.func_name.?.len .. 32 + 8 + 8 + 8 + 4 + self.func_name.?.len + 4], self.func_params.?.len);
            buf[32 + 8 + 8 + 8 + 4 + self.func_name.?.len + 4 .. 32 + 8 + 8 + 8 + 4 + self.func_name.?.len + 4 + self.func_params.?.len] = self.func_params.?[0..];

            return buf;
        } else {
            var buf = heapAlloc(u8, 32 + 8) catch unreachable;

            buf[0..32] = self.recipient_id[0..32];
            std.mem.writeIntSliceLittle(u64, buf[32 .. 32 + 8], self.amount);

            return buf[0 .. 32 + 8];
        }
    }
};

test "marshal transfer" {
    const t = Transfer{};
    std.debug.assert((Transfer{}).marshal().len == 32 + 8 + 8 + 8 + 4);
}

pub const Stake = struct {
    pub opcode: u8,
    pub amount: u64,

    pub fn marshal(self: Stake) []u8 {
        var buf = std.heap.wasm_allocaator.alloc(u8, 1 + 8);

        buf[0] = self.opcode;
        std.mem.writeIntSliceLittle(u64, buf[1 .. 1 + 8], self.amount);

        return buf;
    }
};

pub const Parameters = struct {
    pub round_index: u64,
    pub round_id: [32]u8,
    pub transaction_id: [32]u8,
    pub sender_id: [32]u8,
    pub amount: u64,
    pub parameters: []u8,

    pub fn init() Parameters {
        var buf: []const u8 = heapAlloc(u8, _payload_len()) catch unreachable;
        _payload(buf.ptr);

        comptime var c: u32 = 0; // cursor

        var round_index = std.mem.readIntSliceLittle(u64, read(c, buf, 8));
        var round_id = read(c, buf, 32);
        var transaction_id = read(c, buf, 32);
        var sender_id = read(c, buf, 32);

        var amount = std.mem.readIntSliceLittle(u64, read(c, buf, 8));

        return Parameters{
            .round_index = round_index,
            .round_id = round_id,
            .transaction_id = transaction_id,
            .sender_id = sender_id,
            .amount = amount,
            .parameters = buf[c..],
        };
    }
};

fn cast(t: type, buf: []u8) type {
    return @ptrCast(*t, buf.ptr).*;
}

// read trims the buf and return the trimmed part
inline fn read(cursor: *u32, buf: []u8, sz: u32) []u8 {
    const c = cursor.*;
    cursor.* += sz;
    return buf[c .. c + sz];
}

test "reader" {
    const msg: []u8 = &"Hello, 世界";
    var c: *u32 = &0;

    const hello = read(c, msg, 5);
    const comma = read(c, msg, 1);

    std.debug.assert(std.mem.eql(u8, hello, "Hello"));
    std.debug.assert(std.mem.eql(u8, comma, ","));
}
