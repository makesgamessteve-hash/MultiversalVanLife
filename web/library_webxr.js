// Multiversal Van Life - WebXR bridge for Emscripten (MIT License).
// Requests an 'immersive-vr' session on the existing WebGL2 context and
// drives the C engine via _mvl_xr_frame for every XR animation frame.
addToLibrary({
  $MVLXR__postset: 'MVLXR.probe(); Module["mvlEnterXR"] = function () { _mvl_js_xr_start(); };',
  $MVLXR: {
    supported: 0,
    session: null,
    refSpace: null,
    last: 0,
    viewsPtr: 0,
    inputPtr: 0,
    probe: function () {
      if (typeof navigator === 'undefined' || !navigator.xr || !navigator.xr.isSessionSupported) return;
      navigator.xr.isSessionSupported('immersive-vr').then(function (ok) {
        MVLXR.supported = ok ? 1 : 0;
        if (typeof window !== 'undefined') window.dispatchEvent(new CustomEvent('mvl-xr-support', { detail: ok }));
      }).catch(function () {});
    },
    readInput: function (frame) {
      var out = [0, 0, 0, 0, 0, 0];
      var sources = MVLXR.session.inputSources;
      for (var i = 0; i < sources.length; ++i) {
        var s = sources[i];
        if (!s.gamepad) continue;
        var ax = s.gamepad.axes, bt = s.gamepad.buttons;
        var sx = ax.length >= 4 ? ax[2] : (ax[0] || 0);
        var sy = ax.length >= 4 ? ax[3] : (ax[1] || 0);
        var pressed = function (k) { return bt.length > k && bt[k].pressed ? 1 : 0; };
        if (s.handedness === 'left') {
          out[0] = sx; out[1] = -sy;
          out[5] = Math.max(out[5], pressed(4));
        } else {
          out[2] = sx;
          out[3] = Math.max(out[3], pressed(0));
          out[4] = Math.max(out[4], pressed(1));
        }
      }
      return out;
    },
    onFrame: function (time, frame) {
      var session = MVLXR.session;
      if (!session) return;
      session.requestAnimationFrame(MVLXR.onFrame);
      var pose = frame.getViewerPose(MVLXR.refSpace);
      if (!pose) return;
      var layer = session.renderState.baseLayer;
      var fb = layer.framebuffer;
      var fbId = 0;
      if (fb) {
        if (!fb.name) { fb.name = GL.getNewId(GL.framebuffers); GL.framebuffers[fb.name] = fb; }
        fbId = fb.name;
      }
      var n = Math.min(pose.views.length, 4);
      var f = HEAPF32, base = MVLXR.viewsPtr >> 2;
      for (var i = 0; i < n; ++i) {
        var view = pose.views[i], vp = layer.getViewport(view), o = base + i * 36;
        f[o] = vp.x; f[o + 1] = vp.y; f[o + 2] = vp.width; f[o + 3] = vp.height;
        f.set(view.transform.inverse.matrix, o + 4);
        f.set(view.projectionMatrix, o + 20);
      }
      f.set(MVLXR.readInput(frame), MVLXR.inputPtr >> 2);
      var dt = MVLXR.last ? Math.min((time - MVLXR.last) / 1000, 0.1) : 1 / 72;
      MVLXR.last = time;
      _mvl_xr_frame(fbId, n, MVLXR.viewsPtr, MVLXR.inputPtr, dt);
    }
  },

  mvl_js_xr_supported__deps: ['$MVLXR'],
  mvl_js_xr_supported: function () { return MVLXR.supported; },

  mvl_js_xr_start__deps: ['$MVLXR', 'malloc'],
  mvl_js_xr_start: function () {
    if (!MVLXR.supported || MVLXR.session) return;
    if (!MVLXR.viewsPtr) { MVLXR.viewsPtr = _malloc(4 * 36 * 4); MVLXR.inputPtr = _malloc(8 * 4); }
    var gl = GLctx;
    navigator.xr.requestSession('immersive-vr', { optionalFeatures: ['local-floor'] }).then(function (session) {
      MVLXR.session = session;
      return gl.makeXRCompatible().then(function () {
        session.updateRenderState({ baseLayer: new XRWebGLLayer(session, gl, { depth: true, stencil: true }) });
        return session.requestReferenceSpace('local-floor').catch(function () {
          return session.requestReferenceSpace('local');
        });
      }).then(function (space) {
        MVLXR.refSpace = space;
        MVLXR.last = 0;
        session.addEventListener('end', function () {
          MVLXR.session = null;
          _mvl_xr_session_ended();
        });
        session.requestAnimationFrame(MVLXR.onFrame);
      });
    }).catch(function (err) {
      console.warn('WebXR session failed:', err);
      MVLXR.session = null;
      _mvl_xr_session_ended();
    });
  }
});
