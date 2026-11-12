terraform { # Startet den grundlegenden Terraform-Konfigurationsblock
  required_version = ">= 1.5.0" # Setzt mindestens die Terraform-Version 1.5.0 voraus
  required_providers { # Deklariert alle externen Provider-Plugins für dieses Projekt
    azurerm = { # Definiert den offiziellen Microsoft Azure Resource Manager Provider
      source  = "hashicorp/azurerm" # Gibt die Quelle in der offiziellen Terraform Registry an
      version = "~> 3.100" # Fixiert die Version im Bereich 3.100.x für zuverlässige Reproduzierbarkeit
    }
    random = { # Definiert den Random-Provider für eindeutige Suffixe und Passwörter
      source  = "hashicorp/random" # Gibt die Quelle für den Random-Provider an
      version = "~> 3.6" # Legt die Version des Random-Providers auf 3.6.x fest
    }
    archive = { # Definiert den Archive-Provider zum automatischen Packen der HTML-Datei
      source  = "hashicorp/archive" # Gibt die Quelle für den Archive-Provider an
      version = "~> 2.4" # Legt die Version des Archive-Providers auf 2.4.x fest
    }
  }
}

provider "azurerm" { # Konfiguriert die Verbindung und das Verhalten des Azure-Providers
  features { # Öffnet den Pflichtblock für spezielle Funktionssteuerungen in Azure
    key_vault { # Steuert das Löschverhalten des Azure Key Vaults
      purge_soft_delete_on_destroy = true # Löscht den Key Vault bei 'terraform destroy' endgültig, um Namenskonflikte zu verhindern
    }
    resource_group { # Steuert das Löschverhalten der Azure Resource Group
      prevent_deletion_if_contains_resources = false # Erlaubt das vollständige Abräumen der Ressourcengruppe samt Inhalt
    }
  }
}

resource "random_string" "suffix" { # Erzeugt eine zufällige Zeichenkette für weltweit eindeutige Ressourcennamen
  length  = 6 # Setzt die Länge des Zufalls-Suffixes auf 6 Zeichen
  special = false # Schließt Sonderzeichen aus, damit die Namen in Azure-URLs gültig sind
  upper   = false # Erzwingt Kleinbuchstaben für DNS- und Key-Vault-Kompatibilität
}

resource "random_password" "app_secret" { # Generiert zur Laufzeit ein sicheres Passwort (Best Practice ohne Klartext im Code)
  length  = 24 # Legt eine hohe Passwortlänge von 24 Zeichen fest
  special = true # Aktiviert Sonderzeichen für maximale kryptografische Sicherheit
}

data "azurerm_client_config" "current" {} # Liest Tenant-ID und Object-ID des aktuell angemeldeten Azure-Kontos dynamisch aus

resource "azurerm_resource_group" "rg" { # Erstellt die übergeordnete Azure Resource Group zur sauberen Kapselung
  name     = var.resource_group_name # Übernimmt den Namen aus der Variable 'resource_group_name'
  location = var.location # Setzt die Azure-Region aus der Variable 'location'
  tags     = var.tags # Weist der Ressourcengruppe die zentralen Tags zu
}

resource "azurerm_resource_provider_registration" "alerts" { # Registriert den fehlenden Azure-Ressourcenanbieter im Student-Abonnement
  name = "Microsoft.AlertsManagement" # Aktiviert den Namespace für Application Insights und automatische Warnregeln
}

module "compute_webapp" { # Bindet das eigene Submodul für App Service, Auto-Scaling und Monitoring ein
  source              = "./modules/compute_webapp" # Verweist auf den lokalen Pfad des Untermoduls
  resource_group_name = azurerm_resource_group.rg.name # Übergibt den Namen der erstellten Ressourcengruppe an das Modul
  location            = azurerm_resource_group.rg.location # Übergibt den Standort der Ressourcengruppe an das Modul
  name_prefix         = "${var.project_prefix}-${random_string.suffix.result}" # Kombiniert Präfix und Zufalls-Suffix ohne Leerzeichen
  sku_name            = var.app_service_sku # Übergibt den gewählten App-Service-Tarif (S1) an das Modul
  tags                = var.tags # Übergibt die zentralen Tags an alle Ressourcen im Modul
  depends_on          = [azurerm_resource_provider_registration.alerts] # Wartet mit der Modul-Erstellung, bis der AlertsManagement-Namespace registriert ist
}

