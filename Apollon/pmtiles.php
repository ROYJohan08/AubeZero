<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="UTF-8">
  <title>DomoNas - PmtilesManager</title>
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />

  <!-- Libs locales, dans le même dossier que ce fichier (PATH_LAMP) -->
  <link rel="stylesheet" href="maplibre-gl.css">
  <script src="maplibre-gl.js"></script>
  <script src="pmtiles.js"></script>

  <!-- Ton style.css intégré -->
  <style>
    :root { --bg: #0d0f14; --card: #161b22; --accent: #7c4dff; --danger: #ff4d4d; --text: #c9d1d9; --border: #30363d; }
    body { background: var(--bg); color: var(--text); font-family: 'Segoe UI', sans-serif; padding: 20px; margin: 0; }
    .container { max-width: 1250px; margin: 40px auto; }
    .glass { background: var(--card); border: 1px solid var(--border); border-radius: 12px; padding: 20px; box-shadow: 0 10px 30px rgba(0,0,0,0.5); }
    .header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 25px; }
    table { width: 100%; border-collapse: collapse; }
    td, th { padding: 12px; text-align: left; border-bottom: 1px solid #21262d; }
    input, select { background: #0d1117; border: 1px solid var(--border); color: white; padding: 8px; border-radius: 6px; outline: none; }
    .btn { background: var(--accent); color: white; border: none; padding: 8px 12px; border-radius: 6px; cursor: pointer; font-weight: bold; }
    .btn-tmdb { background: transparent; border: 1px solid var(--accent); color: var(--accent); margin-left: 4px; }
    .btn-del { background: transparent; color: var(--danger); border: 1px solid var(--danger); margin-left: 4px; font-size: 11px; }
    .btn-del:hover { background: var(--danger); color: white; }
    a { color: var(--accent); text-decoration: none; font-weight: 500; }
    #overlay { display:none; position:fixed; inset:0; background:rgba(0,0,0,0.85); z-index:90; backdrop-filter: blur(5px); }
    #tmdb-modal { display:none; position:fixed; top:50%; left:50%; transform:translate(-50%,-50%); background:var(--card); padding:25px; border: 1px solid var(--accent); z-index:100; border-radius:15px; width:450px; }
    .tmdb-item { padding: 10px; border-bottom: 1px solid #333; cursor: pointer; }
    .tmdb-item:hover { background:#1f2933; }
    .actions-cell { display: flex; align-items: center; min-width: 350px; gap: 6px; }
    #results { max-height: 300px; overflow-y: auto; }
    .spinner { border: 3px solid #333; border-top: 3px solid var(--accent); border-radius: 50%; width: 20px; height: 20px; animation: spin 0.8s linear infinite; margin-right: 8px; display:inline-block; vertical-align:middle; }
    @keyframes spin { 0% { transform: rotate(0deg);} 100% { transform: rotate(360deg);} }
    #map { height: 100vh; width: 100vw; }
    body.map{ margin: 0; padding: 0; height: 100%; width: 100%; background-color: #121212; }
    :root {
        --primary: #BB86FC;
        --secondary: #03DAC6;
        --text-main: #FFFFFF;
        --text-muted: #B3B3B3;
        --error: #CF6679;
        --border-color: #2A2A2A;
    }
    .app-bar {
        background-color: var(--card);
        padding: 16px 24px;
        display: flex;
        justify-content: space-between;
        align-items: center;
        box-shadow: 0 2px 4px rgba(0,0,0,0.6);
        border-bottom: 1px solid var(--border);
    }
    .card {
        background-color: var(--card);
        padding: 20px;
        border-radius: 12px;
        margin-bottom: 24px;
        box-shadow: 0 2px 8px rgba(0,0,0,0.5);
        border: 1px solid var(--border);
    }
    .badge {
        padding: 2px 8px;
        border-radius: 999px;
        font-size: 11px;
    }
    .badge-ok { background-color: rgba(3,218,198,0.15); color: var(--secondary); }
    .badge-warn { background-color: rgba(255,193,7,0.15); color: #FFC107; }
    .badge-error { background-color: rgba(207,102,121,0.15); color: var(--error); }
    .progress-bar {
        width: 100%;
        height: 6px;
        background-color: #2A2A2A;
        border-radius: 999px;
    }
    .progress-fill {
        height: 100%;
        background: linear-gradient(90deg, var(--secondary), var(--primary));
        border-radius: 999px;
    }
    .smart-message {
        background-color: #1A1A1A;
        padding: 10px;
        border-radius: 8px;
        border: 1px solid var(--border-color);
    }
    .service-grid {
        display: grid;
        grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
        gap: 20px;
    }
    .service-card {
        background: var(--card);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 18px;
        text-align: center;
        cursor: pointer;
        transition: 0.25s;
        box-shadow: 0 4px 12px rgba(0,0,0,0.4);
    }
    .service-card:hover {
        transform: translateY(-4px);
        box-shadow: 0 6px 18px rgba(0,0,0,0.5);
    }
    .service-card.disabled {
        opacity: 0.35;
        pointer-events: none;
    }
    .service-icon {
        width: 48px;
        height: 48px;
        margin-bottom: 12px;
    }
    .service-name {
        font-size: 16px;
        font-weight: 600;
        margin-bottom: 8px;
    }
    .badge {
        padding: 4px 10px;
        border-radius: 999px;
        font-size: 12px;
        display: inline-block;
    }
    .badge-ok { background-color: rgba(3,218,198,0.15); color: var(--secondary); }
    .badge-error { background-color: rgba(207,102,121,0.15); color: var(--error); }
  </style>
</head>
<body class="map">
  <div id="map"></div>

  <script>
    document.addEventListener('DOMContentLoaded', () => {
      if (typeof pmtiles === 'undefined' || typeof maplibregl === 'undefined') {
        alert("Librairies MapLibre ou PMTiles introuvables. Place maplibre-gl.js, maplibre-gl.css et pmtiles.js dans PATH_LAMP.");
        return;
      }

      const protocol = new pmtiles.Protocol();
      maplibregl.addProtocol("pmtiles", protocol.tile);

      // Tous les fichiers sont dans PATH_LAMP, même dossier que ce HTML
      const PMTILES_URL = "europe.pmtiles";
      const GLYPHS_URL  = "fonts/{fontstack}/{range}.pbf";

      const map = new maplibregl.Map({
        container: 'map',
        style: {
          version: 8,
          glyphs: GLYPHS_URL,
          sources: {
            "protomaps": {
              type: "vector",
              url: `pmtiles://${PMTILES_URL}`
            }
          },
          layers: [
            {
              id: "background",
              type: "background",
              paint: { "background-color": "#212124" }
            },
            {
              id: "water",
              type: "fill",
              source: "protomaps",
              "source-layer": "water",
              paint: { "fill-color": "#17263c" }
            },
            {
              id: "buildings",
              type: "fill",
              source: "protomaps",
              "source-layer": "buildings",
              minzoom: 13,
              paint: {
                "fill-color": "#282d34",
                "fill-outline-color": "#1f2329",
                "fill-opacity": 0.9
              }
            },
            {
              id: "roads_local",
              type: "line",
              source: "protomaps",
              "source-layer": "roads",
              filter: ["!=", ["get", "pmap:kind"], "highway"],
              paint: {
                "line-color": "#2c2d30",
                "line-width": [
                  "interpolate", ["linear"], ["zoom"],
                  12, 1,
                  16, 4
                ]
              }
            },
            {
              id: "roads_highways",
              type: "line",
              source: "protomaps",
              "source-layer": "roads",
              filter: ["==", ["get", "pmap:kind"], "highway"],
              paint: {
                "line-color": "#3c4043",
                "line-width": [
                  "interpolate", ["linear"], ["zoom"],
                  6, 1.5,
                  14, 5
                ]
              }
            },
            {
              id: "labels_roads",
              type: "symbol",
              source: "protomaps",
              "source-layer": "roads",
              minzoom: 13,
              layout: {
                "symbol-placement": "line",
                "text-field": "{name}",
                "text-font": ["OpenSansRegular"],
                "text-size": 11,
                "text-max-angle": 30
              },
              paint: {
                "text-color": "#9aa0a6",
                "text-halo-color": "#212124",
                "text-halo-width": 2
              }
            },
            {
              id: "labels_places",
              type: "symbol",
              source: "protomaps",
              "source-layer": "places",
              layout: {
                "text-field": "{name}",
                "text-font": ["OpenSansRegular"],
                "text-size": [
                  "interpolate", ["linear"], ["zoom"],
                  4, 11,
                  10, 16
                ]
              },
              paint: {
                "text-color": "#e8eaed",
                "text-halo-color": "#212124",
                "text-halo-width": 2
              }
            }
          ]
        },
        center: [2.3522, 48.8566],
        zoom: 6
      });
    });
  </script>
</body>
</html>
