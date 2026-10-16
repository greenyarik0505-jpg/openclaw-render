const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const script = String(filename || '');
    // Heavy workers that evaluate SQLite schema or large preflight snapshots
    const isHeavyWorker = script.includes('sqlite') || script.includes('state') || script.includes('read') || script.includes('secret') || script.includes('auth');
    const maxOldMb = isHeavyWorker ? 48 : 20;
    const userLimits = options?.resourceLimits || {};
    const opts = {
      ...options,
      resourceLimits: {
        ...userLimits,
        maxOldGenerationSizeMb: maxOldMb,
        maxYoungGenerationSizeMb: isHeavyWorker ? 8 : 3,
        codeRangeSizeMb: isHeavyWorker ? 16 : 6,
        stackSizeMb: 1,
      }
    };
    super(filename, opts);
  }
}

wt.Worker = LimitedWorker;

// Run proactive GC on main thread every 12s to continuously release dead memory on 512MB cgroup
if (wt.isMainThread && typeof global.gc === 'function') {
  setInterval(() => {
    try {
      global.gc();
    } catch {}
  }, 12000).unref();
}
