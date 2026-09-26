import fs from 'fs/promises';
import { parse } from './mods/luaparse.js';
import beautify from './mods/beautifier.js';
import { LuauState } from 'luau-web';
import decryptStep from './reversing/decrypt.js';
const inFile = process.argv[2];
let outFile = 'out_decrypted.lua';
let forceEncoding = null;
if (process.argv[3]) {
  const a = process.argv[3];
  const encGuess = ('' + a).toLowerCase();
  if (encGuess.startsWith('utf') || encGuess.startsWith('--encoding=')) {
    if (encGuess.startsWith('--encoding=')) forceEncoding = encGuess.split('=')[1];else forceEncoding = encGuess;
  } else {
    outFile = a;
  }
}
if (process.argv[4]) {
  const b = process.argv[4];
  if (!forceEncoding) forceEncoding = b;
}
if (!inFile) {
  console.error('Usage: node run_decrypt.js <input.lua> [out.lua]');
  process.exit(1);
}
(async () => {
  try {
    const buf = await fs.readFile(inFile);
    let src;
    const normEnc = s => (s || '').toString().toLowerCase();
    const enc = normEnc(forceEncoding);
    if (enc) {
      if (enc.includes('16')) {
        if (enc.includes('be')) {
          const swapped = Buffer.from(buf);
          if (typeof swapped.swap16 === 'function') swapped.swap16();
          src = swapped.toString('utf16le');
          console.log('Using forced encoding: UTF-16 BE (converted)');
        } else {
          src = buf.toString('utf16le');
          console.log('Using forced encoding: UTF-16 LE');
        }
      } else {
        src = buf.toString('utf8');
        console.log('Using forced encoding: UTF-8');
      }
    } else {
      if (buf.length >= 2) {
        const sampleLen = Math.min(buf.length, 1000);
        let zerosEven = 0,
          zerosOdd = 0;
        for (let i = 0; i < sampleLen; i++) {
          if (buf[i] === 0) {
            if ((i & 1) === 0) zerosEven++;else zerosOdd++;
          }
        }
        if (zerosOdd > sampleLen * 0.4) {
          src = buf.toString('utf16le');
          console.log('Detected encoding: UTF-16 LE');
        } else if (zerosEven > sampleLen * 0.4) {
          const swapped = Buffer.from(buf);
          if (typeof swapped.swap16 === 'function') swapped.swap16();
          src = swapped.toString('utf16le');
          console.log('Detected encoding: UTF-16 BE (converted)');
        } else {
          src = buf.toString('utf8');
          console.log('Detected encoding: UTF-8');
        }
      } else {
        src = buf.toString('utf8');
      }
    }
    const ast = parse(src);
    console.log('Creating Luau VM...');
    const state = await LuauState.createAsync();
    console.log('Running decrypt step...');
    const output = await decryptStep(ast.body || [], [], {}, state);
    console.log('Formatting output...');
    const code = beautify(output);
    await fs.writeFile(outFile, code);
    console.log('Wrote', outFile);
  } catch (err) {
    console.error('Decrypt failed:', err);
    process.exit(1);
  }
})();