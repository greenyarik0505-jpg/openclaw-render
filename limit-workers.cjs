const wt = require('node:worker_threads');
const OriginalWorker = wt.Worker;

class LimitedWorker extends OriginalWorker {
  constructor(filename, options = {}) {
    const userLimits = options?.resourceLimits || {};
    const opts = {
      ...options,
      resourceLimits: {
        ...userLimits,
        maxOldGenerationSizeMb: 24,
        maxYoungGenerationSizeMb: 4,
        codeRangeSizeMb: 8,
        stackSizeMb: 1,
      }
    };
    super(filename, opts);
  }
}

wt.Worker = LimitedWorker;


