const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const script = String(filename || '');
    const isHeavyWorker = script.includes('sqlite') || script.includes('state') || script.includes('read');
    const maxOldMb = isHeavyWorker ? 44 : 16;
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


