variable "resource_group_name" { # Nimmt den Namen der Ressourcengruppe vom Hauptskript entgegen
  type = string # Prüft, dass der übergebene Wert eine Zeichenkette ist
}

variable "location" { # Nimmt die Azure-Region vom Hauptskript entgegen
  type = string # Prüft, dass der übergebene Wert eine Zeichenkette ist
}

variable "name_prefix" { # Nimmt das kombinierte Namenspräfix (inkl. Zufalls-Suffix) entgegen
  type = string # Prüft, dass der übergebene Wert eine Zeichenkette ist
}

variable "sku_name" { # Nimmt den gewählten Tarif (S1) für den App Service Plan entgegen
  type = string # Prüft, dass der übergebene Wert eine Zeichenkette ist
}

variable "tags" { # Nimmt die zentralen Ressourcen-Tags vom Hauptskript entgegen
  type = map(string) # Prüft, dass die Tags als Schlüssel-Wert-Map übergeben werden
}

data "archive_file" "html_zip" { # Erstellt automatisch ein ZIP-Archiv aus der HTML-Datei für das Deployment
  type        = "zip" # Legt das Archivformat auf ZIP fest
  output_path = "${path.module}/site.zip" # Speichert das erzeugte ZIP-Paket im Modulverzeichnis ab
  source_file = "${path.root}/index.html" # Liest die 'index.html' zuverlässig aus dem Hauptverzeichnis (Root) ein
}

resource "azurerm_log_analytics_workspace" "law" { # Erstellt den Log Analytics Workspace zur zentralen Protokollierung
  name                = "law-${var.name_prefix}" # Vergibt einen eindeutigen Namen für den Workspace
  location            = var.location # Platziert den Workspace in der übergebenen Region
  resource_group_name = var.resource_group_name # Ordnet den Workspace der übergebenen Ressourcengruppe zu
  sku                 = "PerGB2018" # Wählt das verbrauchsbasierte Abrechnungsmodell
  retention_in_days   = 30 # Bewahrt Log-Daten für 30 Tage auf
  tags                = var.tags # Weist die übergebenen Tags zu
}

resource "azurerm_application_insights" "appinsights" { # Erstellt Application Insights zur Überwachung der Web App
  name                = "appi-${var.name_prefix}" # Vergibt einen eindeutigen Namen für Application Insights
  location            = var.location # Nutzt die übergebene Azure-Region
  resource_group_name = var.resource_group_name # Ordnet die Ressource der Ressourcengruppe zu
  workspace_id        = azurerm_log_analytics_workspace.law.id # Verknüpft Application Insights mit dem Log Analytics Workspace
  application_type    = "web" # Konfiguriert das Monitoring für eine Webanwendung
  tags                = var.tags # Weist die übergebenen Tags zu
}

resource "azurerm_service_plan" "asp" { # Erstellt den Azure App Service Plan als Compute-Fundament
  name                = "asp-${var.name_prefix}" # Vergibt einen eindeutigen Namen für den App Service Plan
  location            = var.location # Platziert den Plan in der übergebenen Region
  resource_group_name = var.resource_group_name # Ordnet den Plan der Ressourcengruppe zu
  os_type             = "Linux" # Wählt Linux als Betriebssystem für den Webserver
  sku_name            = var.sku_name # Setzt den übergebenen Tarif (S1) für Auto-Scaling-Unterstützung
  tags                = var.tags # Weist die übergebenen Tags zu
}

