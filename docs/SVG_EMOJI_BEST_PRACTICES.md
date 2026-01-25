# SVG Emoji Best Practices

## 1. Dimensionen
- **ViewBox:** `viewBox="0 0 36 36"` (Twemoji-Standard)
- **Quadratisch:** IMMER quadratisch
- **Padding:** 4px Rand
- **Mastodon:** Anzeige 20x20px, max 50KB

## 2. Strokes
- **Width:** 2px
- **Line-Cap:** round
- **Line-Join:** round
- **Abstand:** min 2px zwischen Linien

## 3. Farben (Hacker Theme)
- Matrix-Grün: #00FF00
- Background: #000000
- Warning: #FF0000
- Cyber-Blue: #00FFFF

## 4. Typografie
**NIEMALS** `<text>` verwenden → Pfade nutzen!

## 5. Optimierung
- Keine Metadaten
- Keine Kommentare
- Paths vereinfachen
- SVGO/SVGOMG nutzen

## 6. Accessibility
- `role="img"` für semantische SVGs
- `aria-label` für Beschreibung

## 7. Quellen
- openmoji.org/styleguide
- github.com/twitter/twemoji
- laurakalbag.com/custom-emoji-on-mastodon
