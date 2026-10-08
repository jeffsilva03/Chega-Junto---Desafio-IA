{{flutter_js}}
{{flutter_build_config}}

// Flutter's full-page engine replaces the viewport during initialization.
// Restore the accessible viewport after its view is created, including restart.
const accessibleViewport = document.querySelector('meta[name="viewport"]').content;

_flutter.loader.load({
  serviceWorkerSettings: {
    serviceWorkerVersion: {{flutter_service_worker_version}},
  },
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    document.querySelector('meta[name="viewport"]').content = accessibleViewport;
    // Keep one-finger gestures in Flutter while allowing browser pinch zoom.
    document.body.style.touchAction = 'pinch-zoom';
  },
});
