const wavelet = @import("wavelet");

export fn _contract_init() void {}

export fn _contract_on_money_received() void {
    const params = wavelet.Parameters.init();

    wavelet.sendTransaction(wavelet.Transfer{ .recipient_id = params.sender_id, .amount = params.amount / 2 });
}
