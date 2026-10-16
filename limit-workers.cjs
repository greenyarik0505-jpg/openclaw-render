const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const script = String(filename || '');
    const isHeavyWorker = script.includes('sqlite') || script.includes('state') || script.includes('read') || script.includes('session') || script.includes('agent');
    const maxOldMb = isHeavyWorker ? 48 : 24;
    const userLimits = options?.resourceLimits || {};
    const opts = {
      ...options,
      resourceLimits: {
        ...userLimits,
        maxOldGenerationSizeMb: maxOldMb,
        maxYoungGenerationSizeMb: isHeavyWorker ? 8 : 4,
        codeRangeSizeMb: isHeavyWorker ? 16 : 8,
        stackSizeMb: 1,
      }
    };
    super(filename, opts);
  }
}

wt.Worker = LimitedWorker;

// Run periodic GC on main thread to actively release dead bootstrap memory
if (wt.isMainThread && typeof global.gc === 'function') {
  setInterval(() => {
    try {
      global.gc();
    } catch {}
  }, 15000).unref();
}


