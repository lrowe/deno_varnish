// Copyright 2018-2025 the Deno authors. MIT license.

#![allow(clippy::print_stdout)]
#![allow(clippy::print_stderr)]

use std::cell::Ref;
use std::cell::RefCell;
use std::path::Path;
use std::ffi::c_void;
use std::rc::Rc;
use std::sync::Arc;
use std::time::Instant;

use deno_core::FsModuleLoader;
use deno_core::ModuleSpecifier;
use deno_core::anyhow;
use deno_core::external;
use deno_core::ExternalPointer;
use deno_core::op2;
//use deno_core::OpState;
use deno_core::v8;
use deno_core::v8_set_flags;
use deno_resolver::npm::DenoInNpmPackageChecker;
use deno_resolver::npm::NpmResolver;
use deno_runtime::deno_fs::RealFs;
use deno_runtime::deno_permissions::PermissionsContainer;
use deno_runtime::permissions::RuntimePermissionDescriptorParser;
use deno_runtime::worker::MainWorker;
use deno_runtime::worker::WorkerOptions;
use deno_runtime::worker::WorkerServiceOptions;

#[allow(dead_code)]
mod varnish;

// This is likely overcomplicated but do same as Deno http serve for now.
struct HttpRecordInner {
    pub request: varnish::Request,
    pub start: Instant,
}

struct HttpRecord(RefCell<Option<HttpRecordInner>>);

#[repr(transparent)]
struct RcHttpRecord(Rc<HttpRecord>);

// Register the [`HttpRecord`] as an external.
external!(RcHttpRecord, "varnish http record");

impl HttpRecord {
    fn is_warmup(&self) -> bool {
        self.0.borrow().is_none()
    }
    fn self_ref(&self) -> Ref<'_, HttpRecordInner> {
        Ref::map(self.0.borrow(), |option| option.as_ref().unwrap())
    }
    pub fn request(&self) -> Ref<'_, varnish::Request> {
        Ref::map(self.self_ref(), |inner| &inner.request)
    }
}


/// Construct Rc<HttpRecord> from raw external pointer, consuming
/// refcount. You must make sure the external is deleted on the JS side.
macro_rules! take_external {
  ($external:expr, $args:tt) => {{
    let ptr = ExternalPointer::<RcHttpRecord>::from_raw($external);
    ptr.unsafely_take().0
  }};
}

/// Clone Rc<HttpRecord> from raw external pointer.
macro_rules! clone_external {
  ($external:expr, $args:tt) => {{
    let ptr = ExternalPointer::<RcHttpRecord>::from_raw($external);
    ptr.unsafely_deref().0.clone()
  }};
}

#[op2(fast)]
fn op_varnish_backend_response(external: *const c_void, status: u16, #[string] ctype: &str, #[arraybuffer] data: &[u8]) {
    // SAFETY: JS does not use external after this.
    let http = unsafe { take_external!(external, "op_varnish_backend_response") };
    if http.is_warmup() {
        return;
    }
    let us = http.0.take().unwrap().start.elapsed().as_micros();
    eprintln!("{}", format!("deno request time {us} us"));
    varnish::backend_response(status, ctype, data);
}

#[op2(fast)]
fn op_varnish_wait_for_requests_paused(warmups: i32) -> *const c_void {
    let inner = if warmups > 0 {
        None
    } else {
        let request = varnish::wait_for_requests_paused();
        let start = Instant::now();
        Some(HttpRecordInner { request, start })
    };
    let ptr = ExternalPointer::new(RcHttpRecord(Rc::new(HttpRecord(RefCell::new(inner)))));
    ptr.into_raw()
}

#[op2]
#[string]
fn op_varnish_request_url(external: *const c_void) -> String {
    // SAFETY: op is called with external.
    let http = unsafe { clone_external!(external, "op_varnish_request_url") };
    if http.is_warmup() {
        return String::from("/");
    }
    http.request().url().to_string()
}

deno_runtime::deno_core::extension!(
    varnish_runtime,
    ops = [
        op_varnish_backend_response,
        op_varnish_wait_for_requests_paused,
        op_varnish_request_url,
    ],
    esm_entry_point = "ext:varnish_runtime/bootstrap.js",
    esm = [dir "src", "bootstrap.js"]
);

// From deno cli/util/v8.rs
#[inline(always)]
pub fn get_v8_flags_from_env() -> Vec<String> {
    std::env::var("DENO_V8_FLAGS")
        .ok()
        .map(|flags| flags.split(',').map(String::from).collect::<Vec<String>>())
        .unwrap_or_default()
}

fn main() -> Result<(), anyhow::Error> {
    if std::env::var("BREAKPOINT_MAIN").is_ok() {
        varnish::breakpoint();
    }

    // Just use last argument as script until TinyKVM transition to env vars is complete.
    let mut args = ::std::env::args_os();
    let script = args.next_back().unwrap();

    let mut v8_flags = vec![
        "UNUSED_BUT_NECESSARY_ARG0".to_string(),
        "--stack-size=1024".to_string(),
        "--no-harmony-import-assertions".to_string(),
        // Required for v8::Platform::new_single_threaded
        "--single-threaded".to_string(),
    ];
    v8_flags.extend(get_v8_flags_from_env());
    let unrecognized = v8_set_flags(v8_flags);
    for flag in unrecognized.iter().skip(1) {
        eprintln!("{}", format!("Unrecognized v8 flag {flag}"));
    }

    let v8_platform = v8::Platform::new_single_threaded(true).make_shared();
    deno_core::JsRuntime::init_platform(Some(v8_platform), false);
    let main_module = ModuleSpecifier::from_file_path(Path::new(&script)).unwrap();
    eprintln!("{}", format!("Running {main_module}..."));
    let fs = Arc::new(RealFs);
    let permission_desc_parser = Arc::new(RuntimePermissionDescriptorParser::new(
        sys_traits::impls::RealSys,
    ));

    let mut worker = MainWorker::bootstrap_from_options(
        &main_module,
        WorkerServiceOptions::<
            DenoInNpmPackageChecker,
            NpmResolver<sys_traits::impls::RealSys>,
            sys_traits::impls::RealSys,
        > {
            module_loader: Rc::new(FsModuleLoader),
            permissions: PermissionsContainer::allow_all(permission_desc_parser),
            blob_store: Default::default(),
            broadcast_channel: Default::default(),
            feature_checker: Default::default(),
            node_services: Default::default(),
            npm_process_state_provider: Default::default(),
            root_cert_store_provider: Default::default(),
            fetch_dns_resolver: Default::default(),
            shared_array_buffer_store: Default::default(),
            compiled_wasm_module_store: Default::default(),
            v8_code_cache: Default::default(),
            fs,
        },
        WorkerOptions {
            extensions: vec![varnish_runtime::init_ops_and_esm()],
            ..Default::default()
        },
    );

    tokio::runtime::Builder::new_current_thread()
        .build()
        .unwrap()
        .block_on(async {
            worker.execute_main_module(&main_module).await?;
            worker.run_event_loop(false).await?;
            Ok::<(), anyhow::Error>(())
        })
}
