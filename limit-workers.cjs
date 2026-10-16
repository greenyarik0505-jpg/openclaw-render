// Enforces strict single-worker scaling and V8 isolate resource limits on Render Free Tier
const os = require('node:os');
try {
  os.availableParallelism = () => 1;
  const origCpus = os.cpus.bind(os);
  os.cpus = () => [origCpus()[0] || { model: 'vCPU', speed: 2000, times: {} }];
} catch {}
const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const userLimits = options?.resourceLimits || {};
    const opts = {
      ...options,
      resourceLimits: {
        ...userLimits,
        maxOldGenerationSizeMb: 12,
        maxYoungGenerationSizeMb: 2,
        codeRangeSizeMb: 4,
        stackSizeMb: 1,
      }
    };
    super(filename, opts);
  }
}

wt.Worker = LimitedWorker;

