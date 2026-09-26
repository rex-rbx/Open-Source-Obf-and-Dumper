const calculateTimeout = require('./timeout.js');
const {
  spawn,
  execSync
} = require('child_process');
const path = require('path');
const os = require('os');
const fsSync = require('fs');
const isLinux = os.platform() === 'linux';
const isWindows = os.platform() === 'win32';
const IMAGES = {
  base: 'unveilr-sandbox:latest'
};
let _backend = null;
function getBackend() {
  if (_backend !== null) return _backend;
  try {
    execSync('docker info', {
      stdio: 'ignore',
      timeout: 10_000
    });
    _backend = 'docker';
    console.log('[sandbox] Docker backend');
    return _backend;
  } catch {}
  if (isLinux) {
    try {
      execSync('bwrap --version', {
        stdio: 'ignore',
        timeout: 5000
      });
      _backend = 'bwrap';
      console.log('[sandbox] bwrap backend (Docker not available)');
      return _backend;
    } catch {}
  }
  _backend = 'none';
  console.error('[sandbox] ⚠️  NO SANDBOX BACKEND! Install Docker. Untrusted code will be REFUSED.');
  return _backend;
}
async function init() {
  const backend = getBackend();
  if (backend !== 'docker') return;
  for (const image of Object.values(IMAGES)) {
    try {
      execSync("docker image inspect ".concat(image), {
        stdio: 'ignore',
        timeout: 5000
      });
      console.log("[sandbox] Image ".concat(image, " ready"));
    } catch {
      console.log("[sandbox] Building ".concat(image, "..."));
      try {
        execSync("docker build -t ".concat(image, " -f sandbox/Dockerfile sandbox"), {
          stdio: 'inherit',
          timeout: 120_000
        });
      } catch (err) {
        console.error("[sandbox] Failed to build ".concat(image, ":"), err.message);
      }
    }
  }
}
function abs(p, relativeTo) {
  if (path.isAbsolute(p)) return p;
  return path.resolve(relativeTo || process.cwd(), p);
}
function dockerSpawn(cmdArgs, options) {
  const {
    image = IMAGES.base,
    mounts = [],
    workdir = '/sandbox',
    entrypoint,
    env = {},
    memory = '512m',
    cpus = 1,
    pidsLimit = 100,
    allowNet = false,
    spawnOptions = {},
    timeout = 25000
  } = options;
  const cidDir = fsSync.mkdtempSync(path.join(os.tmpdir(), 'rfdist-docker-'));
  const cidFile = path.join(cidDir, 'container.id');
  const dockerArgs = ['run', '--rm', '--network', allowNet ? 'bridge' : 'none', '--read-only', '--security-opt', 'no-new-privileges', '--cap-drop', 'ALL', '--memory', memory, '--cpus', String(cpus), '--pids-limit', String(pidsLimit), '--tmpfs', '/tmp:size=64m', '--user', '65534:65534'];
  dockerArgs.push('--cidfile', cidFile);
  for (const m of mounts) {
    const hostPath = abs(m.host);
    const mount = "type=bind,source=".concat(hostPath, ",target=").concat(m.container);
    dockerArgs.push('--mount', m.mode === 'rw' ? mount : "".concat(mount, ",readonly"));
  }
  if (entrypoint) {
    dockerArgs.push('--entrypoint', entrypoint);
  }
  dockerArgs.push('-w', workdir);
  for (const [key, value] of Object.entries(env)) {
    dockerArgs.push('-e', "".concat(key, "=").concat(value));
  }
  dockerArgs.push(image, ...cmdArgs);
  const proc = spawn('docker', dockerArgs, {
    ...spawnOptions,
    stdio: ['ignore', 'pipe', 'pipe']
  });
  let timeoutId = null;
  let forceKillId = null;
  const killContainer = () => {
    let containerId;
    try {
      containerId = fsSync.readFileSync(cidFile, 'utf8').trim();
    } catch {}
    if (!containerId) return;
    // Stop the container through the Docker CLI. Do not signal the Docker
    // daemon; proc is only the client attached to this container.
    spawn('docker', ['kill', '--signal=KILL', containerId], {
      stdio: 'ignore'
    });
  };
  if (timeout > 0) {
    timeoutId = setTimeout(() => {
      killContainer();
      proc.kill('SIGTERM');
      forceKillId = setTimeout(() => {
        if (proc.exitCode === null && !proc.signalCode) {
          proc.kill('SIGKILL');
        }
      }, 4000);
    }, timeout);
  }
  let stdout = '';
  let stderr = '';
  let output = '';
  proc.stdout?.on('data', data => {
    const str = data.toString();
    stdout += str;
    output += str;
  });
  proc.stderr?.on('data', data => {
    const str = data.toString();
    stderr += str;
    output += str;
  });
  proc._stdout = stdout;
  proc._stderr = stderr;
  proc._output = output;
  proc.waitForExit = new Promise(resolve => {
    proc.on('close', code => {
      if (timeoutId) clearTimeout(timeoutId);
      if (forceKillId) clearTimeout(forceKillId);
      try {
        fsSync.rmSync(cidDir, { recursive: true, force: true });
      } catch {}
      const finalStdout = stdout || proc._stdout || '';
      const finalStderr = stderr || proc._stderr || '';
      const finalOutput = output || proc._output || '';
      resolve({
        code,
        stdout: finalStdout,
        stderr: finalStderr,
        output: finalOutput
      });
    });
  });
  return proc;
}
function bwrapSpawn(command, args, options = {}) {
  const {
    cwd = process.cwd(),
    readOnly = [],
    readWrite = [],
    allowNet = false,
    spawnOptions = {}
  } = options;
  const resolvedCwd = abs(cwd);
  const resolvedCommand = abs(command, resolvedCwd);
  const bwrapArgs = [];
  for (const p of ['/usr', '/lib', '/lib64', '/bin', '/sbin', '/etc/alternatives', '/etc/ld.so.cache', '/etc/ld.so.conf', '/etc/ld.so.conf.d', '/etc/ssl', '/etc/ca-certificates']) {
    try {
      fsSync.statSync(p);
      bwrapArgs.push('--ro-bind', p, p);
    } catch {}
  }
  bwrapArgs.push('--proc', '/proc');
  bwrapArgs.push('--dev', '/dev');
  bwrapArgs.push('--tmpfs', '/tmp');
  for (const ro of readOnly) {
    const r = abs(ro, resolvedCwd);
    bwrapArgs.push('--ro-bind', r, r);
  }
  for (const rw of readWrite) {
    const r = abs(rw, resolvedCwd);
    bwrapArgs.push('--bind', r, r);
  }
  if (!allowNet) bwrapArgs.push('--unshare-net');
  bwrapArgs.push('--unshare-pid', '--unshare-ipc', '--new-session', '--die-with-parent', '--chdir', resolvedCwd, '--', resolvedCommand, ...args);
  return spawn('bwrap', bwrapArgs, {
    ...spawnOptions,
    cwd: resolvedCwd
  });
}
const profiles = {
  lune(luneBinary, args, unveilrDir) {
    const resolved = abs(unveilrDir);
    const backend = getBackend();
    if (backend === 'docker') {
      return dockerSpawn(['lune', ...args], {
        image: IMAGES.base,
        entrypoint: '/usr/bin/env',
        env: {
          HOME: '/opt',
          LUTE_BIN: '/usr/local/bin/lute',
          PATH: '/opt/.rokit/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        },
        mounts: [{
          host: path.join(__dirname, 'httplog2.lua'),
          container: '/unveilr/httplog2.lua',
          mode: 'ro'
        },{
          host: path.join(__dirname, 'httplog.lua'),
          container: '/unveilr/httplog.lua',
          mode: 'ro'
        },{
          host: path.join(__dirname, 'luraphdump.lua'),
          container: '/unveilr/luraphdump.lua',
          mode: 'ro'
        },{
          host: path.join(__dirname, 'Baseplate.rbxl'),
          container: '/unveilr/Baseplate.rbxl',
          mode: 'ro'
        },{
          host: path.join(__dirname, 'exec_env.lua'),
          container: '/unveilr/exec_env.lua',
          mode: 'ro'
        }, {
          host: path.join(__dirname, 'loadstringlog.lua'),
          container: '/unveilr/loadstringlog.lua',
          mode: 'ro'
        },{
          host: path.join(__dirname, 'fakegame.lua'),
          container: '/unveilr/fakegame.lua',
          mode: 'ro'
        }, {
          host: path.join(__dirname, 'fakegame_.lua'),
          container: '/unveilr/fakegame_.lua',
          mode: 'ro'
        }, {
          host: path.join(__dirname, 'dumps'),
          container: '/unveilr/dumps',
          mode: 'rw'
        }, {
          host: path.join(__dirname, 'ibdump.lua'),
          container: '/unveilr/ibdump.lua',
          mode: 'rw'
        }],
        workdir: '/unveilr',
        memory: '512m',
        cpus: 1,
        pidsLimit: 100,
        allowNet: true
      });
    }
    if (backend === 'bwrap') {
      return bwrapSpawn(luneBinary, args, {
        cwd: path.join(__dirname, "unveilr"),
        readOnly: [abs(luneBinary, resolved), path.join(__dirname, "unveilr"), path.join(__dirname, 'httplog2.lua'), path.join(__dirname, 'httplog.lua'), path.join(__dirname, 'luraphdump.lua'), path.join(__dirname, 'Baseplate.rbxl'), path.join(__dirname, 'exec_env.lua'), path.join(__dirname, 'loadstringlog.lua'), path.join(__dirname, 'fakegame.lua'), path.join(__dirname, 'fakegame_.lua')],
        readWrite: [path.join(__dirname, 'dumps')],
        allowNet: true
      });
    }
    return console.error('SANDBOX_ERROR: No sandbox backend available. Refusing to execute.');
  },
  luau(luneBinary, args, unveilrDir) {
    const resolved = abs(unveilrDir);
    const backend = getBackend();
    const inputRelPath = args[1];
    const inputHostPath = path.join(resolved, inputRelPath);
    const inputFileName = path.basename(inputRelPath);
    const containerScript = "/sandbox/".concat(inputFileName);
    const size = fsSync.statSync(inputHostPath).size;
    if (backend === 'docker') {
      return dockerSpawn(['lune', 'run', containerScript], {
        image: IMAGES.base,
        entrypoint: '/usr/bin/env',
        env: {
          HOME: '/opt',
          PATH: '/opt/.rokit/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        },
        mounts: [{
          host: inputHostPath,
          container: containerScript,
          mode: 'ro'
        }],
        workdir: '/sandbox',
        memory: '128m',
        cpus: 0.5,
        pidsLimit: 50,
        allowNet: false,
        spawnOptions: {
          stdio: ['ignore', 'pipe', 'pipe']
        },
        timeout: calculateTimeout(size, true) * 1000
      });
    }
    if (backend === 'bwrap') {
      return bwrapSpawn(luneBinary, args, {
        cwd: resolved,
        readOnly: [abs(luneBinary, resolved), inputHostPath],
        readWrite: [],
        allowNet: false,
        spawnOptions: {
          stdio: ['ignore', 'pipe', 'pipe']
        }
      });
    }
    return console.error('SANDBOX_ERROR: No sandbox backend available. Refusing to execute user code.');
  },
  node(args, workDir) {
    const cwd = abs(workDir || process.cwd());
    const backend = getBackend();
    if (backend === 'docker') {
      return dockerSpawn(['node', ...args], {
        image: IMAGES.base,
        entrypoint: '/usr/bin/env',
        env: {
          HOME: '/opt',
          PATH: '/opt/.rokit/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin'
        },
        mounts: [{
          host: path.join(cwd, 'luathing.js'),
          container: '/app/luathing.js',
          mode: 'ro'
        }, {
          host: path.join(cwd, 'node_modules'),
          container: '/app/node_modules',
          mode: 'ro'
        }, {
          host: path.join(cwd, 'package.json'),
          container: '/app/package.json',
          mode: 'ro'
        }, {
          host: path.join(cwd, 'cache'),
          container: '/app/cache',
          mode: 'rw'
        }],
        workdir: '/app',
        memory: '256m',
        cpus: 0.5,
        pidsLimit: 50,
        allowNet: false
      });
    }
    if (backend === 'bwrap') {
      return bwrapSpawn('/usr/bin/node', args, {
        cwd,
        readOnly: [path.join(cwd, 'luathing.js'), path.join(cwd, 'node_modules'), path.join(cwd, 'package.json')],
        readWrite: [path.join(cwd, 'cache')],
        allowNet: false
      });
    }
    return console.error('SANDBOX_ERROR: No sandbox backend available.');
  }
};
module.exports = {
  profiles,
  init,
  getBackend
};