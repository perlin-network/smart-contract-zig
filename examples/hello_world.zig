const wavelet = @import("wavelet");

export fn _contract_init() void {
    const params = wavelet.Parameters.init();

    wavelet.log("hello from zig! the round id is: {}", params.round_index);
}
