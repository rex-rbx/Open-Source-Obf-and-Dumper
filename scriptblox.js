fetch("https://scriptblox.com/api/script/fetch").then(res => res.json()).then(data => {
  for (const script of data.result.scripts) {
    const url = "https://scriptblox.com/script/".concat(script.slug);
    const rawscriptsUrl = script.script.match(/(https:\/\/rawscripts.net\/raw\/.+)"/)[1];
    if (!rawscriptsUrl) continue;
    fetch(rawscriptsUrl).then(data => data.text().then(content => {
      dumpInner(content, {
        url: url
      });
    }));
  }
}).catch();