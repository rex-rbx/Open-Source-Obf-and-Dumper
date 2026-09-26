const axios = require('axios');
const isIP = require('net').isIP;
const fs = require('fs');
const path = require('path');

// Load and validate list
let list = [];
try {
  list = JSON.parse(fs.readFileSync(path.join(__dirname, 'badSites.json'), 'utf8'));
  if (!Array.isArray(list)) list = [];
} catch (err) {
  console.error('Error loading badSites.json:', err.message);
  list = [];
}

module.exports = async (url) => {
  try {
    const hostname = new URL(url).hostname;
    
    // Check for IP addresses
    if (isIP(hostname) !== 0) {
      throw new Error(`IP addresses are not allowed. URL "${url}" contains an IP address (${hostname}).`);
    }
    
    // Check against bad sites list using some()
    const cleanUrl = url.replace(/https?:\/\//, "");
    const isBad = list.some(site => cleanUrl.startsWith(site));
    
    if (isBad) {
      throw new Error("This site is blocked.");
    }
    const res = await axios.get(url, {
      responseType: 'text',
      headers: {
        'User-Agent': 'Roblox/WinInet'
      }
    });
    if (res.status >= 200 && res.status < 300) {
      return [true, res.data];
    } else {
      throw new Error(`Request failed with status code ${res.status}`);
    }
  } catch (err) {
    return [false, err.message.includes('IP addresses are not allowed') || err.message.includes('This site is blocked')
      ? err.message
      : `Invalid URL: ${url}`];
  }
};