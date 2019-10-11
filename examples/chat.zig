const wavelet = @import("wavelet");

const max_log_capacity: i32 = 50;
const max_message_size: i32 = 240;

const Entry = struct {
    sender: [32]u8,
    message: [max_message_size]u8,
};

const Chat = struct {
    logs: []Entry,

    fn prune_old_messages(self: Chat) void {
        if (self.logs.len > max_log_capacity) {
            self.logs = self.logs[1..];
        }
    }

    fn _contract_init(params: wavelet.Parameters) Chat {
        return Chat{};
    }
};
