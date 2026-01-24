# Errordon Roadmap

## Status-Übersicht (Stand: 2026-01-24)

```
██████████████████████████████ 100% Phase 1 (ohne VPS machbar) ✅
░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░   0% Phase 2 (braucht VPS)
```

## ✅ Erledigt

| Task | Branch | Details |
|------|--------|---------|
| Repo-Setup | `master` | Fork, upstream, Branching |
| Upstream Merge | `master` | Mastodon main integriert |
| Architektur-Doku | `master` | `docs/ARCH_MAP_MEDIA_AND_PROFILE.md` |
| API: media_type Filter | `feature/profile-media-columns` | `?media_type=video\|audio\|image` |
| RSpec Tests | `feature/profile-media-columns` | media_type Filter Tests |
| UI: Profil-Tabs | `feature/profile-media-columns` | Videos/Audio/Images Tabs |
| UI: Routes | `feature/profile-media-columns` | `/@:acct/videos\|audio\|images` |
| i18n | `feature/profile-media-columns` | EN Übersetzungen |
| MediaFilterBar | `master` | ✅ Komplett mit CSS |
| Filter: Originals only | `master` | ✅ Client-side reblog filter |
| Filter: With alt text | `master` | ✅ Alt-text filter |
| Filter: Public only | `master` | ✅ Visibility filter |
| Grid: Instagram-Style | `master` | ✅ 3-Spalten, hover, badges |
| Privacy Preset | `master` | ✅ Strict defaults + ENV config |
| Upload-Limit Doku | `feature/upload-250mb-limits` | `docs/UPLOAD_250MB_CONFIG.md` |
| Transcoding Doku | `feature/transcoding-pipeline` | `docs/TRANSCODING_PIPELINE.md` |
| CI Workflow | `master` | `.github/workflows/ci.yml` |
| Feature Specs | `master` | `docs/FEATURES/*.md` |
| Deploy Templates | `master` | docker-compose, nginx, .env |

## 🔒 Blockiert (braucht VPS)

### Phase 2: Upload-Limits implementieren

```
□ nginx client_max_body_size ändern
□ Rails MediaAttachment Validierung
□ Testen mit echten 250MB Uploads
□ Storage-Monitoring einrichten
```

### Phase 2: Transcoding-Pipeline implementieren

```
□ ffmpeg auf Server installieren
□ MediaTranscodeWorker implementieren
□ Sidekiq Queue konfigurieren
□ Thumbnail-Generierung
□ Varianten (720p/480p) erstellen
□ Storage für Varianten
```

### Phase 3: Production Deployment

```
□ VPS einrichten
□ Docker/Compose deployen
□ SSL/Domain konfigurieren
□ Monitoring einrichten
□ Backup-Strategie
```

## Prioritäten-Matrix

| Prio | Task | Abhängigkeit |
|------|------|--------------|
| 🔴 HIGH | MediaFilterBar Integration | Keine |
| 🔴 HIGH | Grid-Ansichten | Keine |
| 🟡 MED | Weitere Filter | MediaFilterBar |
| 🟡 MED | Deploy-Ordner | Keine |
| 🟢 LOW | Privacy vollständig | Keine |
| ⬜ BLOCKED | Upload 250MB | VPS |
| ⬜ BLOCKED | Transcoding | VPS + Upload |

## Empfohlene Reihenfolge

### Jetzt (ohne VPS)

1. **MediaFilterBar Integration** → Sofort nutzbar
2. **Grid-Ansichten** → Bessere UX
3. **Deploy-Ordner** → Vorbereitung für VPS
4. **Weitere Filter** → Nice-to-have

### Später (mit VPS)

5. **Upload 250MB** → Config + Test
6. **Transcoding** → ffmpeg Pipeline
7. **Privacy vollständig** → Feintuning
8. **Production** → Go Live

## Geschätzte Restarbeit

| Phase | Aufwand | Status |
|-------|---------|--------|
| Phase 1 (UI) | ~10h | 60% done |
| Phase 2 (Backend) | ~15h | 0% (blocked) |
| Phase 3 (Deploy) | ~8h | 0% (blocked) |

**Total ohne VPS:** ~4h verbleibend
**Total mit VPS:** ~23h verbleibend
