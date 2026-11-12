# ☁️ Cloud-Architektur für eine global hochverfügbare Unternehmenswebsite (Azure & Terraform)

Dieses Repository enthält den vollständigen **Infrastructure-as-Code-(IaC-)Quellcode** in Terraform sowie die statische Beispiel-Webanwendung (`index.html`) für das Portfolioprojekt im Kurs **Cloud Programming (DLBSEPCP01_D)** an der IU Internationale Hochschule.

---

## 📋 Projektsteckbrief

* **Aufgabenstellung:** Aufgabe 1 – Einfache Webseite auf Azure hosten (hochverfügbar, latenzoptimiert, automatische Skalierung, reproduzierbar via Infrastructure-as-Code)
* **Autor:** Dustin Dörr
* **Matrikelnummer:** 3200280
* **Studiengang:** B.Sc. Softwareentwicklung (IU Internationale Hochschule)
* **Cloud-Plattform:** Microsoft Azure (*Azure for Students*)
* **IaC-Framework:** HashiCorp Terraform (>= 1.5.0)

---

## 🎯 Architekturübersicht & Erfüllung der Anforderungen

Die entworfene **Platform-as-a-Service-(PaaS-)Architektur** stellt eine statische Unternehmenswebsite („Hello-World“-HTML-Anwendung) vollautomatisiert bereit und basiert auf einem realistischen B2B-SaaS-Unternehmensszenario:

1. **Hochverfügbarkeit (High Availability):**
   Die Webanwendung läuft auf einem **Azure App Service Plan (Tarif `S1`)** mit einer Basislast von **mindestens 2 parallelen Instanzen** (internes Load Balancing ohne Single Point of Failure) sowie einer kontinuierlichen externen Gesundheitsprüfung (*Health Probe* über HTTPS/Port 443 durch den Traffic Manager).
2. **Globale Erreichbarkeit ohne Verzögerungen (Low Latency):**
   Ein vorgeschaltetes **Azure Traffic Manager Profil** mit der Routing-Methode `Performance` bereitet das globale, latenzbasierte Multi-Region-Routing architektonisch vor und übernimmt die weltweite DNS-Auflösung.
3. **Automatische horizontale Skalierung (Auto-Scaling):**
   Über **Azure Monitor Autoscale** skaliert das Backend dynamisch zwischen **2 und 5 Instanzen**:
   * **Scale-Out:** +1 Instanz, sobald die durchschnittliche CPU-Auslastung über 5 Minuten den Schwellenwert von > 70 % überschreitet.
   * **Scale-In:** -1 Instanz, sobald die durchschnittliche CPU-Auslastung unter < 30 % fällt.
4. **Sicherheit & Geheimnisverwaltung (Security by Design):**
   * Erzwungene HTTPS-Verschlüsselung (`https_only = true`).
   * **Keine Klartext-Passwörter im Quellcode:** Geheimnisse werden zur Laufzeit über den Terraform-Provider `random_password` (24 Zeichen) generiert und direkt im **Azure Key Vault** abgelegt.
   * **Passwortlose Authentifizierung:** Die Web App greift über eine **System-Assigned Managed Identity** nach dem *Least-Privilege-Prinzip* (nur `Get`- und `List`-Rechte) auf den Key Vault zu.
5. **Saubere Kapselung & Modularisierung:**
   Alle Ressourcen sind in einer dedizierten **Azure Resource Group** gekapselt und logisch in ein Hauptskript (globales Routing & Security) sowie ein wiederverwendbares Submodul `compute_webapp` (Hosting, Auto-Scaling, ZIP-Deployment & Telemetrie) unterteilt.

---

## 🛠️ Verwendete Cloud-Dienste & Terraform-Ressourcen

| Cloud-Dienst / Komponente | Terraform-Ressource | Modul | Funktion |
| :--- | :--- | :--- | :--- |
| **Azure Resource Group** | `azurerm_resource_group.rg` | Root | Logische Kapselung aller Projektressourcen und einheitliches Tagging |
| **Azure Traffic Manager** | `azurerm_traffic_manager_profile.tm` | Root | Globales, latenzbasiertes DNS-Routing (`Performance`) & HTTPS Health Probe |
| **Azure Key Vault** | `azurerm_key_vault.kv` | Root | Sichere Speicherung von API-Secrets ohne Klartext im Code |
| **App Service Plan (Linux)** | `azurerm_service_plan.asp` | `compute_webapp` | Dediziertes PaaS-Compute-Fundament im Tarif `S1` |
| **Azure Linux Web App** | `azurerm_linux_web_app.webapp` | `compute_webapp` | Hosting der HTML-Seite (PHP 8.2 Stack), Managed Identity & automatisches ZIP-Deploy |
| **Azure Monitor Autoscale** | `azurerm_monitor_autoscale_setting` | `compute_webapp` | Regelbasierte horizontale Skalierung (2–5 Instanzen nach CPU-Metrik) |
| **Application Insights & Log Analytics** | `azurerm_application_insights` / `azurerm_log_analytics_workspace` | `compute_webapp` | Zentrale Überwachung, Telemetrie und Protokollierung (30 Tage Aufbewahrung) |

---

## 📂 Repository-Struktur

```text
.
├── main.tf                     # Hauptkonfiguration (Provider, Resource Group, Key Vault, Traffic Manager)
├── variables.tf                # Zentrale Eingabevariablen mit Standardwerten (Region, SKU, Präfix, Tags)
├── outputs.tf                  # Ausgabe der generierten Web-App- und Traffic-Manager-URLs nach dem Deployment
├── index.html                  # Statische "Hello-World"-Unternehmenswebsite
├── README.md                   # Projektdokumentation und Installationsanleitung
└── modules/
    └── compute_webapp/         # Gekapseltes Terraform-Submodul für Compute, Skalierung & Monitoring
        └── main.tf             # App Service Plan, Linux Web App, Autoscale, Log Analytics, App Insights & ZIP-Archivierung
```

