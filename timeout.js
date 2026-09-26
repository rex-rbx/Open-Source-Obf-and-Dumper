const calculate = (size, isInBytes = false) => {
  let kilobytes;
  if (isInBytes) {
    kilobytes = size / 1024;
  } else {
    kilobytes = size * 1024;
  }
  if (kilobytes < 10) return 7;
  const ratio = 27.5;
  const timeoutFloat = kilobytes / ratio;
  return Math.min(timeoutFloat > 20 ? Math.floor(timeoutFloat) : Math.ceil(timeoutFloat), 40);
};
module.exports = calculate;