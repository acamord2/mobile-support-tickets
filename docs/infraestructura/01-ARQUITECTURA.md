# Arquitectura vigente

Flutter Android conserva SQLite y una cola persistente; durante la práctica usa USB/ADB reverse hacia HTTP 5263. Windows ejecuta pgAdmin 9.4, cliente OpenSSH y proxy Python temporal Grafana. Ubuntu 20.04.6 WSL2 contiene Docker Engine 27.3.1, Compose 2.29.7 y systemd. tickets-supervisor.service corre como econt, fuera de los once contenedores.

API ASP.NET Core .NET 10/Npgsql utiliza imagen local tickets-api:fase12-3, UID1654. PostgreSQL 17.11 primario y standby físico asíncrono tienen almacenamiento independiente; no hay promoción automática. Prometheus/Grafana, cAdvisor, Blackbox, dos exporters SQL, Docker Socket Proxy y supervision_metricas completan la plataforma.

## Redes reales

| Red Compose | Internal | Participantes |
|---|---|---|
| acceso_api | no | api |
| base_datos | sí | api, postgres, postgres_lectura, blackbox, ambos exporters |
| monitoreo | sí | prometheus, grafana, cadvisor, blackbox, ambos exporters, supervision_metricas |
| motor_docker | sí | docker_socket_proxy, cadvisor, blackbox |

El diagrama dibuja cada componente una vez; la tabla expresa sus pertenencias múltiples. Internal limita enrutamiento externo Docker, pero no impide al host WSL acceder a sus bridges ni protege frente a un administrador del host.

| Servicio/acceso | Puerto interno | Publicación/acceso host |
|---|---:|---|
| API | 8080 | 5263 en 0.0.0.0 y :: de WSL, exposición existente |
| PostgreSQL ambos | 5432 | ninguno Docker |
| Grafana | 3000 | ninguno Docker; proxy Windows 127.0.0.1:13000 |
| Prometheus | 9090 | ninguno |
| cAdvisor / Blackbox / exporters | 8080 / 9115 / 9187 | ninguno |
| Socket Proxy / métricas supervisor | 2375 / 9199 | ninguno |
| sshd dedicado | host WSL 2222 | 127.0.0.1:2222 bajo demanda |
| Túneles pgAdmin | destinos privados 5432 | Windows 127.0.0.1:15432 y 15433 |

No se certifica aislamiento LAN de API5263 ni de toda la topología Hyper-V/Windows. Docker27 tiene limitaciones históricas sobre publicaciones localhost; PostgreSQL y monitoreo evitan ese mecanismo. Puertos5432/5433 de otros proyectos no pertenecen a esta arquitectura. SSH temporal no estaba escuchando al auditar esta fase; no se inició.

## Flujos y consistencia

Login, /api/auth/me, rol/actividad, autorización primaria, transacciones y escrituras siguen en postgres. PasswordHasher<Usuario> verifica hashes Identity y el middleware valida JWT. Cinco lecturas replicables usan consultor_api en standby: sucursales, agenda, eventos, solicitudes y técnicos. Cada respuesta usa una conexión/snapshot REPEATABLE READ READ ONLY; conserva alcance y filtros, sin sustituirlos por agenda_tickets.

La API comprueba pg_is_in_recovery y devuelve X-Destino-Lectura. X-Consistencia: inmediata o ?consistencia=inmediata solicita consulta primaria con la cuenta consultora, útil después de escribir. SecretsApi:LecturasEnPrimario=true permite reversión. Standby caído permite un solo fallback seguro a primario; nunca se reintenta una escritura con commit incierto.

Ante fallo transitorio del primario, solo GET protegido con JWT vigente y categorías previamente verificadas puede reutilizar autorización hasta120s desde su última validación primaria. Incluye X-Modo: solo-consultas y X-Autorizacion: temporal-no-confirmada. No confirma una revocación desconocida; existe ventana residual de hasta120s. Login nuevo, /me, escritura y caché ausente/vencida fallan con503/Retry-After5; token inválido/expirado produce401. Reiniciar API elimina caché y falla cerrado.

Timeouts: apertura2s, comando3s, primer intento3s, lectura7s y petición9s; Flutter15s. SQLite conserva pendientes y no los sobrescribe al descargar; guardado local no es confirmación remota.

## Dependencias y almacenamiento

Depends_on service_healthy: api→postgres, grafana→prometheus y cadvisor→docker_socket_proxy. No representa vigilancia continua. Bootstrap standby exige primario accesible, passfile, respaldo ensayado y volumen vacío o standby válido. Volúmenes: datos_postgres, datos_postgres_lectura, datos_prometheus y datos_grafana. Estado/cooldown/presupuesto supervisor reside externo.