---

## 🚀 Schritt-für-Schritt Installations- und Deployment-Anleitung

### 1. Voraussetzungen prüfen
Stelle sicher, dass folgende Werkzeuge lokal installiert sind:
* **Microsoft Azure Abonnement** (z. B. *Azure for Students*)
* **[Azure CLI](https://learn.microsoft.com/de-de/cli/azure/install-azure-cli)** (Version >= 2.50)
* **[HashiCorp Terraform](https://developer.hashicorp.com/terraform/downloads)** (Version >= 1.5.0)
* **Git**

### 2. Repository klonen
Klone dieses Repository auf deinen lokalen Rechner und wechsle in das Projektverzeichnis:
```bash
git clone https://github.com/doerrdu/DLBSEPCP01_D
cd DLBSEPCP01_D
```

### 3. Anmeldung bei Microsoft Azure
Authentifiziere dich über die Azure CLI mit deinem Azure-Konto:
```bash
az login
```

### 4. Terraform initialisieren
Lade die benötigten Provider-Plugins (`azurerm`, `random`, `archive`) herunter und initialisiere das lokale Submodul `compute_webapp`:
```bash
terraform init
```

### 5. Ausführungsplan prüfen
Erstelle einen Ausführungsplan, um vorab zu kontrollieren, welche Azure-Ressourcen angelegt werden:
```bash
terraform plan
```

### 6. Cloud-Infrastruktur bereitstellen (Deployment)
Starte die automatisierte Bereitstellung der gesamten Architektur inklusive des automatischen ZIP-Deployments der `index.html`:
```bash
terraform apply
```
Bestätige die Abfrage im Terminal mit `yes`.

> 💡 **Tipp bei Azure-Student-Konten (Drosselung vermeiden):**
> Sollte die Azure-API im Student-Tarif bei parallelen Anfragen eine Drosselung (*Error 429 – Too Many Requests*) melden, führe das Deployment sequenziell aus:
> ```bash
> terraform apply -parallelism=1
> ```

### 7. Bereitstellung überprüfen
Nach erfolgreichem Abschluss (ca. 2–4 Minuten) gibt Terraform die beiden Endpunkt-URLs direkt in der Konsole aus:
* `direct_webapp_url` – Direkte HTTPS-URL des Azure App Service (`https://app-iuportfolio-<suffix>.azurewebsites.net`)
* `global_traffic_manager_url` – Globale URL des Azure Traffic Managers (`http://tm-iuportfolio-<suffix>.trafficmanager.net`)

> ⚠️ **Hinweis zum HTTPS-Aufruf:** Beim Aufruf über die `.trafficmanager.net`-URL erfolgt durch `https_only = true` ein automatischer Redirect auf HTTPS. Da das Azure-Standardzertifikat auf `*.azurewebsites.net` ausgestellt ist, kann im Browser eine Zertifikatswarnung erscheinen, die für den Test ignoriert werden kann.

### 8. Ressourcen abbauen (Kostenschutz / FinOps)
Um das *Azure for Students*-Guthaben zu schonen und laufende Kosten durch den Tarif `S1` zu vermeiden, kann die gesamte Infrastruktur nach dem Test mit einem einzigen Befehl rückstandslos gelöscht werden:
```bash
terraform destroy
```
Bestätige den Abbau mit `yes`.

---

## ⚙️ Konfigurierbare Variablen (`variables.tf`)

Alle Parameter verfügen über sinnvolle Standardwerte, sodass ein Deployment ohne manuelle Anpassung sofort funktioniert. Bei Bedarf können sie über eine `terraform.tfvars`-Datei oder per CLI-Flag (`-var="..."`) überschrieben werden:

| Variablenname | Typ | Standardwert | Beschreibung |
| :--- | :--- | :--- | :--- |
| `resource_group_name` | `string` | `"rg-portfolio-aufgabe1"` | Name der Azure Resource Group für saubere Kapselung |
| `location` | `string` | `"francecentral"` | Azure-Region (gemäß Azure Policy im Student-Tarif erlaubt: `francecentral`, `switzerlandnorth`, `polandcentral`, `austriaeast`, `belgiumcentral`) |
| `project_prefix` | `string` | `"iuportfolio"` | Namenspräfix für alle Cloud-Ressourcen (max. 12 Zeichen wegen Key-Vault-Namenslimit) |
| `app_service_sku` | `string` | `"S1"` | Tarif für den App Service Plan (`S1` unterstützt Auto-Scaling & Traffic Manager) |
| `tags` | `map(string)` | `{ Project = "IU-Cloud-Programming-Aufgabe1", ManagedBy = "Terraform" }` | Einheitliche Metadaten-Tags zur Strukturierung und Kostenkontrolle |

---

## 📤 Terraform Outputs (`outputs.tf`)

| Output-Name | Beschreibung | Beispielwert |
| :--- | :--- | :--- |
| `direct_webapp_url` | Direkte HTTPS-URL des Azure App Service Backends | `https://app-iuportfolio-a8f2c1.azurewebsites.net` |
| `global_traffic_manager_url` | Globale, latenzoptimierte DNS-URL über den Azure Traffic Manager | `http://tm-iuportfolio-a8f2c1.trafficmanager.net` |