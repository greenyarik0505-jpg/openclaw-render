const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const script = String(filename || '');
    // 1. Heartbeats and lifecycles: tiny footprint
    const isHeartbeat = script.includes('heartbeat') || script.includes('lifecycle') || script.includes('lease');
    // 2. Heavy worker: ONLY the primary sqlite-store worker and secret decryptor
    const isHeavyWorker = !isHeartbeat && (script.includes('sqlite-store') || script.includes('store.worker') || script.includes('secret'));
    // 3. Regular workers: read, state context, etc.
    const maxOldMb = isHeavyWorker ? 45 : (isHeartbeat ? 10 : 20);
    const maxYoungMb = isHeavyWorker ? 4 : 2;
    const userLimits = options?.resourceLimits || {};
    const opts = {
      ...options,
      resourceLimits: {
        ...userLimits,
        maxOldGenerationSizeMb: maxOldMb,
        maxYoungGenerationSizeMb: maxYoungMb,
        codeRangeSizeMb: isHeavyWorker ? 8 : 0,
        stackSizeMb: 1,
      }
    };
    super(filename, opts);
  }
}

wt.Worker = LimitedWorker;

// Run proactive GC on main thread every 5s to continuously release dead memory on 512MB cgroup
if (wt.isMainThread && typeof global.gc === 'function') {
  setInterval(() => {
    try {
      global.gc();
    } catch {}
  }, 5000).unref();
}

