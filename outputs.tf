output "global_traffic_manager_url" { # Definiert den Output für die globale URL über den Azure Traffic Manager
  description = "Globale, latenzoptimierte DNS-URL über Azure Traffic Manager" # Erklärt den Zweck der ausgegebenen URL
  value       = "http://${azurerm_traffic_manager_profile.tm.fqdn}" # Nutzt http:// zur sauberen Weiterleitung auf das HTTPS-Backend ohne SSL-Warnung
}

output "direct_webapp_url" { # Definiert den Output für die direkte URL des Azure App Service
  description = "Direkte HTTPS-URL des Azure App Service Backends" # Erklärt den Zweck der direkten Backend-URL
  value       = "https://${module.compute_webapp.webapp_default_hostname}" # Bezieht den Hostnamen der Web App aus dem Modul-Output
}