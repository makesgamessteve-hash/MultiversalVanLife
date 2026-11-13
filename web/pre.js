// Multiversal Van Life - runs inside the Emscripten module scope before
// main(): mounts a persistent IndexedDB folder for save games (MIT License).
Module['preRun'] = Module['preRun'] || [];
Module['preRun'].push(function () {
  FS.mkdir('/save');
  FS.mount(IDBFS, {}, '/save');
  addRunDependency('mvl-save');
  FS.syncfs(true, function (err) {
    if (err) console.warn('could not load saves', err);
    removeRunDependency('mvl-save');
  });
});
