use deno_bench_util::{bench_js_sync, bench_js_sync_with, bench_js_async_with, BenchOptions };
use deno_bench_util::bench_or_profile;
use deno_bench_util::bencher::benchmark_group;
use deno_bench_util::bencher::Bencher;
use deno_core::Extension;
use deno_core::op2;
use deno_core::extension;

#[op2(fast)]
#[number]
fn op_nop() -> usize {
    9
}

fn setup() -> Vec<Extension> {
    extension!(
        bench_setup,
        ops = [op_nop],
        esm_entry_point = "ext:bench_setup/setup.js",
        esm = ["ext:bench_setup/setup.js" = {
            source = r#"
            globalThis.op_nop = Deno.core.ops.op_nop;
            globalThis.js_nop = () => 9;
            "#
        }]
    );
    vec![bench_setup::init_ops_and_esm()]
}

static BENCH1: BenchOptions = BenchOptions { benching_inner: 1, profiling_inner: 1_000, profiling_outer: 10_000 };

fn bench_op_sync1(b: &mut Bencher) {
    bench_js_sync_with(b, r#"op_nop();"#, setup, BENCH1);
}

fn bench_op_sync1000(b: &mut Bencher) {
    bench_js_sync(b, r#"op_nop();"#, setup);
}

fn bench_js_sync1(b: &mut Bencher) {
    bench_js_sync_with(b, r#"js_nop();"#, setup, BENCH1);
}

fn bench_js_sync1000(b: &mut Bencher) {
    bench_js_sync(b, r#"js_nop();"#, setup);
}

fn bench_op_async1(b: &mut Bencher) {
    bench_js_async_with(b, r#"op_nop();"#, setup, BENCH1);
}

benchmark_group!(benches, bench_op_sync1, bench_op_sync1000, bench_js_sync1, bench_js_sync1000, bench_op_async1);
bench_or_profile!(benches);
