build:
	for f in examples/*.zig ; do zig fmt $$f ; done
	for f in examples/*.zig ; do zig build-lib -target wasm32-freestanding --output-dir release/ --pkg-begin wavelet wavelet/wavelet.zig --pkg-end --release-small $$f; done
