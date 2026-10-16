// Enforces strict V8 isolate resource limits on all background worker threads
// to keep total multi-worker memory within the 512MB Linux cgroup on Render.
const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const opts = { ...options };
    opts.resourceLimits = {
      maxOldGenerationSizeMb: 16,
      maxYoungGenerationSizeMb: 4,
      codeRangeSizeMb: 8,
      stackSizeMb: 1,
      ...options.resourceLimits
    };
    super(filename, opts);
  }
}

wt.Worker = LimitedWorker;
