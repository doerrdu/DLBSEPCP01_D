variable "resource_group_name" { # Definiert die Eingabevariable für den Namen der Azure Resource Group
  description = "Name der Azure Resource Group für saubere Kapselung" # Beschreibt den Verwendungszweck der Variable
  type        = string # Legt den Datentyp als Zeichenkette (Text) fest
  default     = "rg-portfolio-aufgabe1" # Setzt den Standardnamen passend zum Architekturdiagramm
}

variable "location" { # Definiert die Variable für das geografische Azure-Rechenzentrum
  description = "Erlaubte Azure-Region gemäß Azure Policy (francecentral, switzerlandnorth, polandcentral, austriaeast, belgiumcentral)" # Dokumentiert die erlaubten Regionen
  type        = string # Legt den Datentyp als Zeichenkette fest
  default     = "francecentral" # Wechselt auf "francecentral", um die App-Service-Drosselung (Fehler 429) zu umgehen
}

variable "project_prefix" { # Definiert ein einheitliches Namenspräfix für alle Cloud-Dienste
  description = "Präfix für alle Cloud-Ressourcen (max. 12 Zeichen wegen Key Vault Limit)" # Erklärt den Zweck und die Längenbegrenzung
  type        = string # Legt den Datentyp als Zeichenkette fest
  default     = "iuportfolio" # Setzt den Standardwert für das Projektpräfix
}

variable "app_service_sku" { # Definiert die Variable für die Leistungsstufe des App Service Plans
  description = "Tarif für den App Service Plan (S1 unterstützt Auto-Scaling & Traffic Manager)" # Erläutert die Wahl des Tarifs
  type        = string # Legt den Datentyp als Zeichenkette fest
  default     = "S1" # Wählt den Standard-Tarif S1 als Voraussetzung für Auto-Scaling und Traffic Manager
}

variable "tags" { # Definiert einheitliche Metadaten-Markierungen (Tags) für alle Ressourcen
  description = "Einheitliche Tags zur sauberen Strukturierung und Kostenkontrolle" # Beschreibt den Nutzen für die Cloud-Governance
  type        = map(string) # Legt den Datentyp als Schlüssel-Wert-Tabelle (Map) fest
  default = { # Öffnet den Block der Standard-Tags
    Project   = "IU-Cloud-Programming-Aufgabe1" # Ordnet alle Ressourcen eindeutig dem Portfolioprojekt zu
    ManagedBy = "Terraform" # Kennzeichnet die automatisierte Bereitstellung über Infrastructure as Code
  }
}