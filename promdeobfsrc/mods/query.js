const is = (node, pattern) => {
  const match = (node, pat) => {
    if (!node || !pat || typeof node !== "object" || typeof pat !== "object") return node === pat;
    for (const key in pat) {
      if (!(key in node)) return false;
      const a = node[key],
        b = pat[key];
      if (Array.isArray(a) && Array.isArray(b)) {
        if (a.length < b.length) return false;
        for (let i = 0; i < b.length; i++) if (!match(a[i], b[i])) return false;
      } else if (typeof a === "object" && typeof b === "object") {
        if (!match(a, b)) return false;
      } else if (a !== b) return false;
    }
    return true;
  };
  return match(node, pattern);
};
const query = (root, matcher, opts = {}) => {
  if (opts.dontTouch && !opts.skipKey) opts.skipKey = (node, key) => (node.type === "AssignmentStatement" || node.type === "LocalStatement") && key === "variables" || node.type === "FunctionDeclaration" && (key === "identifier" || key === "parameters") || node.type === "ForNumericStatement" && key === "variable" || node.type === "ForGenericStatement" && key === "variables";
  const {
    dontTouch = new Set(),
    skipKey = () => false,
    outsideOf,
    stopAtMatch = false
  } = opts;
  const walls = outsideOf ? new Set(Array.isArray(outsideOf) ? outsideOf : [outsideOf]) : null;
  const results = [];
  if (!root || typeof root !== "object") return results;
  if (matcher !== null && typeof matcher === "object" && !Array.isArray(matcher) && Array.isArray(matcher.sequence)) {
    const seq = matcher.sequence;
    if (seq.length === 0) return results;
    const walk = node => {
      if (!node || typeof node !== "object") return;
      if (dontTouch.has(node)) return;
      if (!Array.isArray(node) && walls?.has(node.type)) return;
      if (Array.isArray(node)) {
        for (let i = 0; i <= node.length - seq.length; i++) {
          if (seq.every((t, j) => node[i + j]?.type === t)) results.push(node.slice(i, i + seq.length));
        }
        for (const item of node) walk(item);
      } else {
        for (const key in node) {
          if (skipKey(node, key)) continue;
          walk(node[key]);
        }
      }
    };
    walk(root);
    return results;
  }
  let matchFn;
  if (typeof matcher === "string") {
    matchFn = node => node.type === matcher;
  } else if (Array.isArray(matcher)) {
    const typeSet = new Set(matcher);
    matchFn = node => typeSet.has(node.type);
  } else {
    matchFn = node => is(node, matcher);
  }
  const stack = [root];
  const seen = new WeakSet();
  while (stack.length) {
    const node = stack.pop();
    if (!node || typeof node !== "object") continue;
    if (dontTouch.has(node)) continue;
    if (walls?.has(node.type)) continue;
    if (seen.has(node)) continue;
    seen.add(node);
    const matched = matchFn(node);
    if (matched) results.push(node);
    if (matched && stopAtMatch) continue;
    for (const key in node) {
      if (skipKey(node, key)) continue;
      const value = node[key];
      if (Array.isArray(value)) {
        for (let i = value.length - 1; i >= 0; i--) stack.push(value[i]);
      } else if (value && typeof value === "object") {
        stack.push(value);
      }
    }
  }
  return results;
};
export default query;