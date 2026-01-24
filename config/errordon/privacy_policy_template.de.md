# Datenschutzerklärung

**Stand: Januar 2025**

## 1. Verantwortlicher

Verantwortlich für die Datenverarbeitung auf dieser Plattform ist:

```
[INSTANCE_NAME]
[BETREIBER_NAME]
[ADRESSE]
E-Mail: datenschutz@[DOMAIN]
```

## 2. Datenschutzbeauftragter

Bei Fragen zum Datenschutz erreichen Sie unseren Datenschutzbeauftragten unter:
E-Mail: datenschutz@[DOMAIN]

## 3. Erhobene Daten

### 3.1 Registrierungsdaten
- E-Mail-Adresse
- Benutzername
- IP-Adresse bei Registrierung

**Rechtsgrundlage:** Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung)

### 3.2 Nutzungsdaten
- IP-Adressen bei Login
- Hochgeladene Medien
- Veröffentlichte Beiträge

**Rechtsgrundlage:** Art. 6 Abs. 1 lit. b DSGVO (Vertragserfüllung)

### 3.3 Content-Moderation (NSFW-Protect)

Zur Gewährleistung einer sicheren Plattform setzen wir ein KI-gestütztes Content-Moderationssystem ein:

| Datenart | Zweck | Speicherdauer | Rechtsgrundlage |
|----------|-------|---------------|-----------------|
| IP-Adresse bei Upload | Sicherheit, Missbrauchsprävention | **7 Tage** | Art. 6 Abs. 1 lit. f DSGVO |
| KI-Analyse-Ergebnisse | Erkennung illegaler Inhalte | **1 Jahr** | Art. 6 Abs. 1 lit. f DSGVO |
| Strike-Informationen | Durchsetzung der Nutzungsbedingungen | **1 Jahr** | Art. 6 Abs. 1 lit. f DSGVO |

**Besondere Hinweise bei CSAM (Kindesmissbrauchsdarstellungen):**

Bei Verdacht auf Kindesmissbrauchsdarstellungen (§184b StGB) sind wir gesetzlich verpflichtet:
- Daten an Strafverfolgungsbehörden weiterzugeben
- Beweismittel für **5 Jahre** aufzubewahren

**Rechtsgrundlage:** Art. 6 Abs. 1 lit. c DSGVO (Rechtliche Verpflichtung)

## 4. Automatisierte Entscheidungsfindung

### 4.1 KI-gestützte Content-Moderation

Wir setzen KI-Systeme ein, um hochgeladene Inhalte automatisch zu analysieren:

- **Zweck:** Erkennung von Pornografie, Hassrede und illegalen Inhalten
- **Technologie:** Ollama AI mit LLaVA (Bildanalyse) und LLaMA (Textanalyse)
- **Auswirkungen:** Automatische Sperrung bei hoher Konfidenz (>90%)

**Ihr Recht auf menschliche Überprüfung:**
Gemäß Art. 22 Abs. 3 DSGVO haben Sie das Recht:
- Ihren Standpunkt darzulegen
- Die Entscheidung anzufechten
- Eine menschliche Überprüfung zu verlangen

Kontakt: datenschutz@[DOMAIN]

## 5. Ihre Rechte

### 5.1 Auskunftsrecht (Art. 15 DSGVO)

Sie können jederzeit Auskunft über Ihre gespeicherten Daten anfordern:
- **API-Endpoint:** `GET /api/v1/errordon/gdpr/export`
- **E-Mail:** datenschutz@[DOMAIN]

### 5.2 Recht auf Löschung (Art. 17 DSGVO)

Sie können die Löschung Ihrer Daten verlangen:
- **API-Endpoint:** `DELETE /api/v1/errordon/gdpr/delete`
- **E-Mail:** datenschutz@[DOMAIN]

**Einschränkungen:**
- Bei laufenden Ermittlungen (§184b StGB) können Daten nicht gelöscht werden
- Anonymisierte Statistiken werden nicht gelöscht

### 5.3 Recht auf Berichtigung (Art. 16 DSGVO)

Unrichtige Daten werden auf Anfrage berichtigt.

### 5.4 Recht auf Einschränkung (Art. 18 DSGVO)

Sie können die Einschränkung der Verarbeitung verlangen.

### 5.5 Recht auf Datenübertragbarkeit (Art. 20 DSGVO)

Sie können Ihre Daten in einem maschinenlesbaren Format (JSON) erhalten.

### 5.6 Widerspruchsrecht (Art. 21 DSGVO)

Sie können der Verarbeitung auf Basis berechtigter Interessen widersprechen.

### 5.7 Beschwerderecht (Art. 77 DSGVO)

Sie haben das Recht, sich bei der zuständigen Aufsichtsbehörde zu beschweren:
- Landesbeauftragte/r für Datenschutz Ihres Bundeslandes
- Liste: https://www.bfdi.bund.de/DE/Infothek/Anschriften_Links/anschriften_links-node.html

## 6. Aufbewahrungsfristen

| Datenart | Speicherdauer | Begründung |
|----------|---------------|------------|
| IP-Adressen (Login) | 7 Tage | BfDI-Empfehlung |
| IP-Adressen (Violations) | 7 Tage | Sicherheit |
| Session-Daten | 30 Tage | Technisch erforderlich |
| Strike-Daten (regulär) | 1 Jahr | Durchsetzung der Regeln |
| CSAM-Daten | 5 Jahre | §184b StGB |
| Audit-Logs | 2 Jahre | Nachweispflicht |

Nach Ablauf der Fristen werden Daten automatisch gelöscht oder anonymisiert.

## 7. Datensicherheit

Wir setzen folgende technische Maßnahmen ein:
- Verschlüsselte Übertragung (TLS 1.3)
- Verschlüsselte Speicherung sensibler Daten
- Regelmäßige Sicherheitsupdates
- Zugriffsbeschränkung nach dem Need-to-know-Prinzip
- Automatische Anonymisierung nach Aufbewahrungsfrist

## 8. Datenübermittlung

### 8.1 An Strafverfolgungsbehörden

Bei Verdacht auf Straftaten (insbesondere §184b StGB) übermitteln wir Daten an:
- Bundeskriminalamt (BKA)
- National Center for Missing & Exploited Children (NCMEC)

**Rechtsgrundlage:** Art. 6 Abs. 1 lit. c DSGVO

### 8.2 Fediverse

Als Teil des Fediverse werden öffentliche Beiträge mit anderen Instanzen geteilt.

## 9. Cookies

Diese Plattform verwendet nur technisch notwendige Cookies:
- Session-Cookie (Anmeldung)
- CSRF-Token (Sicherheit)

Eine Einwilligung ist nicht erforderlich (§ 25 Abs. 2 Nr. 2 TDDDG).

## 10. Änderungen

Diese Datenschutzerklärung kann aktualisiert werden. Die aktuelle Version finden Sie stets unter:
`https://[DOMAIN]/privacy-policy`

## 11. Kontakt

Bei Fragen zum Datenschutz:
```
E-Mail: datenschutz@[DOMAIN]
```

---

*Diese Datenschutzerklärung wurde unter Berücksichtigung der DSGVO, des BDSG und des TDDDG erstellt.*