resource "azurerm_monitor_autoscale_setting" "autoscale" { # Konfiguriert die automatische horizontale Skalierung und Hochverfügbarkeit
  name                = "autoscale-${var.name_prefix}" # Vergibt einen eindeutigen Namen für die Skalierungsregel
  resource_group_name = var.resource_group_name # Ordnet die Einstellung der Ressourcengruppe zu
  location            = var.location # Setzt die übergebene Region
  target_resource_id  = azurerm_service_plan.asp.id # Wendet die Skalierung direkt auf den App Service Plan an
  tags                = var.tags # Weist die übergebenen Tags zu

  profile { # Öffnet das Skalierungsprofil
    name = "AutoScale-CPU-Profile" # Benennt das Profil für die CPU-basierte Skalierung

    capacity { # Legt die Instanzgrenzen fest
      default = 2 # Startet standardmäßig mit 2 parallelen Instanzen für Hochverfügbarkeit
      minimum = 2 # Hält mindestens 2 Instanzen dauerhaft aktiv, um Einzelausfälle abzufangen
      maximum = 5 # Begrenzt den Ausbau auf maximal 5 Instanzen zur Kostenkontrolle
    }

    rule { # Erste Regel: Horizontales Hochskalieren (Scale-Out) bei steigender Besucherlast
      metric_trigger { # Definiert den Auslöser anhand der CPU-Metrik
        metric_name        = "CpuPercentage" # Überwacht die prozentuale CPU-Auslastung
        metric_resource_id = azurerm_service_plan.asp.id # Misst die Auslastung am App Service Plan
        time_grain         = "PT1M" # Erfasst die Messwerte im 1-Minuten-Takt
        statistic          = "Average" # Berechnet den Mittelwert über alle laufenden Instanzen
        time_window        = "PT5M" # Betrachtet das Zeitfenster der letzten 5 Minuten
        time_aggregation   = "Average" # Aggregiert die Werte als Durchschnitt
        operator           = "GreaterThan" # Löst aus, sobald der Schwellenwert überschritten wird
        threshold          = 70 # Setzt die Schwelle zum Hochskalieren auf 70 Prozent CPU-Last
      }

      scale_action { # Definiert die Skalierungsaktion bei Überschreitung von 70 % CPU-Last
        direction = "Increase" # Erhöht die Anzahl der laufenden Instanzen
        type      = "ChangeCount" # Ändert die Instanzanzahl um einen festen Wert
        value     = "1" # Fügt 1 zusätzliche Instanz hinzu
        cooldown  = "PT5M" # Wartet 5 Minuten vor einer weiteren Skalierungsaktion
      }
    }

    rule { # Zweite Regel: Horizontales Herunterskalieren (Scale-In) bei sinkender Last
      metric_trigger { # Definiert den Auslöser für den Abbau überschüssiger Instanzen
        metric_name        = "CpuPercentage" # Überwacht ebenfalls die prozentuale CPU-Auslastung
        metric_resource_id = azurerm_service_plan.asp.id # Bezieht die Metrik vom App Service Plan
        time_grain         = "PT1M" # Prüft im 1-Minuten-Intervall
        statistic          = "Average" # Nutzt den Durchschnittswert aller Instanzen
        time_window        = "PT5M" # Betrachtet einen Zeitraum von 5 Minuten
        time_aggregation   = "Average" # Aggregiert über den Durchschnitt
        operator           = "LessThan" # Löst aus, wenn die Auslastung unter den Schwellenwert sinkt
        threshold          = 30 # Setzt die Schwelle zum Herunterskalieren auf 30 Prozent CPU-Last
      }

      scale_action { # Definiert die Aktion bei Unterschreitung von 30 % CPU-Last
        direction = "Decrease" # Verringert die Anzahl der laufenden Instanzen
        type      = "ChangeCount" # Ändert die Instanzanzahl um einen festen Wert
        value     = "1" # Baut 1 Instanz wieder ab (bis zum Minimum von 2 Instanzen)
        cooldown  = "PT5M" # Wartet 5 Minuten vor der nächsten Prüfung
      }
    }
  }
}

resource "azurerm_linux_web_app" "webapp" { # Erstellt die PaaS-Web-App zum Hosten der Webseite
  name                = "app-${var.name_prefix}" # Vergibt einen global eindeutigen Namen für die Web App
  location            = var.location # Platziert die Web App in der übergebenen Region
  resource_group_name = var.resource_group_name # Ordnet die Web App der Ressourcengruppe zu
  service_plan_id     = azurerm_service_plan.asp.id # Verknüpft die Web App mit dem App Service Plan
  https_only          = true # Erzwingt ausschließlich verschlüsselte HTTPS-Verbindungen
  zip_deploy_file     = data.archive_file.html_zip.output_path # Spielt das erzeugte ZIP-Paket mit der index.html direkt ein
  depends_on          = [azurerm_service_plan.asp, azurerm_application_insights.appinsights] # Stellt sicher, dass Plan und Monitoring zuerst bereitstehen
  tags                = var.tags # Weist die übergebenen Tags zu

  identity { # Konfiguriert die Dienstidentität der Web App
    type = "SystemAssigned" # Aktiviert eine System-Assigned Managed Identity für den passwortlosen Key-Vault-Zugriff
  }

  site_config { # Konfiguriert den integrierten Webserver der Web App
    always_on           = true # Verhindert das Abschalten bei Inaktivität und vermeidet Kaltstart-Verzögerungen
    minimum_tls_version = "1.2" # Setzt mindestens TLS 1.2 für sichere Verschlüsselung voraus
    ftps_state          = "Disabled" # Deaktiviert unsichere FTP-Zugänge zugunsten des Terraform-ZIP-Deployments

    application_stack { # Legt das Laufzeit-Framework des Webservers fest
      php_version = "8.2" # Nutzt den integrierten PHP-8.2-Webserver zur sofortigen Auslieferung der index.html
    }
  }

  app_settings = { # Übergibt Konfigurations- und Umgebungsvariablen an die Web App
    "APPINSIGHTS_INSTRUMENTATIONKEY"        = azurerm_application_insights.appinsights.instrumentation_key # Verknüpft den Instrumentation-Key von Application Insights
    "APPLICATIONINSIGHTS_CONNECTION_STRING" = azurerm_application_insights.appinsights.connection_string # Übergibt den Connection-String für Telemetriedaten
    "SCM_DO_BUILD_DURING_DEPLOYMENT"        = "false" # Deaktiviert unnötige Build-Prozesse für die statische HTML-Datei
  }
}

output "webapp_default_hostname" { # Gibt den generierten Hostnamen der Web App an das Hauptskript zurück
  value = azurerm_linux_web_app.webapp.default_hostname # Liest die Standard-Domain (*.azurewebsites.net) für Azure Front Door und die Outputs aus
}

output "webapp_principal_id" { # Gibt die eindeutige Objekt-ID der Managed Identity an das Hauptskript zurück
  value = azurerm_linux_web_app.webapp.identity[0].principal_id # Wird im Hauptskript für die Zugriffsrichtlinie des Azure Key Vaults benötigt
}

output "webapp_id" { # Gibt die vollständige Azure-Ressourcen-ID der Web App an das Hauptskript zurück
  value = azurerm_linux_web_app.webapp.id # Ermöglicht bei Bedarf direkte Ressourcen-Referenzierungen im Hauptskript
}