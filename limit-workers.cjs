const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const script = String(filename || '');
    const isDbWorker = script.includes('sqlite-store') || script.includes('store.worker') || script.includes('secret');
    const isStateWorker = script.includes('state') || script.includes('read') || script.includes('auth') || script.includes('session') || script.includes('heartbeat');
    const maxOldMb = isDbWorker ? 48 : (isStateWorker ? 32 : 16);
    const maxYoungMb = isDbWorker ? 3 : 2;
    const userLimits = options?.resourceLimits || {};
    const opts = {
      ...options,
      resourceLimits: {
        ...userLimits,
        maxOldGenerationSizeMb: maxOldMb,
        maxYoungGenerationSizeMb: maxYoungMb,
        codeRangeSizeMb: 4,
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