resource "azurerm_key_vault" "kv" { # Erstellt den Azure Key Vault für sichere Passwort- und Geheimnisverwaltung
  name                       = "kv-${var.project_prefix}-${random_string.suffix.result}" # Vergibt einen global eindeutigen Namen für den Key Vault
  location                   = azurerm_resource_group.rg.location # Platziert den Key Vault in der Region der Ressourcengruppe
  resource_group_name        = azurerm_resource_group.rg.name # Ordnet den Key Vault der Ressourcengruppe zu
  tenant_id                  = data.azurerm_client_config.current.tenant_id # Verknüpft den Tresor mit dem aktuellen Azure-AD-Mandanten
  sku_name                   = "standard" # Wählt den kostengünstigen Standard-Tarif
  soft_delete_retention_days = 7 # Setzt die Aufbewahrungsfrist für gelöschte Geheimnisse auf das Minimum von 7 Tagen
  purge_protection_enabled   = false # Deaktiviert den Löschschutz für einen problemlosen Abbau nach dem Test
  tags                       = var.tags # Fügt die Standard-Tags hinzu

  access_policy { # Erste Zugriffsrichtlinie: Erlaubt dem ausführenden Terraform-Account das Verwalten des Secrets
    tenant_id          = data.azurerm_client_config.current.tenant_id # Nutzt die dynamisch ausgelesene Mandanten-ID
    object_id          = data.azurerm_client_config.current.object_id # Nutzt die Objekt-ID des ausführenden Accounts
    secret_permissions = ["Get", "List", "Set", "Delete", "Purge"] # Gewährt die nötigen Rechte zum Anlegen und Löschen beim Abbau
  }

  access_policy { # Zweite Zugriffsrichtlinie: Gewährt der Web App passwortlosen Lesezugriff über ihre Managed Identity
    tenant_id          = data.azurerm_client_config.current.tenant_id # Nutzt dieselbe Mandanten-ID
    object_id          = module.compute_webapp.webapp_principal_id # Bezieht die Identitäts-ID der Web App direkt aus dem Output des Moduls
    secret_permissions = ["Get", "List"] # Beschränkt die Berechtigung nach dem Least-Privilege-Prinzip auf reines Lesen
  }
}

resource "azurerm_key_vault_secret" "example_secret" { # Speichert das dynamisch erzeugte Passwort sicher im Key Vault ab
  name         = "WebApp-Api-Secret" # Vergibt einen sprechenden Namen für das Geheimnis
  value        = random_password.app_secret.result # Übergibt den Zufallswert aus der Ressource 'random_password'
  key_vault_id = azurerm_key_vault.kv.id # Verknüpft das Geheimnis mit dem oben erstellten Key Vault
}

resource "azurerm_traffic_manager_profile" "tm" { # Erstellt das globale Azure Traffic Manager Profil (Ersatz für gesperrtes Front Door im Student-Tarif)
  name                   = "tm-${var.project_prefix}-${random_string.suffix.result}" # Vergibt einen eindeutigen Namen für das Traffic-Manager-Profil
  resource_group_name    = azurerm_resource_group.rg.name # Ordnet das Profil der Ressourcengruppe zu
  traffic_routing_method = "Performance" # Routet globale Besuchende automatisch mit minimaler Netzwerk-Latenz
  tags                   = var.tags # Fügt die Standard-Tags hinzu

  dns_config { # Konfiguriert die globale DNS-Auflösung des Traffic Managers
    relative_name = "tm-${var.project_prefix}-${random_string.suffix.result}" # Erzeugt den weltweiten DNS-Namen (*.trafficmanager.net)
    ttl           = 60 # Setzt die Time-to-Live auf 60 Sekunden für schnelle Aktualisierungen bei Ausfällen
  }

  monitor_config { # Konfiguriert die automatische Gesundheitsprüfung (Health Probe) des Backends
    protocol                     = "HTTPS" # Prüft den Webserver verschlüsselt über HTTPS
    port                         = 443 # Nutzt den Standard-Port 443 für HTTPS
    path                         = "/" # Prüft den Wurzelpfad (die index.html) auf Erreichbarkeit
    interval_in_seconds          = 30 # Führt die Verfügbarkeitsprüfung alle 30 Sekunden durch
    timeout_in_seconds           = 10 # Wartet maximal 10 Sekunden auf eine Antwort des Backends
    tolerated_number_of_failures = 3 # Markiert den Endpunkt erst nach 3 fehlgeschlagenen Versuchen als nicht verfügbar
  }
}

resource "azurerm_traffic_manager_azure_endpoint" "tm_endpoint" { # Verknüpft das Traffic-Manager-Profil direkt mit der Azure Web App
  name               = "ep-webapp-primary" # Vergibt einen Namen für den primären Endpunkt
  profile_id         = azurerm_traffic_manager_profile.tm.id # Verweist auf die ID des oben erstellten Traffic-Manager-Profils
  target_resource_id = module.compute_webapp.webapp_id # Bezieht die Ressourcen-ID der Web App direkt aus dem Compute-Modul
  weight             = 100 # Weist dem Endpunkt das volle Routing-Gewicht zu
}