Si Engine/WSL se detienen no hay disponibilidad dentro de esa VM. Unless-stopped opera cuando Docker vuelve; no inicia Windows/WSL. Supervisor no repara Engine ni promueve PostgreSQL.

## Diagramas

[draw.io editable](arquitectura.drawio) · [Mermaid importable](arquitectura.mmd). Las versiones proceden del inventario inspeccionado, no de una suposición sobre tags.

```mermaid
flowchart LR
  subgraph win["Windows 11"]
    pgadmin["pgAdmin 9.4"]
    tun["OpenSSH loopback 15432 / 15433"]
    browser["Navegador Grafana"]
    proxy["Proxy temporal 127.0.0.1:13000"]
  end
  subgraph wsl["Ubuntu 20.04 WSL2"]
    subgraph sys["systemd - procesos host"]
      sup["tickets-supervisor.service - econt"]
      state["Estado persistente externo - cooldown y supervisor.prom"]
    end
    subgraph eng["Docker Engine 27.3.1 / Compose 2.29.7"]
      subgraph access["acceso_api - bridge"]
        api["api .NET 10 - 8080 / host 5263"]
      end
      subgraph db["base_datos - interna"]
        pg["postgres 17.11 - 5432 - RW"]
        ro["postgres_lectura 17.11 - 5432 - READ ONLY"]
        exp["postgres_exporter v0.20.1 - 9187"]
        expro["postgres_exporter_lectura v0.20.1 - 9187"]
        vpg["Volumen datos_postgres"]
        vro["Volumen datos_postgres_lectura"]
      end
      subgraph mon["monitoreo - interna"]
        prom["prometheus v3.15.0 - 9090 / 15s / 7d"]
        gf["grafana 13.2.4 - 3000 / 5 dashboards / 50 paneles"]
        bb["blackbox v0.29.0 - 9115"]
        cad["cadvisor 0.60.6 - 8080 / lectura host"]
        met["supervision_metricas BusyBox 1.37.0 - 9199"]
        vp["datos_prometheus"]
        vg["datos_grafana"]
      end
      subgraph motor["motor_docker - interna"]
        sock["docker_socket_proxy v0.5.0 - 2375 / GET-HEAD ACL"]
        dockerapi["Socket Docker - ACL proxy / control host separado"]
      end
    end
    sshd["sshd temporal 127.0.0.1:2222 - key-only / PermitOpen / sin shell"]
  end
  android["Android Flutter / SQLite - USB ADB reverse 5263"]
  pgadmin -->|"TCP loopback"| tun
  tun -->|"SSH host key verificada"| sshd
  sshd -->|"PermitOpen IP actual:5432"| pg
  sshd -->|"PermitOpen IP actual:5432"| ro
  android -->|"ADB reverse + HTTP JWT"| api
  api -->|"Escritura login me y autorizacion"| pg
  api -->|"Cinco lecturas consultor_api"| ro
  pg -->|"WAL streaming async y slot"| ro
  exp -->|"monitor_postgres"| pg
  expro -->|"monitor_postgres"| ro
  prom -->|"scrape interno"| exp
  prom -->|"scrape interno"| expro
  prom -->|"scrape"| cad
  prom -->|"scrape y probes"| bb
  prom -->|"scrape supervisor.prom"| met
  prom -->|"Auto scrape"| prom
  gf -->|"Datasource"| prom
  bb -->|"health HTTP"| api
  bb -->|"Metadatos permitidos"| sock
  cad -->|"GET HEAD"| sock
  sock -->|"Socket local protegido"| dockerapi
  sup -->|"restart solo API Grafana Blackbox exporters"| dockerapi
  sup -->|"Persiste y observa salud"| state
  state -->|"Bind RO metricas"| met
  browser -->|"HTTP loopback"| proxy
  proxy -->|"stdio WSL sin puerto Docker"| gf
  pg -->|"PGDATA propio"| vpg
  ro -->|"PGDATA propio"| vro
  prom -->|"TSDB"| vp
  gf -->|"Persistencia"| vg
  api -.->|"Fallback seguro consultor_api"| pg
  legend["Flecha continua: solicitud/flujo. Punteada: fallback seguro. Multiples redes: API tambien base_datos; exporters tambien monitoreo; Blackbox tambien base_datos/motor_docker; cAdvisor tambien motor_docker. PostgreSQL y monitoreo sin puertos Docker publicados. SSH/proxy bajo demanda. Solo primario escribe; sin promocion automatica. Backups externos no equivalen a replica."]
```
